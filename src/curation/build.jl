function _build!(path::AbstractString; verbose::Bool = false)
    # build tarball
    verbose && @info "Building Tarball"

    temp_path = abspath(Tar.create(path))
    dist_path = joinpath(path, "..", "dist")

    # compress tarball
    verbose && @info "Compressing Tarball"

    run(`gzip -9 $temp_path`)
    
    # copy from temporary file and delete it
    file_path = mkpath(joinpath(dist_path, "collections.tar.gz"))

    verbose && @info "Copying files"

    cp("$temp_path.gz", file_path)

    rm(temp_path; force = true)
    rm("$temp_path.gz"; force = true)

    return nothing
end