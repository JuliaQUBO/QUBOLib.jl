# Define codec for QPLIB format
# TODO: Make it available @ QUBOTools

struct Format{F} <: QUBOTools.AbstractFormat
    Format(F::Symbol) = new{F}()
end

function _read_qplib_model(path::AbstractString)
    return open(path, "r") do io
        _read_qplib_model(io)
    end
end

function _read_qplib_line(io::IO)
    line = readline(io)

    # Remove comments and strip line
    return strip(only(match(r"([^#]+)", line)))
end

function _read_qplib_float(io::IO, ∞::AbstractString)
    line = _read_qplib_line(io)

    if line == ∞
        return Inf
    else
        return parse(Float64, line)
    end
end

function QUBOTools.read_model(io::IO, ::Format{:qplib})
    # Read the header
    code = _read_qplib_line(io)

    @assert !isnothing(match(r"^(QBB|QBN)$", _read_qplib_line(io)))

    sense = _read_qplib_line(io)

    @assert sense ∈ ("minimize", "maximize")

    # number of variables
    nv = let
        line = _read_qplib_line(io)
        m    = match(r"([0-9]+)", line)

        if isnothing(m)
            QUBOTools.syntax_error("Invalid number of variables: $(line)")

            return nothing
        end

        parse(Int, m[1])
    end

    V = Set{Int}(1:nv)
    L = Dict{Int,Float64}()
    Q = Dict{Tuple{Int,Int},Float64}()

    # number of quadratic terms in objective
    nq = let
        line = _read_qplib_line(io)
        m    = match(r"([0-9]+)", line)

        if isnothing(m)
            QUBOTools.syntax_error("Invalid number of quadratic terms: $(line)")

            return nothing
        end

        parse(Int, m[1])
    end

    sizehint!(Q, nq)

    for _ = 1:nq
        let
            line = _read_qplib_line(io)
            m    = match(r"([0-9]+)\s+([0-9]+)\s+(\S+)", line)

            if isnothing(m)
                QUBOTools.syntax_error("Invalid quadratic term: $(line)")

                return nothing
            end

            i = parse(Int, m[1])
            j = parse(Int, m[2])
            c = parse(Float64, m[3])

            # QPLIB defines the quadratic objective as 0.5 * x' * Q^0 * x + b^0 * x + q^0,
            # storing the lower-left triangle of Q^0 (i >= j).
            key = i <= j ? (i, j) : (j, i)
            Q[key] = get(Q, key, 0.0) + 0.5 * c
        end
    end

    # default value for linear coefficients in objective
    dl = parse(Float64, _read_qplib_line(io))

    # number of non-default linear coefficients in objective
    ln = parse(Int, _read_qplib_line(io))

    sizehint!(L, ln)

    if !iszero(dl)
        for i = 1:nv
            L[i] = dl
        end
    end

    for _ = 1:ln
        let line = _read_qplib_line(io)
            m    = match(r"([0-9]+)\s+(\S+)", line)

            if isnothing(m)
                QUBOTools.syntax_error("Invalid linear coefficient: $(line)")

                return nothing
            end

            i = parse(Int, m[1])
            c = parse(Float64, m[2])

            L[i] = c
        end
    end

    β = parse(Float64, _read_qplib_line(io)) # objective constant

    inf = _read_qplib_line(io) # value for infinity

    @assert _read_qplib_float(io, inf) isa Float64 # default variable primal value in starting point
    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default variable primal values in starting point

    @assert _read_qplib_float(io, inf) isa Float64 # default variable bound dual value in starting point
    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default variable bound dual values in starting point

    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default variable names
    @assert iszero(parse(Int, _read_qplib_line(io))) # number of non-default constraint names

    return QUBOTools.Model{Int,Float64,Int}(
        V, L, Q;
        offset      = β,
        domain      = :bool,
        sense       = (sense == "minimize") ? :min : :max,
        description = "QPLib instance no. $code",
    )
end

function _read_qplib_solution(
    path::AbstractString,
    model::QUBOTools.Model{Int,Float64,Int},
    var_map::Dict{Int,Int},
)
    return open(path, "r") do io
        _read_qplib_solution!(io, model, var_map)
    end
