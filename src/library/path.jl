@doc raw"""
    library_path()::AbstractString

Returns the absolute path to the QUBOLib artifact.
"""
function library_path()::String
    # return root_path() # switch to artifact as soon as it is released:
    return abspath(artifact"qubolib") 
end

function library_path(path::AbstractString)::String
    return joinpath(path, "qubolib")
end

library_path(index::LibraryIndex) = index.path

@doc raw"""
    database_path(path::AbstractString=library_path())::AbstractString

Returns the absolute path to the database file, given a reference library path `path`.
"""
function database_path(path::AbstractString = library_path())::String
    return joinpath(path, "index.db")
end

database_path(index::LibraryIndex) = database_path(index.path)

@doc raw"""
    archive_path(path::AbstractString=library_path())::AbstractString

Returns the absolute path to the archive file, given a reference library path `path`.
"""
function archive_path(path::AbstractString = library_path())::String
    return joinpath(path, "archive.h5")
end

archive_path(index::LibraryIndex) = archive_path(index.path)

# Functions below will be more often used when building the library,
# therefore they will point to the the project's root path by default.

@doc raw"""
    root_path()::AbstractString

Returns the absolute path to the project's root folder.

!!! info
    The [`dist_path`](@ref), [`build_path`](@ref), and [`cache_path`](@ref) functions are
    more often used when building the library, therefore they will point to the the project's
    root path by default, by referencing this function.
"""
function root_path()::AbstractString
    return __project__()
end

root_path(index::LibraryIndex) = abspath(dirname(index.path))

@doc raw"""
    dist_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the distribution folder, given a reference _root path_ `path`.
"""
function dist_path(path::AbstractString = root_path())::String
    return joinpath(path, "dist")
end

dist_path(index::LibraryIndex) = dist_path(root_path(index))

@doc raw"""
    build_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the build folder, given a reference _root path_ `path`.
"""
function build_path(path::AbstractString = root_path())::String
    return joinpath(dist_path(path), "build")
end

build_path(index::LibraryIndex) = build_path(root_path(index))

@doc raw"""
    cache_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the cache folder, given a reference _root path_ `path`.
"""
function cache_path(path::AbstractString = root_path(), paths...)::String
    return joinpath(dist_path(path), "cache", paths...)
end

cache_path(index::LibraryIndex, paths...) = cache_path(root_path(index), paths...)

@doc raw"""
    cache_data_path(path::AbstractString, paths...)

Returns the absolute path to the data cache folder, given a reference _root path_ `path`.
"""
function cache_data_path(path::AbstractString = root_path(), paths...)::String
    return joinpath(cache_path(path, paths...), "data")
end

cache_data_path(index::LibraryIndex, paths...) = cache_data_path(root_path(index), paths...)
