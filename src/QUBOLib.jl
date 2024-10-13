module QUBOLib

using LazyArtifacts
using SQLite
using DataFrames
using JuMP

import JSONSchema
import Pkg
import HDF5
import JSON
import Random

import QUBOTools
import PseudoBooleanOptimization as PBO

import TOML

include("project.jl")

const QUBOLIB_SQL_PATH       = joinpath(@__DIR__, "assets", "qubolib.sql")
const COLLECTION_SCHEMA_PATH = joinpath(@__DIR__, "assets", "collection.schema.json")
const COLLECTION_SCHEMA      = JSONSchema.Schema(JSON.parsefile(COLLECTION_SCHEMA_PATH))

const QUBOLIB_LOGO = raw"""
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  ▄██████▄   ██    ██  █████▄   ▄██████▄ ┃
┃ ██      ██  ██    ██  ██   ██  ██    ██ ┃
┃ ██      ██  ██    ██  ██████   ██    ██ ┃
┃ ██  ▀▀▄███  ██    ██  ██   ██  ██    ██ ┃
┃  ▀██████▀▄▄ ▀██████▀  █████▀   ▀██████▀ ┃
┃                                         ┃
┃  ██       ██  ██      ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲  ┃
┃  ██           ██      ╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱  ┃
┃  ██       ██  █████▄                    ┃
┃  ██       ██  ██  ██  ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲  ┃
┃  ███████  ██  █████▀  ╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
"""

function print_logo(io::IO = stdout)
    println(io, QUBOLIB_LOGO)

    return nothing
end

include("interface.jl")

include("library/index.jl")
include("library/path.jl")
include("library/access.jl")

include("library/instances.jl")
include("library/collections.jl")
include("library/solvers.jl")
include("library/solutions.jl")

include("library/synthesis/Synthesis.jl")

end # module QUBOLib
