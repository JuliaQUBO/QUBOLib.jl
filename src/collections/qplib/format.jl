@doc raw"""
    QPLIB

Format specification for reading QPLIB instances.
"""
struct QPLIB <: QUBOTools.AbstractFormat end

QUBOTools.format(::Val{:qplib}) = QPLIB()

function QUBOTools.read_model(io::IO, ::QPLIB)
    # Read the header
    code = readline(io)

    @assert !isnothing(match(r"(QBB)", readline(io)))

    sense = readline(io)

    @assert sense ∈ ("minimize", "maximize")

    vn = parse(Int, readline(io)) # number of variables

    V = Set{Int}(1:vn)
    L = Dict{Int, Float64}()
    Q = Dict{Tuple{Int, Int}, Float64}()

    qn = parse(Int, readline(io)) # number of quadratic terms in objective

    sizehint!(Q, qn)

    for _ in 1:qn
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
        for i in 1:vn
            L[i] = dl
        end
    end

    for _ in 1:ln
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
        V, L, Q;
        offset      = β,
        domain      = :bool,
        sense       = (sense == "minimize") ? :min : :max,
        description = "QPLib code '$code'",
    )
end
