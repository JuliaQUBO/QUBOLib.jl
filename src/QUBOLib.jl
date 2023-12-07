module QUBOLib

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

const __PROJECT__ = abspath(@__DIR__, "..")
const __VERSION__ = VersionNumber(TOML.parsefile(joinpath(__PROJECT__, "Project.toml"))["version"])

export load_instance, list_collections, list_instances, select

function data_path()::AbstractString
    # return abspath(artifact"qubolib")
    return @__DIR__
end

# Public API
include("public/interface.jl")
include("public/load.jl")
include("public/list.jl")
include("public/archive.jl")
include("public/database.jl")

# Data curation methods
include("curation/index.jl")

end # module QUBOLib
