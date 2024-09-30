@doc raw"""
    AbstractProblem{T}
"""
abstract type AbstractProblem{T} end

@doc raw"""
    generate(problem::AbstractProblem{T}) where {T}
    generate(rng, problem::AbstractProblem{T}) where {T}

Generates a QUBO problem and returns it as a [`QUBOTools.Model`](@extref).
"""
function generate end
