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

# Standard Collection List
const COLLECTIONS = Symbol[]

# Library
include("logo.jl")
include("path.jl")
include("collection.jl")
include("database.jl")
include("archive.jl")
include("index.jl")
include("build.jl")

# Collections
include("collections/qplib.jl")

end # module QUBOLib
