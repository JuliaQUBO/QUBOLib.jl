module QUBOLib

using ArgParse
using LazyArtifacts
using Downloads
using JuliaFormatter
using LaTeXStrings
using SQLite
using DataFrames
using UUIDs
using JuMP
using SparseArrays
using ProgressMeter

import JSONSchema
import Tar
import TOML
import Pkg
import HDF5
import JSON
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

const QUBOLIB_SQL_PATH       = joinpath(@__DIR__, "assets", "qubolib.sql")
const COLLECTION_SCHEMA_PATH = joinpath(@__DIR__, "assets", "collection.schema.json")
const COLLECTION_SCHEMA      = JSONSchema.Schema(JSON.parsefile(COLLECTION_SCHEMA_PATH))

const QUBOLIB_LOGO = """
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  ▄██████▄   ██    ██  █████▄   ▄██████▄ ┃
┃ ██      ██  ██    ██  ██   ██  ██    ██ ┃
┃ ██      ██  ██    ██  ██████   ██    ██ ┃
┃ ██  ▀▀▄███  ██    ██  ██   ██  ██    ██ ┃
┃  ▀██████▀▄▄ ▀██████▀  █████▀   ▀██████▀ ┃
┃                                         ┃
┃  ██       ██  ██      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ ┃
┃  ██           ██      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ ┃
┃  ██       ██  █████▄  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ ┃
┃  ██       ██  ██  ██  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ ┃
┃  ███████  ██  █████▀  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
"""

function print_logo(io::IO = stdout)
    println(io, QUBOLIB_LOGO)

    return nothing
end

include("interface.jl")

include("library/path.jl")
include("library/index.jl")
include("library/access.jl")

include("library/synthesis/Synthesis.jl")

include("main.jl")

end # module QUBOLib
