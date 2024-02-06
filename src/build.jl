function build(path::AbstractString = root_path(); clear_cache::Bool=false)
    @info "Building QUBOLib v$(QUBOLib.__VERSION__)"

    if clear_cache
        @info "Clearing Cache"

        rm(QUBOLib.cache_path(path); force=true, recursive=true)
    end

    @info "Retrieving Library Index"

    QUBOLib.load_index(path; create=true) do index
        for code in QUBOLib.COLLECTIONS
            if !QUBOLib.has_collection(index, code)
                QUBOLib.build!(index, code)
            end
        end
    end
end

function build!(index::LibraryIndex, code::Symbol)
    @info "Building Collection: '$code'"

    return build!(index, Collection(code))
end
