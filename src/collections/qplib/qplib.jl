const QPLIB_URL = "http://qplib.zib.de/qplib.zip"

function metadata_path(::Val{:qplib})
    return bspath(@__DIR__, "metadata.json")
end

function get_metadata(coll::Val{:qplib}; validate::Bool = true)::Dict{String, Any}
    data = JSON.parsefile(metadata_path(coll))

    validate && validate_metadata(data)

    return data
end

function load_collection!(index::Index, coll::Val{:qplib}; cache::Bool = true)
    cache && check_cache(index, coll)
    
    Downloads.download()

    return nothing
end