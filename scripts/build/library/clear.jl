function clear_build(path::AbstractString = QUBOLib.root_path())
    rm(build_path(path; ifmissing = identity); force = true, recursive = true)

    return nothing
end

function clear_cache(path::AbstractString = QUBOLib.root_path())
    rm(cache_path(path; ifmissing = identity); force = true, recursive = true)

    return nothing
end
