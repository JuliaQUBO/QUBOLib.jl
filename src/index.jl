include("index/database.jl")
include("index/archive.jl")

@doc raw"""
    LibraryIndex

The QUBOLib index is composed of two parts: a SQLite database and an HDF5 archive.
"""
struct LibraryIndex
    db::SQLite.DB
    fp::HDF5.File
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

include("index/collections.jl")
include("index/instances.jl")
include("index/solvers.jl")
include("index/solutions.jl")
