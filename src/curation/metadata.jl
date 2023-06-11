const _METADATA_SCHEMA = JSONSchema.Schema(JSON.parsefile(joinpath(@__DIR__, "metadata.schema.json")))

function _metadata(path::AbstractString, collection::AbstractString; validate::Bool = true)
    metapath = joinpath(path, collection, "metadata.json")
    metadata = JSON.parsefile(metapath)

    if validate
        report = JSONSchema.validate(_METADATA_SCHEMA, metadata)

        if !isnothing(report)
            error(
                """
                Invalid collection metadata for $(collection):
                $(report)
                """
            )
        end
    end

    return metadata
end
