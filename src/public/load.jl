function load_instance(collection::AbstractString, instance::AbstractString)
    return load_instance(artifact"collections", collection, instance)
end

function load_instance(path::AbstractString, collection::AbstractString, instance::AbstractString)
    collpath = joinpath(path, collection)

    if !isdir(collpath)
        error("Unknown collection '$collection'")
    end

    instpath = joinpath(collpath, "data", instance)
    
    if !isfile(instpath)
        error("Unknown instance '$instance'")
    end
    
    # QUBOTools must be able to infer the format from the file extension
    return QUBOTools.read_model(instpath)
end
