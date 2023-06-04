function list_collections()
    return basename.(filter(isdir, readdir(collections; join = true)))
end

function list_instances(collection::AbstractString)
    datapath = joinpath(collections, collection, "data")

    return readdir(datapath; join = false)
end
