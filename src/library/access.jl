function access(callback::Any; path::AbstractString = pwd(), clear::Bool = false)
    index = access(; path, clear)

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

function access(; path::AbstractString = pwd(), clear::Bool = false)
    if !is_installed(path) || clear
        install(path; clear)
    end

    return load_index(path)
end

function is_installed(path::AbstractString)::Bool
    lib_path = library_path(path)

    return isdir(lib_path) && isfile(database_path(lib_path)) && isfile(archive_path(lib_path))
end

function install(path::AbstractString; clear::Bool = false)
    lib_path = library_path(path)

    if clear
        rm(lib_path; force = true, recursive = true)

        mkpath(lib_path)
    else
        mkpath(lib_path)

        for src_name in readdir(library_path())
            src_path = abspath(library_path(), src_name)
            dst_path = abspath(lib_path, src_name)
            
            cp(
                src_path,
                dst_path;
                force           = true,
                follow_symlinks = true,
            )

            chmod(dst_path, 0o644)
        end
    end

    return nothing
end

function load_index(path::AbstractString)
    lib_path = library_path(path)

    @assert isdir(lib_path)

    db = load_database(database_path(lib_path))
    h5 = load_archive(archive_path(lib_path))

    if isnothing(db) && isnothing(h5)
        # In this case, we have to create both
        return create_index(path)
    elseif isnothing(db) || isnothing(h5)
        error("QUBOLib Installation is compromised: Try running `access` with the `clear` argument set to `true`.")

        return nothing
    else
        return LibraryIndex(db, h5, lib_path)
    end
end

function create_index(path::AbstractString)
    # When building, $path is assumed to be pointing to dist/ or any other root path
    lib_path = library_path(path)

    @assert isdir(lib_path)

    db = create_database(database_path(lib_path))
    h5 = create_archive(archive_path(lib_path))

    return LibraryIndex(db, h5, lib_path)
end

function load_database(path::AbstractString)::Union{SQLite.DB,Nothing}
    if !isfile(path)
        return nothing
    else
        return SQLite.DB(path)
    end
end

function each_stmt(src::AbstractString)
    return Iterators.filter(!isempty, Iterators.map(strip, eachsplit(src, ';')))
end

function create_database(path::AbstractString)
    rm(path; force = true) # Remove file if it exists

    db = SQLite.DB(path)

    open(QUBOLIB_SQL_PATH) do file
        for stmt in each_stmt(read(file, String))
            DBInterface.execute(db, stmt)
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
