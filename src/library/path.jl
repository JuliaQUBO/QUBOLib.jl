@doc raw"""
    library_path()::AbstractString

Returns the absolute path to the QUBOLib artifact.
"""
function library_path()::AbstractString
    return root_path() # switch to artifact as soon as it is released:
    # return abspath(artifact"qubolib") 
end

@doc raw"""
    database_path(path::AbstractString=library_path())::AbstractString

Returns the absolute path to the database file, given a reference `path`.
"""
function database_path(path::AbstractString=library_path(); create::Bool=false)::AbstractString
    return abspath(build_path(path; create), "index.db")
end

@doc raw"""
    archive_path(path::AbstractString=library_path())::AbstractString

Returns the absolute path to the archive file, given a reference `path`.
"""
function archive_path(path::AbstractString=library_path(); create::Bool=false)::AbstractString
    return abspath(build_path(path; create), "archive.h5")
end

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

raw"""
    _get_path(path::AbstractString; create::Bool = false)
"""
function _get_path(path::AbstractString; create::Bool=false)::AbstractString
    if ispath(path)
        return abspath(path)
    elseif create
        return abspath(mkdir(path))
    else
        error("Path '$path' does not exist")

        return nothing
    end
end

@doc raw"""
    dist_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the distribution folder, given a reference `path`.
The path is created if it does not exist.
"""
function dist_path(path::AbstractString=root_path(); create::Bool=false)::AbstractString
    return _get_path(abspath(path, "dist"); create)
end

@doc raw"""
    build_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the build folder, given a reference `path`.
The path is created if it does not exist.
"""
function build_path(path::AbstractString=root_path(); create::Bool=false)::AbstractString
    return _get_path(abspath(dist_path(path; create), "build"); create)
end

@doc raw"""
    cache_path(path::AbstractString=root_path())::AbstractString

Returns the absolute path to the cache folder, given a reference `path`.
The path is created if it does not exist.
"""
function cache_path(path::AbstractString=root_path(); create::Bool=false)::AbstractString
    return _get_path(abspath(dist_path(path; create), "cache"); create)
end
