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

function add_collection!(
    index::LibraryIndex,
    collection::AbstractString,
    data::Dict{String,Any}
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
            (collection, name, author, year, description, url)
        VALUES
            (?, ?, ?, ?, ?, ?)
        """,
        (
            String(collection),
            get(data, "name", String(collection)),
            haskey(data, "author") ? join(data["author"], " and ") : missing,
            get(data, "year", missing),
            get(data, "description", missing),
            get(data, "url", missing),
        )
    )

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
