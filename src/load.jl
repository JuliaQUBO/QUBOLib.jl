function load_instance(
    collection::AbstractString,
    instance::AbstractString;
    format::Union{QUBOTools.AbstractFormat,Nothing} = nothing
)
    return load_instance(collection, "data", instance; format)
end

function load_instance(
    path::AbstractString...;
    format::Union{QUBOTools.AbstractFormat,Nothing} = nothing
)
    filepath = joinpath(collections, path...)

    if !isfile(filepath)
        error("Unknown instance '$path'")
    end

    if isnothing(format)
        return QUBOTools.read_model(filepath, QUBOTools.infer_format(filepath))
    else
        return QUBOTools.read_model(filepath, format)
    end
end
