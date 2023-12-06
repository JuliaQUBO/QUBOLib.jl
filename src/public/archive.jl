function archive(callback::Function, path::AbstractString)
    return HDF5.h5open(callback, abspath(path, "archive.h5"), "r")
end

function archive(path::AbstractString)
    return HDF5.h5open(abspath(path, "archive.h5"), "r")
end

function archive(callback::Function)
    return archive(callback, data_path())
end

function archive()
    return archive(data_path())
end
 