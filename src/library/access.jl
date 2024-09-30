function access(; path::AbstractString = library_path(), create::Bool = false)
    ifmissing = _ -> error(
        """
        There's no valid QUBOLib installation at '$path'.
        Try running `QUBOLib.access` with the `create = true` keyword set in order to generate one from scratch.
        """,
    )

    db = load_database(database_path(path; create, ifmissing))
    h5 = load_archive(archive_path(path; create, ifmissing))

    if isnothing(db) || isnothing(h5)
        if create
            return create_index(path)
        else
            error("Failed to load index from '$path'")

            return nothing
        end
    end

    return LibraryIndex(db, h5; path)
end

function access(callback::Any; path::AbstractString = library_path(), create::Bool = false)
    index = access(; path, create)

    @assert isopen(index)

    try
        return callback(index)
    finally
        close(index)
    end
end

function create_index(path::AbstractString)
    db = create_database(database_path(path; create = true))
    h5 = create_archive(archive_path(path; create = true))

    return LibraryIndex(db, h5; path)
end

function load_database(path::AbstractString)::Union{SQLite.DB,Nothing}
    if !isfile(path)
        return nothing
    else
        return SQLite.DB(path)
    end
end

function create_database(path::AbstractString)
    rm(path; force = true) # Remove file if it exists

    db = SQLite.DB(path)

    open(QUBOLIB_SQL_PATH) do file
        for stmt in eachsplit(read(file, String), ';')
            stmt = strip(stmt)

            if !isempty(stmt)
                DBInterface.execute(db, stmt)
            end
        end
    end

    return db
end

function load_archive(
    path::AbstractString;
    mode::AbstractString = "cw",
)::Union{HDF5.File,Nothing}
    if !isfile(path)
        return nothing
    else
        return HDF5.h5open(path, mode)
    end
end

function create_archive(path::AbstractString)
    rm(path; force = true) # remove file if it exists

    h5 = HDF5.h5open(path, "w")

    HDF5.create_group(h5, "instances")
    HDF5.create_group(h5, "solutions")

    return h5
end
