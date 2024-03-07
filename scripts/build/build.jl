using QUBOTools
using QUBOLib
using Downloads

# Standard Library
include("qplib.jl")
include("arXiv_1903_10928_3r3x.jl")
include("arXiv_1903_10928_5r5x.jl")

function build_standard_qubolib(
    path::AbstractString = root_path();
    clear_build::Bool = false,
    clear_cache::Bool = false,
)
    @info "Building QUBOLib v$(QUBOLib.__VERSION__)"

    if clear_build
        @info "Clearing Build"

        rm(QUBOLib.build_path(path); force = true, recursive = true)
    end

    if clear_cache
        @info "Clearing Cache"

        rm(QUBOLib.cache_path(path); force = true, recursive = true)
    end

    QUBOLib.load_index(path; create = true) do index
        build_qplib!(index)
        build_arXiv_1903_10928_3r3x!(index)
        build_arXiv_1903_10928_5r5x!(index)
    end

    return nothing
end


function main()
    QUBOLib.logo()

    build_standard_qubolib(
        QUBOLib.root_path();
        clear_build = ("--clear-build" ∈ ARGS),
        clear_cache = ("--clear-cache" ∈ ARGS),
    )

    return nothing
end

main() # Here we go!
