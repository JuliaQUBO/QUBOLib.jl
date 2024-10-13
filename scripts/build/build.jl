using JuliaFormatter
using LaTeXStrings
import Downloads

import QUBOLib
import QUBOTools

include("library/clear.jl")
include("library/deploy.jl")

include("sources/hen.jl")
include("sources/qplib.jl")

function build_standard_qubolib(
    path::AbstractString;
    clear_cache::Bool = false,
    clear_build::Bool = false,
)
    @info "Building QUBOLib v$(QUBOLib.__version__()) @ $(path)"

    if clear_cache
        @info "[Clearing Cache]"

        clear_cache!(path)
    end

    if clear_build
        @info "[Clearing Build]"

        QUBOLib.access(; path, clear = true) |> close
    end

    QUBOLib.access(; path) do index
        build_hen!(index)
    end

    QUBOLib.access(; path) do index
        build_qplib!(index)
    end

    return nothing
end

function main(args::Vector{String} = ARGS)
    QUBOLib.print_logo(stdout)

    build_standard_qubolib(
        QUBOLib.root_path();
        clear_cache = ("--clear-cache" ∈ args),
        clear_build = ("--clear-build" ∈ args),
    )

    return nothing
end
