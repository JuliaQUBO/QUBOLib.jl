"""Convert an independently audited, saved binary Original to QOBLIB QS."""
module QOBLIBQSExport

import SHA

include("qoblib_toqubo.jl")
using .QOBLIBToQUBO: JSON, exact, exact_text, header, require, scan_polynomial, sha

const SCHEMA = "qubolib-qoblib-qs-export-v1"

function require_qs_float(value, location)
    converted = Float64(value)
    isfinite(converted) && Rational{BigInt}(converted) == value ||
        throw(ArgumentError("QS Float64 cannot represent $location exactly: $value"))
    return nothing
end

function decimal_token(value::Rational{BigInt})
    # Float64-exact fractions are dyadic. Write the exact decimal itself, so
    # decimal readers also see the intended value instead of a roundtrip alias.
    num, den = numerator(value), denominator(value)
    den == 1 && return string(num)
    places = trailing_zeros(den)
    return string(num * (big(5)^places), "e-", places)
end

function write_qs(io, polynomial, expected)
    n, l, m = (expected[key] for key in ("n", "l", "m"))
    require((n, l, m) isa NTuple{3,Int} && 0 <= l <= n && 0 <= m <= typemax(Int) - l,
        "invalid independent audit dimensions")

    return open(polynomial, "r") do input
        line = readline(input)
        require(!isempty(line) && sizeof(line) <= 16_384, "empty/oversized saved polynomial header")
        row = JSON.parse(line)
        require(row isa AbstractDict, "polynomial header must be an object")
        dimension, _, _ = header(row; max_variables = n)
        require(dimension == n, "saved polynomial dimension differs from independent audit")
        scale = exact(row["scale_exact"])
        multiplier = row["sense"] == "max" ? -scale : scale
        offset = multiplier * exact(row["offset_exact"])
        require_qs_float(offset, "offset")

        println(io, "# ObjectiveOffset ", decimal_token(offset))
        println(io, "# Vars Non-zeros")
        println(io, n, " ", l + m)
        seekstart(input)
        saved = scan_polynomial(input; max_variables = n, max_interactions = m) do i, j, coefficient
            scaled = multiplier * Rational{BigInt}(coefficient)
            require_qs_float(scaled, ("coefficient", i, j))
            column = i
            token = scaled
            if j != 0
                column = j
                # QS stores one triangle of a symmetric matrix used as x'Qx.
                token = scaled / 2
                require_qs_float(token, ("half interaction", i, j))
            end
            println(io, i, " ", column, " ", decimal_token(token))
        end
        require(saved.h == row && (saved.n, saved.l, saved.m) == (n, l, m),
            "saved polynomial header or counts differ from independent audit")
        return (; header = row, multiplier, offset, fingerprint = saved.fingerprint)
    end
end

function input_object(path)
    require(isfile(path) && !islink(path), "expected regular input file: $path")
    body = read(path)
    digest = bytes2hex(SHA.sha256(body))
    value = JSON.parse(String(body))
    require(value isa AbstractDict, "expected JSON input object: $path")
    return value, digest
end

function generator_provenance(environment)
    julia = get(environment, "julia_version", nothing)
    packages = get(environment, "packages", nothing)
    require(julia isa AbstractString && !isempty(julia) && packages isa AbstractDict,
        "environment is missing Julia or package provenance")
    selected = Dict{String,Any}()
    for name in ("ToQUBO", "QUBOPreprocessing", "PseudoBooleanOptimization")
        package = get(packages, name, nothing)
        require(package isa AbstractDict && get(package, "version", nothing) isa AbstractString &&
            !isempty(package["version"]), "environment is missing $(name) version provenance")
        fields = ("version", "source_tree", "commit")
        selected[name] = Dict(key => package[key] for key in fields if haskey(package, key))
    end
    return Dict("julia_version" => julia, "packages" => selected)
end

function export_qs(polynomial, audit_path, environment_path, output)
    require(isfile(polynomial) && !islink(polynomial), "expected regular saved Original polynomial")
    require(!ispath(output) && !islink(output), "output already exists: $output")
    audit, audit_sha = input_object(audit_path)
    environment, environment_sha = input_object(environment_path)
    require(get(audit, "schema", nothing) in ("qoblib-missing-case-audit-v1", "qoblib-missing-case-audit-v2") &&
        all(key -> get(audit, key, false) === true, ("accepted", "passed", "original_validated")),
        "independent Original audit did not pass")
    require(audit["environment_sha256"] == environment_sha, "environment differs from the independent audit")
    id = audit["case_id"]
    require(id isa AbstractString && occursin(r"\A[A-Za-z0-9_-]+\z", id), "invalid audited case ID")
    original = audit["original"]
    polynomial_sha = original["polynomial_sha256"]
    require(sha(polynomial) == polynomial_sha, "saved Original differs from the independent audit")
    generation = generator_provenance(environment)
    source_commit = audit["source_snapshot_commit"]
    source_lp_sha = audit["source_lp_decompressed_sha256"]
    source_lp = audit["source_lp_path"]
    require(source_commit isa AbstractString && occursin(r"\A[0-9a-f]{40}\z", source_commit) &&
        source_lp_sha isa AbstractString && occursin(r"\A[0-9a-f]{64}\z", source_lp_sha),
        "invalid source LP identity in the independent audit")
    require(source_lp isa AbstractString && !occursin('\\', source_lp) &&
        all(part -> !(part in ("", ".", "..")), split(source_lp, '/')),
        "expected a repository-relative source LP path")
    source = Dict("repository" => "ZIB-AOPT/QOBLIB", "commit" => source_commit, "path" => source_lp,
        "decompressed_sha256" => source_lp_sha)

    output = abspath(output)
    return mktempdir(dirname(output); prefix = ".qoblib-qs-") do staging
        filename = id * ".qs"
        destination = joinpath(staging, filename)
        conversion = open(destination, "w") do io
            write_qs(io, polynomial, original)
        end
        require(sha(polynomial) == polynomial_sha, "saved Original changed during export")
        receipt = Dict("schema" => SCHEMA, "case_id" => id, "source" => source,
            "generation" => generation, "environment_sha256" => environment_sha,
            "audit" => Dict("schema" => audit["schema"], "sha256" => audit_sha,
                "accepted" => true, "original_validated" => true, "n" => original["n"], "l" => original["l"], "m" => original["m"]),
            "saved_original" => Dict("sha256" => polynomial_sha, "fingerprint_sha256" => conversion.fingerprint,
                "sense" => conversion.header["sense"], "scale_exact" => conversion.header["scale_exact"],
                "offset_exact" => conversion.header["offset_exact"], "variable_order" => conversion.header["variable_order"]),
            "qs" => Dict("path" => filename, "sha256" => sha(destination), "bytes" => filesize(destination),
                "domain" => "bool", "sense" => "min", "offset_exact" => exact_text(conversion.offset),
                "multiplier_exact" => exact_text(conversion.multiplier)),
            "scope" => "Exact signed objective translation from the independently audited saved Original on binary assignments.")
        QOBLIBToQUBO.new_json(joinpath(staging, "provenance.json"), receipt)
        mv(staging, output)
        receipt
    end
end

function main(args = ARGS)
    length(args) == 4 || throw(ArgumentError("usage: export_qoblib_qs.jl POLYNOMIAL AUDIT ENVIRONMENT OUTPUT_DIRECTORY"))
    export_qs(args...)
    return nothing
end

end

if abspath(PROGRAM_FILE) == (@__FILE__)
    QOBLIBQSExport.main()
end
