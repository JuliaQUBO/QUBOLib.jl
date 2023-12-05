function deploy(index::InstanceIndex; curate_data::Bool = false, on_read_error::Function=msg -> @warn(msg))
    if curate_data
        curate!(index; on_read_error)
    end

    deploy(index.dist_path)
    
    return nothing
end

function deploy(dist_path::AbstractString)

    # Build tarball
    temp_path = abspath(Tar.create(dist_path))

    # Compress tarball
    run(`gzip -9 $temp_path`)

    # Move tarball
    file_path = mkpath(abspath(dist_path, "collections.tar.gz"))

    cp("$temp_path.gz", file_path; force = true)

    # Remove temporary files
    rm(temp_path; force = true)
    rm("$temp_path.gz"; force = true)
    
    return nothing
end
