module Management

using ..QUBOLib
using LazyArtifacts
using HDF5
using JSON
using JSONSchema
using JuliaFormatter
using LaTeXStrings
using SQLite
using DataFrames
using Tar
using TOML
using Pkg
using UUIDs
using QUBOTools
using ProgressMeter

include("index.jl")

function get_metadata(coll::String)
    return get_metadata(Symbol(coll))
end

function get_metadata(coll::Symbol)
    return get_metadata(Val(coll))
end

function set_metadata(coll::Symbol, metadata::Dict{String, Any})
    return set_metadata(Val(coll), metadata)
end

function validate_metadata(data::Dict{String, Any})
    @assert isnothing(JSONSchema.validate(data, COLLECTION_SCHEMA))

    return nothing
end


end