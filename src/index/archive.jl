function _load_archive(path::AbstractString, mode::AbstractString="w")
    if !isfile(path)
        return nothing
    else
        return HDF5.h5open(path, mode)
    end
end

function _create_archive(path::AbstractString)
    rm(path; force=true) # remove file if it exists

    fp = HDF5.h5open(path, "w")

    HDF5.create_group(fp, "collections")

    return fp
end
