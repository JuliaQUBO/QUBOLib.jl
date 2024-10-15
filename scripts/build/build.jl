import Pkg
import Tar
import Downloads

import QUBOLib
import QUBOTools

using JuliaFormatter
using LaTeXStrings

include("library/clear.jl")
include("library/deploy.jl")

include("sources/hen.jl")
include("sources/qplib.jl")

function build_qubolib!(
    path::AbstractString = pwd();
    deploy::Bool = false,
    clear_cache::Bool = false,
    clear_build::Bool = false,
)
    @info "Building QUBOLib v$(QUBOLib.__version__()) @ '$path'"

    if clear_cache
        @info "[QUBOLib] Clear Cache"

        clear_cache!(path)
    end

    if clear_build
        @info "[QUBOLib] Clear Build"

        QUBOLib.access(; path, clear = true) |> close
    end

    QUBOLib.access(; path) do index
        build_hen!(index)
    end

    QUBOLib.access(; path) do index
        build_qplib!(index)
    end

    @info "[QUBOLib] Build done!"

    if deploy
        @info "[QUBOLib] Deploy Library"

        QUBOLib.access(; path) do index
            deploy_qubolib!(index)
            deploy_hen!(index)
            deploy_qplib!(index)
        end
    end

    return nothing
end

function main(args::Vector{String} = ARGS)
    QUBOLib.print_logo(stdout)

    build_qubolib!(
        pwd();
        deploy      = ("--deploy" ∈ args),
        clear_cache = ("--clear-cache" ∈ args),
        clear_build = ("--clear-build" ∈ args),
    )

    return nothing
end
