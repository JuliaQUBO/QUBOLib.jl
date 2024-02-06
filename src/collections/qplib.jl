# Define codec for QPLIB format

function _read_qplib_model(path::AbstractString)
    return open(path, "r") do io
        _read_qplib_model(io)
    end
end

function _read_qplib_model(io::IO)
    # Read the header
    code = readline(io)

    @assert !isnothing(match(r"(QBB)", readline(io)))

    sense = readline(io)

    @assert sense ∈ ("minimize", "maximize")

    nv = parse(Int, readline(io)) # number of variables

    V = Set{Int}(1:nv)
    L = Dict{Int,Float64}()
    Q = Dict{Tuple{Int,Int},Float64}()

    nq = parse(Int, readline(io)) # number of quadratic terms in objective

    sizehint!(Q, nq)

    for _ = 1:nq
        m = match(r"([0-9]+)\s+([0-9+])\s+(\S+)", readline(io))
        i = parse(Int, m[1])
        j = parse(Int, m[2])
        c = parse(Float64, m[3])

        Q[(i, j)] = c
    end

    dl = parse(Float64, readline(io)) # default value for linear coefficients in objective
    ln = parse(Int, readline(io)) # number of non-default linear coefficients in objective

    sizehint!(L, ln)

    if !iszero(dl)
        for i = 1:nv
            L[i] = dl
        end
    end

    for _ = 1:ln
        m = match(r"([0-9]+)\s+(\S+)", readline(io))
        i = parse(Int, m[1])
        c = parse(Float64, m[2])

        L[i] = c
    end

    β = parse(Float64, readline(io)) # objective constant

    @assert isfinite(parse(Float64, readline(io))) # value for infinity
    @assert isfinite(parse(Float64, readline(io))) # default variable primal value in starting point
    @assert iszero(parse(Int, readline(io))) # number of non-default variable primal values in starting point

    @assert isfinite(parse(Float64, readline(io))) # default variable bound dual value in starting point
    @assert iszero(parse(Int, readline(io))) # number of non-default variable bound dual values in starting point

    @assert iszero(parse(Int, readline(io))) # number of non-default variable names
    @assert iszero(parse(Int, readline(io))) # number of non-default constraint names

    return QUBOTools.Model{Int,Float64,Int}(
        V,
        L,
        Q;
        offset = β,
        domain = :bool,
        sense  = (sense == "minimize") ? :min : :max,
        description = "QPLib instance '$code'",
    )
end

function _read_qplib_solution(path::AbstractString, model::QUBOTools.Model{Int,Float64,Int})
    open(path, "r") do io
        _read_qplib_solution!(io, model)
    end

    return nothing
end

function _read_qplib_solution!(io::IO, model::QUBOTools.Model{Int,Float64,Int})
    # Read the header
    value = let
        m = match(r"objvar\s+([\S]+)", readline(io))

        if isnothing(m)
            QUBOTools.syntax_error("Invalid header")

            return nothing
        end

        tryparse(Float64, m[1])
    end

    if isnothing(value)
        QUBOTools.syntax_error("Invalid objective value")
    end

    v = Tuple{Int,Float64}[]
    n = 0

    for line in eachline(io)
        i, λ = let
            m = match(r"b([0-9]+)\s+([\S]+)", line)

            if isnothing(m)
                QUBOTools.syntax_error("Invalid solution input")

                return nothing
            end

            (tryparse(Int, m[1]), tryparse(Float64, m[2]))
        end

        if isnothing(i) || isnothing(λ)
            QUBOTools.syntax_error("Invalid variable assignment")

            return nothing
        end

        n = max(n, i)

        push!(v, (i, λ))
    end

    ψ = zeros(Int, n)

    for (i, λ) in v
        ψ[i] = ifelse(iszero(λ), 0, 1)
    end

    s = QUBOTools.Sample{Float64,Int}[QUBOTools.Sample{Float64,Int}(ψ, λ)]

    sol = QUBOTools.SampleSet{Float64,Int}(
        s;
        sense  = QUBOTools.sense(model),
        domain = :bool,
    )

    QUBOTools.attach!(model, sol)
end

function _is_qplib_qubo(path::AbstractString)
    @assert isfile(path) && endswith(path, ".qplib")

    return open(path, "r") do io
        ____ = readline(io)
        type = readline(io)

        return (type == "QBB")
    end
end

const QPLIB_URL = "http://qplib.zib.de/qplib.zip"

function build!(index::LibraryIndex, coll::Collection{:qplib})
    load!(coll)

    @info "[qplib] Building index"

    qplib_data_path = abspath(cache_path(), "qplib", "data")

    return nothing
end

function load!(::Collection{:qplib})
    @assert Sys.isunix() "Processing QPLIB is only possible on Unix systems"

    qplib_cache_path = mkpath(abspath(cache_path(), "qplib"))
    qplib_data_path  = mkpath(abspath(qplib_cache_path, "data"))
    qplib_zip_path   = abspath(qplib_cache_path, "qplib.zip")

    # Download QPLIB archive
    if isfile(qplib_zip_path)
        @info "[qplib] Archive already downloaded"
    else
        @info "[qplib] Downloading archive"
        Downloads.download(QPLIB_URL, qplib_zip_path)
    end

    # Extract QPLIB archive
    @assert run(`which unzip`, devnull, devnull).exitcode == 0 "'unzip' is required to extract QPLIB archive"

    @info "[qplib] Extracting archive"

    run(
        `unzip -qq -o -j  $qplib_zip_path 'qplib/html/qplib/*' 'qplib/html/sol/*' -d $qplib_data_path`,
    )

    # Remove non-QUBO instances
    @info "[qplib] Removing non-QUBO instances"

    for file_path in filter(endswith(".qplib"), readdir(qplib_data_path; join = true))
        if !_is_qplib_qubo(file_path)
            code = readline(file_path)

            rm(joinpath(qplib_data_path, "$(code).qplib"); force = true)
            rm(joinpath(qplib_data_path, "$(code).sol"); force = true)
        end
    end

    return nothing
end

# Add QPLIB to the standard collection list
push!(COLLECTIONS, :qplib)
