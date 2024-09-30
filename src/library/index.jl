@doc raw"""
    LibraryIndex

The QUBOLib index is composed of two pieces: a SQLite database and an HDF5 archive.
"""
struct LibraryIndex
    db::SQLite.DB
    h5::HDF5.File

    path::String

    function LibraryIndex(db::SQLite.DB, h5::HDF5.File; path::AbstractString = library_path())
        return new(db, h5, path)
    end
end

function Base.isopen(index::LibraryIndex)
    return isopen(index.db) && isopen(index.h5)
end

function Base.close(index::LibraryIndex)
    if isopen(index.db)
        close(index.db)
    end
    
    if isopen(index.h5)
        close(index.h5)
    end

    return nothing
end

function database(index::LibraryIndex)::SQLite.DB
    @assert isopen(index)

    return index.db
end

function archive(index::LibraryIndex)::HDF5.File
    @assert isopen(index)

    return index.h5
end

function Base.show(io::IO, index::LibraryIndex)
    if isopen(index)
        return println(io, "QUBOLib ■ Library Index")
    else
        return println(io, "QUBOLib ■ Library Index (closed)")
    end
end
