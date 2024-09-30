@doc raw"""
    NAE3SAT{T}(m::Integer, n::Integer)

Not-all-equal 3-SAT on ``m`` clauses and ``n`` variables.
"""
struct NAE3SAT{T} <: AbstractProblem{T}
    m::Int 
    n::Int
    ratio::Float64

    function NAE3SAT{T}(m::Integer, n::Integer) where {T}
        @assert(n >= 3, "number of variables must be at least 3")

        return new{T}(m, n, m / n)
    end
end

@doc raw"""
    NAE3SAT{T}(n::Integer, ratio::Real = 2.11)

Not-all-equal 3-SAT on ``n`` variables with number of clauses defined
by the *clause-to-variable* ratio.
"""
function NAE3SAT{T}(n::Integer, ratio::Real = 2.11) where {T}
    @assert(ratio > 0, "ratio must be positive")

    return NAE3SAT{T}(trunc(Int, n * ratio), n, ratio)
end

function generate(rng, problem::NAE3SAT{T}) where {T}
    m = problem.m # number of clauses
    n = problem.n # number of variables

    # Ising Interactions
    h = Dict{Int,T}()
    J = Dict{Tuple{Int,Int},T}()

    C = BitSet(1:n)

    c = Vector{Int}(undef, 3)
    s = Vector{Int}(undef, 3)

    for _ = 1:problem.m
        union!(C, 1:problem.n)

        for j = 1:3
            c[j] = pop!(C, rand(rng, C))
        end
        
        s .= rand(rng, (↑,↓), 3)

        for i = 1:3, j = (i+1):3
            x = (c[i], c[j])

            J[x] = get(J, x, zero(T)) + s[i] * s[j]
        end
    end

    return QUBOTools.Model{Int,T,Int}(
        h,
        J,
        domain   = :spin,
        metadata = Dict{String,Any}(
            "origin"    => "QUBOLib.jl",
            "synthesis" => Dict{String,Any}(
                "problem"    => "Not-all-equal 3-SAT",
                "parameters" => Dict{String,Any}(
                    "m"     => problem.m,
                    "n"     => problem.n,
                    "ratio" => problem.ratio,
                ),
            ),
        )
    )
end
