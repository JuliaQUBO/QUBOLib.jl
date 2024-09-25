@doc raw"""
    XORSAT{T}

``r``-regular ``k``-XORSAT
"""
struct XORSAT{T} <: AbstractProblem{T}
    n::Int
    r::Int
    k::Int

    function XORSAT{T}(n::Integer, r::Integer = 3, k::Integer = 3) where {T}
        return new{T}(n, r, k)
    end
end

function generate(problem::XORSAT{T}, ::BoolDomain) where {T}

end

function generate(rng, problem::XORSAT{T}, ::SpinDomain; kws...) where {T}
    return cast(𝔹 => 𝕊, generate(rng, problem, 𝔹)...; kws...)
end
