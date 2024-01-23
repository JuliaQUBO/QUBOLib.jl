module QUBOLib

using LazyArtifacts
using HDF5
using JSON
using Downloads
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

# function data_path()::AbstractString
#     return abspath(artifact"qubolib")
# end

# Data management methods
# include("management/index.jl")

# Public API
# include("access/interface.jl")
# include("access/load.jl")
# include("access/list.jl")
# include("access/archive.jl")
# include("access/database.jl")

end # module QUBOLib
