function load_instance(collection::AbstractString, instance::AbstractString)
    return load_instance(data_path(), collection, instance)
end

function load_instance(path::AbstractString, collection::AbstractString, instance::AbstractString)
    return archive(path) do h5
        return QUBOTools.read_model(h5["collections"][collection][instance], QUBOTools.QUBin())
    end
end
