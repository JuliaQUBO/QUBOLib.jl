@doc raw"""
    AbstractProblem{T}
"""
abstract type AbstractProblem{T} end

@doc raw"""
    generate(problem)
    generate(rng, problem)

Generates a QUBO problem and returns it as a [`QUBOTools.Model`](@ref).
"""
function generate end
