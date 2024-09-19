function _load_archive(path::AbstractString, mode::AbstractString="cw")
    if !isfile(path)
        return nothing
    else
        return HDF5.h5open(path, mode)
    end
end

function _create_archive(path::AbstractString)
    rm(path; force=true) # remove file if it exists

    h5 = HDF5.h5open(path, "w")

    HDF5.create_group(h5, "instances")
    HDF5.create_group(h5, "solutions")

    return h5
end
