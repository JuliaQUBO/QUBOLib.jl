function clear_cache!(path::AbstractString = QUBOLib.root_path())
    rm(QUBOLib.cache_path(path); force = true, recursive = true)

    return nothing
end
