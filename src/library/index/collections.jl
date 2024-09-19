const COLLECTION_DATA_SCHEMA = JSONSchema.Schema(
    JSON.parsefile(joinpath(@__DIR__, "collection-data.schema.json"))
)

function has_collection(index::LibraryIndex, code::Symbol)
    @assert isopen(index)

    df = DBInterface.execute(
        index.db,
        "SELECT COUNT(*) FROM collections WHERE collection = ?",
        (string(code),)
    ) |> DataFrame

    return only(df[!, 1]) > 0
end

function add_collection!(
    index::LibraryIndex,
    code::Symbol,
    data::Dict{String,Any}
)
    @assert isopen(index)

    let report = JSONSchema.validate(data, COLLECTION_DATA_SCHEMA)
        if !isnothing(report)
            error("Invalid collection data:\n$report")
        end
    end
    
    if has_collection(index, code)
        error("Collection '$code' already exists")
    else
        DBInterface.execute(
            index.db,
            "INSERT INTO collections (collection, name) VALUES (?, ?)",
            (
                string(code),
                data["name"],
            )
        )

        @info "Collection '$code' added to index"
    end

    return nothing
end

function remove_collection!(index::LibraryIndex, code::Symbol)
    @assert isopen(index)

    if !has_collection(index, code)
        error("Collection '$code' does not exist")
    else
        DBInterface.execute(
            index.db,
            "DELETE FROM collections WHERE code = ?",
            (string(code),)
        )

        @info "Collection '$code' removed from index"
    end

    return nothing
end
