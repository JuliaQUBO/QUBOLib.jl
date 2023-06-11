function _build!(path::AbstractString, distpath::AbstractString; verbose::Bool=false)
    # build tarball
    temppath = abspath(Tar.create(path))

    # compress tarball
    run(`gzip -9 $temppath`)
    
    # copy from temporary file and delete it
    filepath = mkpath(joinpath(distpath, "collections.tar.gz"))

    cp("$temppath.gz", filepath)

    rm(temppath; force = true)
    rm("$temppath.gz"; force = true)

    return nothing
end