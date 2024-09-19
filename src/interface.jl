@doc raw"""
    add_collection!(index::LibraryIndex, code::Symbol, data::Dict{String,Any})

Creates a new collection in the library index.
"""
function add_collection! end

@doc raw"""
    add_solver!(index::LibraryIndex, code::Symbol, data::Dict{String,Any})

Registers a new solver in the library index.
"""
function add_solver! end

@doc raw"""
    add_instance!(index::LibraryIndex, coll::Symbol, model::QUBOTools.Model{Int,Float64,Int})

Adds a new instance to the library index.
"""
function add_instance! end

@doc raw"""
    add_solution!(index::LibraryIndex, instance::Integer, sol::SampleSet{Float64,Int})

Adds a new solution to the library index.

The `sol` argument is a sample set, which is a collection of samples and their respective energies.
"""
function add_solution! end

@doc raw"""
    run!(index::LibraryIndex, instance::Integer, optimizer)
    run!(index::LibraryIndex, instances::Vector{U}, optimizer) where {U<:Integer}
"""
function run! end

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
