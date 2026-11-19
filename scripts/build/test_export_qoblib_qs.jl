using Test
import QUBOLib

include("export_qoblib_qs.jl")
module QSReader
import QUBOLib
const QUBOTools = QUBOLib.QUBOTools
include("sources/qoblib.jl")
end

const Export = QOBLIBQSExport
const JSON = QUBOLib.JSON
const QT = QUBOLib.QUBOTools
const R = Rational{BigInt}

function fixture(directory; sense = "max", scale = "-3//2", offset = "3//4",
    linear = "5//8", interaction = "-3//8")
    header = Dict("kind" => "header", "schema" => "qoblib-generated-exact-polynomial-v1",
        "n" => 4, "domain" => "bool", "sense" => sense,
        "scale_exact" => scale, "offset_exact" => offset, "variable_order" => "one_based_internal")
    original = joinpath(directory, "original-polynomial.jsonl")
    open(original, "w") do io
        for row in (header,
            Dict("kind" => "linear", "i" => 1, "coefficient_exact" => linear),
            Dict("kind" => "linear", "i" => 3, "coefficient_exact" => "-1//2"),
            Dict("kind" => "quadratic", "i" => 1, "j" => 2, "coefficient_exact" => interaction))
            println(io, JSON.json(row))
        end
    end
    environment = joinpath(directory, "environment.json")
    write(environment, JSON.json(Dict("julia_version" => "1.13.4", "packages" =>
        Dict(name => Dict("version" => version, "source_tree" => repeat("a", 40))
            for (name, version) in (("ToQUBO", "0.8.2"), ("QUBOPreprocessing", "0.2.2"),
                ("PseudoBooleanOptimization", "0.3.2"))))))
    audit = joinpath(directory, "audit.json")
    write(audit, JSON.json(Dict("schema" => "qoblib-missing-case-audit-v2", "accepted" => true,
        "passed" => true, "original_validated" => true, "case_id" => "toy-case",
        "source_snapshot_commit" => repeat("b", 40), "source_lp_path" => "03-birkhoff/toy.lp.xz",
        "source_lp_decompressed_sha256" => repeat("c", 64), "environment_sha256" => Export.sha(environment),
        "original" => Dict("n" => 4, "l" => 2, "m" => 1, "polynomial_sha256" => Export.sha(original)))))
    return (; original, audit, environment, target = joinpath(directory, "contribution"))
end

@testset "Exact QOBLIB QS conversion" begin
    for sense in ("min", "max"), scale in ("-3//2", "3//2")
        mktempdir() do directory
            paths = fixture(directory; sense, scale)
            receipt = Export.export_qs(paths...)
            qs_path = joinpath(paths.target, "toy-case.qs")
            @test receipt == JSON.parsefile(joinpath(paths.target, "provenance.json"))
            @test receipt["qs"]["sha256"] == Export.sha(qs_path)
            @test receipt["audit"]["sha256"] == Export.sha(paths.audit)
            @test receipt["source"]["decompressed_sha256"] == repeat("c", 64)
            @test receipt["generation"]["packages"]["ToQUBO"]["version"] == "0.8.2"
            @test receipt["saved_original"]["sense"] == sense
            @test receipt["saved_original"]["scale_exact"] == scale

            model = QT.read_model(qs_path, QSReader.QOBLIBQS())
            @test Symbol(QT.domain(model)) == :bool
            @test Symbol(QT.sense(model)) == :min
            @test collect(QT.variables(model)) == collect(1:4)
            multiplier = (sense == "max" ? -1 : 1) * Export.exact(scale)
            @test receipt["qs"]["multiplier_exact"] == Export.exact_text(multiplier)
            @test R(QT.offset(model)) == multiplier * (3//4)
            @test Dict(i => R(value) for (i, value) in QT.linear_terms(model)) ==
                Dict(1 => multiplier * (5//8), 3 => multiplier * (-1//2))
            @test Dict(ij => R(value) for (ij, value) in QT.quadratic_terms(model)) ==
                Dict((1, 2) => multiplier * (-3//8))
            for assignment in 0:15
                state = [(assignment >> i) & 1 for i in 0:3]
                expected = multiplier * (3//4 + (5//8) * state[1] -
                    (1//2) * state[3] - (3//8) * state[1] * state[2])
                @test R(QT.value(model, state)) == expected
            end
            @test_throws ArgumentError Export.export_qs(paths...)
            @test Export.sha(qs_path) == receipt["qs"]["sha256"]
        end
    end
end

@testset "QS text preserves the exact decimal value" begin
    mktempdir() do directory
        coefficient = R(0.1)
        paths = fixture(directory; sense = "min", scale = "1//1", linear = Export.exact_text(coefficient))
        Export.export_qs(paths...)
        qs_path = joinpath(paths.target, "toy-case.qs")
        token = last(split(only(filter(line -> startswith(line, "1 1 "), readlines(qs_path)))))
        significand, places = split(token, "e-")
        @test parse(BigInt, significand) // (big(10)^parse(Int, places)) == coefficient
        model = QT.read_model(qs_path, QSReader.QOBLIBQS())
        @test R(Dict(QT.linear_terms(model))[1]) == coefficient
    end
end

@testset "Unrepresentable products and invalid receipts leave no export" begin
    # Inputs are individually representable; the signed/scaled product rounds.
    almost_one = Export.exact_text(nextfloat(1.0))
    smallest = Export.exact_text(nextfloat(0.0))
    largest = Export.exact_text(floatmax(Float64))
    for (parameters, reason) in (((scale = almost_one, linear = almost_one, offset = "0//1"), "(\"coefficient\""),
        ((scale = "1//1", interaction = smallest), "(\"half interaction\""),
        ((scale = "2//1", interaction = largest), "(\"coefficient\""),
        ((scale = almost_one,), "offset"))
        mktempdir() do directory
            paths = fixture(directory; parameters...)
            failure = try
                Export.export_qs(paths...)
                nothing
            catch error
                error
            end
            @test failure isa ArgumentError
            @test occursin("QS Float64 cannot represent $reason", sprint(showerror, failure))
            @test !ispath(paths.target)
        end
    end
    for tampered in (:original, :environment, :audit)
        mktempdir() do directory
            paths = fixture(directory)
            if tampered == :audit
                audit = JSON.parsefile(paths.audit)
                audit["original"]["l"] = 1
                write(paths.audit, JSON.json(audit))
            else
                open(getproperty(paths, tampered), "a") do io
                    print(io, '\n')
                end
            end
            @test_throws ArgumentError Export.export_qs(paths...)
            @test !ispath(paths.target)
        end
    end
end
