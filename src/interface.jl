@doc raw"""
    add_collection!(index::LibraryIndex, code::Symbol, data::Dict{String,Any})

Creates a new collection in the library index.
"""
function add_collection! end

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