end

function _read_qplib_solution!(
    io::IO,
    model::QUBOTools.Model{Int,Float64,Int},
    var_map::Dict{Int,Int},
)
    # Read the header
    λ = let
        m = match(r"objvar\s+([\S]+)", readline(io))

        if isnothing(m)
            QUBOTools.syntax_error("Invalid header")
        end

        tryparse(Float64, m[1])
    end

    if isnothing(λ)
        QUBOTools.syntax_error("Invalid objective value")
    end

    n = QUBOTools.dimension(model)
    ψ = zeros(Int, n)

    for line in eachline(io)
        i, x = let
            m = match(r"b([0-9]+)\s+([\S]+)", line)

            if isnothing(m)
                QUBOTools.syntax_error("Invalid solution input")
            end

            (tryparse(Int, m[1]), tryparse(Float64, m[2]))
        end

        if isnothing(i) || isnothing(x)
            QUBOTools.syntax_error("Invalid variable assignment")
        end

        ψ[var_map[i]] = ifelse(x > 0, 1, 0)
    end

    s = QUBOTools.Sample{Float64,Int}[QUBOTools.Sample{Float64,Int}(ψ, λ)]

    return QUBOTools.SampleSet{Float64,Int}(
        s;
        sense  = QUBOTools.sense(model),
        domain = :bool,
    )
end

function _is_qplib_qubo(path::AbstractString)
    @assert isfile(path) && endswith(path, ".qplib")

    return open(path, "r") do io
        ____ = _read_qplib_line(io)
        type = _read_qplib_line(io)

        return type in ("QBB", "QBN")
    end
end

function _get_qplib_var_map(path::AbstractString, n::Integer = 1)
    @assert isfile(path) && endswith(path, ".lp")

    var_set = sizehint!(Set{Int}(), n)

    open(path, "r") do io
        for line in eachline(io)
            for m in eachmatch(r"b([0-9]+)", line)
                if !isnothing(m)
                    push!(var_set, parse(Int, m[1]))
                end
            end
        end
    end

    return Dict{Int,Int}(v => i for (i, v) in enumerate(sort!(collect(var_set))))
end

const QPLIB_URL = "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/data-mirror/qplib.zip"
const QPLIB_MIRROR_SHA256 = "896b2e1c5e5e78e7b89674cb6bc84a0f6e05a0e36adddeaaa744472733517672"
const QPLIB_SOURCE_REPOSITORY_URL = "https://gitlab.com/svigerske/qplib-web"
const QPLIB_SOURCE_COMMIT = "4b681a263d9c2cb21e83f08e1b3232361dcedd5a"
const QPLIB_SOURCE_COMMIT_URL =
    "https://gitlab.com/svigerske/qplib-web/-/commit/$QPLIB_SOURCE_COMMIT"
const QPLIB_CITATION = """
@article{Furini2019QPLIB,
  title={QPLIB: a library of quadratic programming instances},
  author={Furini, Fabio and Traversi, Emiliano and Belotti, Pietro and Frangioni, Antonio and Gleixner, Ambros and Gould, Nick and Liberti, Leo and Lodi, Andrea and Misener, Ruth and Mittelmann, Hans and Sahinidis, Nikolaos and Vigerske, Stefan and Wiegele, Angelika},
  journal={Mathematical Programming Computation},
  volume={11},
  pages={237--265},
  year={2019},
  doi={10.1007/s12532-018-0147-4},
}
"""

