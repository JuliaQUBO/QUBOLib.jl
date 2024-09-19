module QUBOLib

using ArgParse
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

const QUBOLIB_LOGO = """
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  ██████  ██    ██ ██████   ██████  ┃
┃ ██    ██ ██    ██ ██   ██ ██    ██ ┃
┃ ██    ██ ██    ██ ██████  ██    ██ ┃
┃ ██ ▄▄ ██ ██    ██ ██   ██ ██    ██ ┃
┃  ██████   ██████  ██████   ██████  ┃
┃     ▀▀                             ┃
┃  ██      ██ ██       ▒▒▒▒▒▒▒▒▒▒▒▒  ┃
┃  ██         ██       ▒▒▒▒▒▒▒▒▒▒▒▒  ┃
┃  ██      ██ ██████   ▒▒▒▒▒▒▒▒▒▒▒▒  ┃
┃  ██      ██ ██  ██   ▒▒▒▒▒▒▒▒▒▒▒▒  ┃
┃  ███████ ██ ██████   ▒▒▒▒▒▒▒▒▒▒▒▒  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
"""

function print_logo(io::IO = stdout)
    println(io, QUBOLIB_LOGO)

    return nothing
end

include("interface/interface.jl")

include("library/path.jl")
include("library/index/index.jl")

include("library/register.jl")
include("library/build.jl")

include("synthesis/abstract.jl")
include("synthesis/sherrington_kirkpatrick.jl")
include("synthesis/wishart.jl")

include("main.jl")

end # module QUBOLib
