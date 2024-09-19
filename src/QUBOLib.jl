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
using QUBODrivers
using JuMP
using SparseArrays
using ProgressMeter

import Random
import QUBOTools
import PseudoBooleanOptimization as PBO

const __PROJECT__ = abspath(@__DIR__, "..")
const __VERSION__ = VersionNumber(TOML.parsefile(joinpath(__PROJECT__, "Project.toml"))["version"])

export LibraryIndex

include("logo.jl")
include("path.jl")
include("interface.jl")

include("index/index.jl")

include("synthesis/abstract.jl")
include("synthesis/sherrington_kirkpatrick.jl")
include("synthesis/wishart.jl")

include("run.jl")

end # module QUBOLib