const QPLIB_DATA = Dict{String,Any}(
    "name"         => "QPLIB",
    "author"       => [
        "Fabio Furini",
        "Emiliano Traversi",
        "Pietro Belotti",
        "Antonio Frangioni",
        "Ambros Gleixner",
        "Nick Gould",
        "Leo Liberti",
        "Andrea Lodi",
        "Ruth Misener",
        "Hans Mittelmann",
        "Nikolaos Sahinidis",
        "Stefan Vigerske",
        "Angelika Wiegele",
    ],
    "description"  => "The Quadratic Programming Library",
    "year"         => 2014,
    "url"          => "https://qplib.zib.de/",
    "data_license" => "CC-BY-4.0",
    "citation"     => QPLIB_CITATION,
    "metadata"     => Dict{String,Any}(
        "source_name"              => "QPLIB",
        "source_url"               => "https://qplib.zib.de/",
        "source_repository_url"    => QPLIB_SOURCE_REPOSITORY_URL,
        "source_commit"            => QPLIB_SOURCE_COMMIT,
        "source_commit_url"        => QPLIB_SOURCE_COMMIT_URL,
        "source_snapshot_status"   => "reconstructed-and-verified",
        "source_snapshot_evidence" => "The 2018 mirror timestamps and all 23 historical solution objectives identify source commit 4b681a2.",
        "mirror_url"               => QPLIB_URL,
        "mirror_sha256"            => QPLIB_MIRROR_SHA256,
        "citation_doi"             => "10.1007/s12532-018-0147-4",
        "license_evidence_url"     => "https://qplib.zib.de/",
        "provenance_status"        => "verified",
        "rights_status"            => "verified",
        "provenance_note"          => "Later official-file drift is documented in DATASET.md.",
        "transformation_note"      => "QUBOLib redistributes a processed subset of 23 QBB instances, parsing QPLIB models, mapping SOL entries through LP variable names, and storing the results in HDF5 and SQLite.",
    ),
)

