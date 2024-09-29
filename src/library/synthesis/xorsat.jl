@doc raw"""
    XORSAT{T}(n::Integer, r::Integer = 3, k::Integer = 3)

``r``-regular ``k``-XORSAT on ``n`` variables.
"""
struct XORSAT{T} <: AbstractProblem{T}
    n::Int
    r::Int
    k::Int

    function XORSAT{T}(n::Integer, r::Integer = 3, k::Integer = 3) where {T}
        return new{T}(n, r, k)
    end
end

function generate(rng, problem::XORSAT{T}) where {T}

end
