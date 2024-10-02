function access(callback::Any; path::AbstractString = pwd())
    index = access(; path)

    @assert isopen(index)

    try
        # TODO: Start transaction here
        return callback(index)
    catch err
        # TODO: Implement some transaction rollback functionality!
        rethrow(err)
    finally
        # TODO: Close transaction here
        close(index)
    end
end

function access(; path::AbstractString = pwd())
    if !is_installed(library_path(path))
        install(library_path(path))
    end

    return load_index(library_path(path))
end

function is_installed(path::AbstractString)::Bool
    return isdir(path) && isfile(database_path(path)) && isfile(archive_path(path))
end

function install(path::AbstractString)
    mkdir(path)

    for src_name in readdir(library_path())
        src_path = abspath(library_path(), src_name)
        dst_path = abspath(path, src_name)
        
        cp(
            src_path,
            dst_path;
            force           = true,
            follow_symlinks = true,
        )

        chmod(dst_path, 0o644)
    end

    return nothing
end

function load_index(path::AbstractString)
    @assert isdir(path)

    db = load_database(database_path(path))
    h5 = load_archive(archive_path(path))

    if isnothing(db) || isnothing(h5)
        # In this case, we have to create both
        return create_index(path)
    else
        return LibraryIndex(db, h5, path)
    end
end

function create_index(path::AbstractString)
    # When building, $path is assumed to be pointing to dist/build
    db = create_database(database_path(path))
    h5 = create_archive(archive_path(path))

    return LibraryIndex(db, h5, path)
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
        DBInterface.executemultiple(db, read(file, String))
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
