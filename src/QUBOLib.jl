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

const __PROJECT__ = Ref{Union{String,Nothing}}(nothing)

function __project__()
    if isnothing(__PROJECT__[])
        proj_path = abspath(dirname(@__DIR__))
    
        @assert isdir(proj_path)
    
        __PROJECT__[] = proj_path
    end

    return __PROJECT__[]::String
end

const __VERSION__ = Ref{Union{VersionNumber,Nothing}}(nothing)

function __version__()::VersionNumber
    if isnothing(__VERSION__[])
        proj_file_path = abspath(__project__(), "Project.toml")

        @assert isfile(proj_file_path)

        proj_file_data = TOML.parsefile(proj_file_path)

        __VERSION__[] = VersionNumber(proj_file_data["version"])
    end

    return __VERSION__[]::VersionNumber
end

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
include("library/synthesis.jl")

include("actions/clear.jl")

include("main.jl")

end # module QUBOLib