const QPLIB_INSTANCE_METADATA = Dict{String,NamedTuple}(
    "QPLIB_3506" => (
        origin = "MINLPLib",
        original_name = "sporttournament32",
        minlplib_name = "sporttournament32",
        primal_bound = 478.0,
        dual_bound = 484.0,
        proven_optimal = false,
    ),
    "QPLIB_3565" => (
        origin = "MINLPLib",
        original_name = "sporttournament24",
        minlplib_name = "sporttournament24",
        primal_bound = 282.0,
        dual_bound = 282.0,
        proven_optimal = true,
    ),
    "QPLIB_3642" => (
        origin = "MINLPLib",
        original_name = "sporttournament46",
        minlplib_name = "sporttournament46",
        primal_bound = 1034.0,
        dual_bound = 1070.944598,
        proven_optimal = false,
    ),
    "QPLIB_3650" => (
        origin = "MINLPLib",
        original_name = "sporttournament44",
        minlplib_name = "sporttournament44",
        primal_bound = 922.0,
        dual_bound = 956.3308189,
        proven_optimal = false,
    ),
    "QPLIB_3693" => (
        origin = "MINLPLib",
        original_name = "sporttournament48",
        minlplib_name = "sporttournament48",
        primal_bound = 1154.0,
        dual_bound = 1200.414098,
        proven_optimal = false,
    ),
    "QPLIB_3705" => (
        origin = "MINLPLib",
        original_name = "sporttournament28",
        minlplib_name = "sporttournament28",
        primal_bound = 384.0,
        dual_bound = 384.0,
        proven_optimal = true,
    ),
    "QPLIB_3706" => (
        origin = "MINLPLib",
        original_name = "sporttournament38",
        minlplib_name = "sporttournament38",
        primal_bound = 682.0,
        dual_bound = 699.029604,
        proven_optimal = false,
    ),
    "QPLIB_3738" => (
        origin = "MINLPLib",
        original_name = "sporttournament30",
        minlplib_name = "sporttournament30",
        primal_bound = 422.0,
        dual_bound = 425.0489482,
        proven_optimal = false,
    ),
    "QPLIB_3745" => (
        origin = "MINLPLib",
        original_name = "sporttournament26",
        minlplib_name = "sporttournament26",
        primal_bound = 334.0,
        dual_bound = 334.0,
        proven_optimal = true,
    ),
    "QPLIB_3822" => (
        origin = "MINLPLib",
        original_name = "sporttournament42",
        minlplib_name = "sporttournament42",
        primal_bound = 850.0,
        dual_bound = 878.5122339,
        proven_optimal = false,
    ),
    "QPLIB_3832" => (
        origin = "MINLPLib",
        original_name = "sporttournament34",
        minlplib_name = "sporttournament34",
        primal_bound = 554.0,
        dual_bound = 563.0,
        proven_optimal = false,
    ),
    "QPLIB_3838" => (
        origin = "MINLPLib",
        original_name = "sporttournament40",
        minlplib_name = "sporttournament40",
        primal_bound = 746.0,
        dual_bound = 775.0633203,
        proven_optimal = false,
    ),
    "QPLIB_3850" => (
        origin = "MINLPLib",
        original_name = "sporttournament50",
        minlplib_name = "sporttournament50",
        primal_bound = 1198.0,
        dual_bound = 1249.748958,
        proven_optimal = false,
    ),
    "QPLIB_3852" => (
        origin = "MINLPLib",
        original_name = "sporttournament22",
        minlplib_name = "sporttournament22",
        primal_bound = 234.0,
        dual_bound = 234.0,
        proven_optimal = true,
    ),
    "QPLIB_3877" => (
        origin = "MINLPLib",
        original_name = "sporttournament36",
        minlplib_name = "sporttournament36",
        primal_bound = 602.0,
        dual_bound = 611.5425502,
        proven_optimal = false,
    ),
    "QPLIB_5721" => (
        origin = "MINLPLib",
        original_name = "ising2_5-300_5555",
        minlplib_name = "ising2_5-300_5555",
        primal_bound = 8579363.0,
        dual_bound = 8656028.328,
        proven_optimal = false,
    ),
    "QPLIB_5725" => (
        origin = "MINLPLib",
        original_name = "toroidal3g7_6666",
        minlplib_name = "toroidal3g7_6666",
        primal_bound = 33611981.0,
        dual_bound = 33611981.0,
        proven_optimal = true,
    ),
    "QPLIB_5755" => (
        origin = "MINLPLib",
        original_name = "toroidal2g20_5555",
        minlplib_name = "toroidal2g20_5555",
        primal_bound = 24838942.0,
        dual_bound = 24838942.0,
        proven_optimal = true,
    ),
    "QPLIB_5875" => (
        origin = "BiqMac",
        original_name = "be200.8.4",
        minlplib_name = nothing,
        primal_bound = 43757.0,
        dual_bound = 43757.0,
        proven_optimal = true,
    ),
    "QPLIB_5881" => (
        origin = "BiqMac",
        original_name = "be120.3.1",
        minlplib_name = nothing,
        primal_bound = 13067.0,
        dual_bound = 13067.0,
        proven_optimal = true,
    ),
    "QPLIB_5882" => (
        origin = "BiqMac",
        original_name = "be150.8.9",
        minlplib_name = nothing,
        primal_bound = 25388.0,
        dual_bound = 25388.0,
        proven_optimal = true,
    ),
    "QPLIB_5909" => (
        origin = "BiqMac",
        original_name = "bqp250-8",
        minlplib_name = nothing,
        primal_bound = 35726.0,
        dual_bound = 35726.0,
        proven_optimal = true,
    ),
    "QPLIB_5922" => (
        origin = "BiqMac",
        original_name = "bqp500-2",
        minlplib_name = nothing,
        primal_bound = 128339.0,
        dual_bound = 128339.0,
        proven_optimal = true,
    ),
)

