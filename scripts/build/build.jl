import QUBOLib
import QUBOTools
import Downloads

include("arXiv_1903_10928_3r3x.jl")
include("arXiv_1903_10928_5r5x.jl")
include("qplib.jl")

function build_standard_qubolib(
    path::AbstractString = root_path();
    clear_build::Bool = false,
    clear_cache::Bool = false,
)
    @info "Building QUBOLib v$(QUBOLib.__version__())"

    if clear_build
        QUBOLib.clear_build(path)
    end

    if clear_cache
        QUBOLib.clear_cache(path)
    end

    close(QUBOLib.access(; path, create = true))

    QUBOLib.access(; path) do index
        build_arXiv_1903_10928_3r3x!(index)
    end

    # QUBOLib.access(; path) do index
    #     build_arXiv_1903_10928_5r5x!(index)
    # end

    QUBOLib.access(; path) do index
        build_qplib!(index)
    end

    return nothing
end


function main()
    build_standard_qubolib(
        QUBOLib.root_path();
        clear_build = ("--clear-build" ∈ ARGS),
        clear_cache = ("--clear-cache" ∈ ARGS),
    )

    return nothing
end

main() # Here we go!
