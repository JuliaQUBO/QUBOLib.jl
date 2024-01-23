function metadata_schema_path()
    return abspath(@__DIR__, "metadata.schema.json")
end

function metadata_schema()
    return JSONSchema.Schema(JSON.parsefile(metadata_schema_path()))
end

function validate_metadata(data::Dict{String, Any})
    report = JSONSchema.validate(metadata_schema(), data)

    if !isnothing(report)
        error(
            """
            Invalid collection metadata for $(collection):
            $(report)
            """
        )
    end

    return nothing
end

function get_metadata(index::Index, collection::AbstractString; validate::Bool=true)
    metapath = joinpath(index.list_path, collection, "metadata.json")
    metadata = JSON.parsefile(metapath)

    if validate
        validate_metadata(metadata)
    end

    return metadata
end