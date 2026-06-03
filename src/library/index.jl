@doc raw"""
    LibraryIndex

The QUBOLib index is composed of two pieces: a SQLite database and an HDF5 archive.
"""
struct LibraryIndex
    db::SQLite.DB
    h5::HDF5.File

    path::String # equivalent to .../build

    function LibraryIndex(db::SQLite.DB, h5::HDF5.File, path::AbstractString)
        return new(db, h5, path)
    end
end

const _ACCESS_SAVEPOINT_NAME = "qubolib_access"
const _ACCESS_SAVEPOINTS = IdDict{SQLite.DB,Bool}()

function _begin_access_savepoint!(db::SQLite.DB)
    DBInterface.execute(db, "SAVEPOINT $(_ACCESS_SAVEPOINT_NAME);")
    _ACCESS_SAVEPOINTS[db] = true

    return nothing
end

function _release_access_savepoint!(db::SQLite.DB)
    if get(_ACCESS_SAVEPOINTS, db, false)
        try
            DBInterface.execute(db, "RELEASE SAVEPOINT $(_ACCESS_SAVEPOINT_NAME);")
        finally
            delete!(_ACCESS_SAVEPOINTS, db)
        end
    end

    return nothing
end

function _rollback_access_savepoint!(db::SQLite.DB)
    if get(_ACCESS_SAVEPOINTS, db, false)
        try
            DBInterface.execute(db, "ROLLBACK TO SAVEPOINT $(_ACCESS_SAVEPOINT_NAME);")
        finally
            try
                DBInterface.execute(db, "RELEASE SAVEPOINT $(_ACCESS_SAVEPOINT_NAME);")
            finally
                delete!(_ACCESS_SAVEPOINTS, db)
            end
        end
    end

    return nothing
end

function Base.isopen(index::LibraryIndex)
    return isopen(index.db) && isopen(index.h5)
end

function Base.close(index::LibraryIndex)
    if isopen(index.db)
        _release_access_savepoint!(index.db)
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