function build_qplib!(
    index::QUBOLib.LibraryIndex;
    cache::Bool = true,
    source_path::Union{AbstractString,Nothing} = nothing,
    codes = nothing,
)
    if QUBOLib.has_collection(index, "qplib")
        @info "[qplib] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, "qplib")
        end
    end

    @info "[qplib] Building QPLIB"

    QUBOLib.add_collection!(index, "qplib", QPLIB_DATA)

    data_path, code_list = if isnothing(source_path)
        loaded_codes = load_qplib!(index)
        (
            QUBOLib.cache_data_path(index, "qplib"),
            isnothing(codes) ? loaded_codes : collect(String, codes),
        )
    else
        dir = String(source_path)
        found_codes = [
            first(splitext(f)) for f in sort!(filter(endswith(".qplib"), readdir(dir)))
        ]
        (dir, isnothing(codes) ? found_codes : collect(String, codes))
    end

    @info "[qplib] Building index"

    for code in code_list
        mod_path = joinpath(data_path, "$(code).qplib")
        var_path = joinpath(data_path, "$(code).lp")
        sol_path = joinpath(data_path, "$(code).sol")

        model = QUBOTools.read_model(mod_path, Format(:qplib))
        info = get(QPLIB_INSTANCE_METADATA, code, nothing)
        inst_meta = if isnothing(info)
            nothing
        else
            Dict{String,Any}(
                "origin"                => info.origin,
                "original_name"         => info.original_name,
                "minlplib_name"         => info.minlplib_name,
                "upstream_primal_bound" => info.primal_bound,
                "dual_bound"            => info.dual_bound,
                "proven_optimal"        => info.proven_optimal,
            )
        end
        mod_i = QUBOLib.add_instance!(
            index,
            model,
            "qplib";
            name         = basename(mod_path),
            source_name  = isnothing(info) ? nothing : info.original_name,
            metadata     = inst_meta,
        )

        if isfile(sol_path)
            var_map = _get_qplib_var_map(var_path)

            sol = _read_qplib_solution(sol_path, model, var_map)

            if !isnothing(sol)
                ψ = QUBOTools.state(sol, 1)
                λ = QUBOTools.value(sol, 1)
                eval_val = QUBOTools.value(model, ψ)
                is_opt = !isnothing(info) && info.proven_optimal && isapprox(eval_val, info.primal_bound; atol = 1e-6)
                QUBOLib.add_solution!(
                    index,
                    mod_i,
                    sol;
                    qubo_value        = eval_val,
                    source_value      = λ,
                    source_objective  = λ,
                    objective_bound   = isnothing(info) ? nothing : info.primal_bound,
                    dual_bound        = isnothing(info) ? nothing : info.dual_bound,
                    proven_optimal    = is_opt,
                    validation_status = isapprox(eval_val, λ; atol = 1e-6) ? "validated" : "evaluated",
                )
            else
                @warn "[qplib] Failed to read solution for instance '$code'"
            end
        end
    end

    return nothing
end

function load_qplib!(index::QUBOLib.LibraryIndex)
    @assert Sys.isunix() "Processing QPLIB is only possible on Unix systems"

    data_path = mkpath(QUBOLib.cache_data_path(index, "qplib"))
    file_path = abspath(QUBOLib.cache_path(index, "qplib"), "qplib.zip")

    # Download QPLIB archive
    if isfile(file_path)
        @info "[qplib] Archive already downloaded"
    else
        @info "[qplib] Downloading archive"

        Downloads.download(QPLIB_URL, file_path)
    end

    # Extract QPLIB archive
    @assert run(`which unzip`, devnull, devnull).exitcode == 0 "'unzip' is required to extract QPLIB archive"

    @info "[qplib] Extracting archive"

    run(`unzip -qq -o -j $file_path -d $data_path`)

    # When getting from original source:
    # run(```
    # unzip -qq -o -j 
    #     $file_path
    #     'qplib/html/qplib/*'
    #     'qplib/html/sol/*'
    #     'qplib/html/lp/*'
    #     -d $data_path
    # ```)

    # Remove non-QUBO instances
    @info "[qplib] Removing non-QUBO instances"

    code_list = String[]

    for model_path in filter(endswith(".qplib"), readdir(data_path; join = true))
        code = readline(model_path)

        if !_is_qplib_qubo(model_path)
            rm(joinpath(data_path, "$(code).qplib"); force = true)
            rm(joinpath(data_path, "$(code).lp"); force = true)
            rm(joinpath(data_path, "$(code).sol"); force = true)
        else
            push!(code_list, code)
        end
    end

    return code_list
end

function deploy_qplib!(index::QUBOLib.LibraryIndex)
    close(index)

    src_path = QUBOLib.cache_data_path(index, "qplib")
    dst_path = mkpath(joinpath(QUBOLib.build_path(index), "mirror"))
    zip_path = joinpath(dst_path, "qplib.zip")

    run(`zip -q -j -r $zip_path $src_path`)

    return nothing
end
