@doc raw"""
    NAE3SAT{T}

Not-all-equal 3-SAT
"""
struct NAE3SAT{T} <: AbstractProblem{T}
    m::Int 
    n::Int 

    function NAE3SAT{T}(m::Integer, n::Integer) where {T}
        @assert n >= 3

        return new{T}(m, n)
    end 

    function NAE3SAT{T}(n::Integer, ratio = 2.11) where {T}
        m = trunc(Int, n * ratio)

        return NAE3SAT{T}(m, n)
    end
end

function generate(rng, problem::NAE3SAT{T}, ::SpinDomain) where {T}
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

    α = one(T)
    β = zero(T)

    return (h, J, α, β)
end

function generate(rng, problem::NAE3SAT{T}, ::BoolDomain) where {T}
    return cast(𝕊 => 𝔹, generate(rng, problem, 𝕊)...)
end
