struct LibraryIndex
    db::SQLite.DB
    fp::HDF5.File

    collections::Vector{Symbol}

    metadata::Dict{String,Any}
end

function LibraryIndex(db::SQLite.DB, fp::HDF5.File)
    return LibraryIndex(db, fp, Symbol[], Dict{String,Any}())
end

function Base.isopen(index::LibraryIndex)
    return isopen(index.db) && isopen(index.fp)
end

function Base.close(index::LibraryIndex)
    close(index.db)
    close(index.fp)

    return nothing
end

function _create_index(path::AbstractString)
    db = _create_database(database_path(path))
    fp = _create_archive(archive_path(path))

    return LibraryIndex(db, fp)
end

@doc raw"""
    load_index(path::AbstractString)

Loads the library index from the given path.
"""
function load_index(path::AbstractString; create::Bool=false)
    db = _load_database(database_path(path))
    fp = _load_archive(archive_path(path))

    if isnothing(db) || isnothing(fp)
        if create
            @info "Creating index at '$path'"

            return _create_index(path)
        else 
            error("Failed to load index from '$path'")

            return nothing
        end
    end

    return LibraryIndex(db, fp)
end

function load_index(callback::Function, path::AbstractString=qubolib_path(); create::Bool=false)
    index = load_index(path; create)

    @assert isopen(index)

    try
        return callback(index)
    finally
        close(index)
    end
end

function has_collection(index::LibraryIndex, code::Symbol)
    @assert isopen(index)

    df = DBInterface.execute(
        index.db,
        "SELECT COUNT(*) FROM collections WHERE collection = ?",
        (code,)
    ) |> DataFrame

    return only(df[!, 1]) > 0
end

function has_collection(index::LibraryIndex, ::Collection{code}) where {code}
    return has_collection(index, code)
end
