function _list_collections(path::AbstractString)
    return basename.(filter(isdir, readdir(path; join = true)))
end

function _list_instances(path::AbstractString, collection::AbstractString)
    datapath = joinpath(path, collection, "data")

    return readdir(datapath; join = false)
end
