function has_collection(index::LibraryIndex, collection::AbstractString)
    @assert isopen(index)

    db = QUBOLib.database(index)
    df = DBInterface.execute(
        db,
        "SELECT COUNT(*) FROM collections WHERE collection = ?",
        (String(collection),)
    ) |> DataFrame

    return only(df[!, 1]) > 0
end

function _collection_metadata_value(metadata)
    if isnothing(metadata) || ismissing(metadata)
        return missing
    elseif metadata isa AbstractString
        return String(metadata)
    else
        return JSON.json(metadata)
    end
end

function add_collection!(
    index::LibraryIndex,
    collection::AbstractString,
    data::Dict{String,Any},
)
    @assert isopen(index)

    if has_collection(index, collection)
        error("Collection '$collection' already exists")
    end

    let report = JSONSchema.validate(data, COLLECTION_SCHEMA)
        if !isnothing(report)
            error("Invalid collection data:\n$report")
        end
    end

    db = QUBOLib.database(index)

    DBInterface.execute(
        db,
        """
        INSERT INTO collections
            (
                collection,
                name,
                author,
                year,
                description,
                url,
                license,
                data_license,
                citation,
                metadata
            )
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            String(collection),
            get(data, "name", String(collection)),
            haskey(data, "author") ? join(data["author"], " and ") : missing,
            get(data, "year", missing),
            get(data, "description", missing),
            get(data, "url", missing),
            get(data, "license", missing),
            get(data, "data_license", missing),
            get(data, "citation", missing),
            _collection_metadata_value(get(data, "metadata", missing)),
        ),
    )

    return nothing
end

function remove_collection!(index::LibraryIndex, collection::AbstractString)
    @assert isopen(index)

    if !has_collection(index, collection)
        error("Collection '$collection' does not exist")
    else
        DBInterface.execute(
            index.db,
            "DELETE FROM collections WHERE collection = ?",
            (String(collection),),
        )

        @info "Collection '$collection' removed from index"
    end

    return nothing
end

remove_collection!(index::LibraryIndex, collection::Symbol) =
    remove_collection!(index, string(collection))

# Queries

function collection_size(index::LibraryIndex, collection::AbstractString)
    @assert isopen(index)
    @assert has_collection(index, collection)

    db = database(index)

    df = DBInterface.execute(
        db,
        "SELECT COUNT(*) FROM instances WHERE collection = ?;",
        [String(collection)]
    ) |> DataFrame

    return only(df[!, begin])::Integer
end
