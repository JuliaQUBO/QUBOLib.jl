function lib_path()::AbstractString
    return abspath(artifact"qubolib")
end

function database_path(path::AbstractString=lib_path())::AbstractString
    return abspath(build_path(path), "index.db")
end

function archive_path(path::AbstractString=lib_path())::AbstractString
    return abspath(build_path(path), "archive.h5")
end

# Functions below will be more often used when building the library,
# therefore they will point to the the project's root path by default.
function root_path()::AbstractString
    return __PROJECT__
end

function dist_path(path::AbstractString=root_path())::AbstractString
    return mkpath(abspath(path, "dist"))
end

function build_path(path::AbstractString=root_path())::AbstractString
    return mkpath(abspath(dist_path(path), "build"))
end

function cache_path(path::AbstractString=root_path())::AbstractString
    return mkpath(abspath(dist_path(path), "cache"))
end

