@doc raw"""
    SK{T}

Sherrington-Kirkpatrick Model
"""
struct SK{T} <: AbstractProblem{T}
    n::Int

    function SK{T}(n::Integer) where {T}
        return new{T}(n)
    end
end

function generate(rng, problem::SK{T}, ::SpinDomain) where {T}
    n = problem.n # number of variables

    # Ising Interactions
    h = Dict{Int,T}()
    J = sizehint!(Dict{Tuple{Int,Int},T}(), (n * (n - 1)) ÷ 2)

    for i = 1:n, j = (i+1):n
        J[(i,j)] = randn(rng, T)
    end

    α = one(T)
    β = zero(T)

    return (h, J, α, β)
end

function generate(rng, problem::SK{T}, ::BoolDomain; kws...) where {T}
    return cast(𝕊 => 𝔹, generate(rng, problem, 𝕊)...; kws...)
end