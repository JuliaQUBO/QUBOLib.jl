@doc raw"""
    library_path()::AbstractString

Returns the absolute path to the QUBOLib artifact.
"""
function library_path()::String
    # return root_path() # switch to artifact as soon as it is released:
    return abspath(artifact"qubolib") 
end

function library_path(path::AbstractString)::String
    return abspath(path, "qubolib")
end

@doc raw"""
    database_path(path::AbstractString=library_path())::AbstractString

Returns the absolute path to the database file, given a reference `path`.
"""
function database_path(path::AbstractString = library_path())::String
    return joinpath(path, "index.db")
end

database_path(index::LibraryIndex) = database_path(index.path)

@doc raw"""
    archive_path(path::AbstractString=library_path())::AbstractString

Returns the absolute path to the archive file, given a reference `path`.
"""
function archive_path(path::AbstractString = library_path())::String
    return joinpath(path, "archive.h5")
end

archive_path(index::LibraryIndex) = archive_path(index.path)

# Functions below will be more often used when building the library,
# therefore they will point to the the project's root path by default.

raw"""
    _get_path(path::AbstractString; create::Bool = false)
"""
function _get_path(
    path::AbstractString;
    create::Bool = false,
    ifmissing::Any = path -> error("Path '$path' does not exist"),
)::String
    if ispath(path)
        return abspath(path)
    elseif create
        return abspath(mkdir(path))
    else
        return ifmissing(path)
    end
end

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

@doc raw"""
    dist_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the distribution folder, given a reference `path`.
The path is created if it does not exist.
"""
function dist_path(
    path::AbstractString = root_path();
    create::Bool = false,
    ifmissing::Any = path -> error("No distribution path at '$path'"),
)::String
    return _get_path(abspath(path, "dist"); create, ifmissing)
end

dist_path(index::LibraryIndex; kws...) = dist_path(index.path; kws...)

@doc raw"""
    build_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the build folder, given a reference `path`.
The path is created if it does not exist.
"""
function build_path(
    path::AbstractString = root_path();
    create::Bool = false,
    ifmissing::Any = path -> error("No build path at '$path'"),
)::String
    return _get_path(abspath(dist_path(path; create, ifmissing), "build"); create, ifmissing)
end

build_path(index::LibraryIndex; kws...) = build_path(index.path; kws...)

@doc raw"""
    cache_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the cache folder, given a reference `path`.
The path is created if it does not exist.
"""
function cache_path(
    path::AbstractString = root_path();
    create::Bool = false,
    ifmissing::Any = path -> error("No cache path at '$path'"),
)::String
    return _get_path(abspath(dist_path(path; create, ifmissing), "cache"); create, ifmissing)
end

cache_path(index::LibraryIndex; kws...) = cache_path(index.path; kws...)
