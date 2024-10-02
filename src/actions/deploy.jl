function deploy(path::AbstractString)
    @assert Sys.islinux()

    # Calculate tree hash
    tree_hash = bytes2hex(Pkg.GitTools.tree_hash(build_path(path)))

    # Build tarball
    temp_path = abspath(Tar.create(build_path(path)))

    # Compress tarball
    run(`gzip -9 $temp_path`)

    # Move tarball
    file_path = mkpath(abspath(dist_path(path), "qubolib.tar.gz"))

    rm(file_path; force = true)

    cp("$temp_path.gz", file_path; force = true)

    # Remove temporary files
    rm(temp_path; force = true)
    rm("$temp_path.gz"; force = true)

    # Write hash to file
    write(joinpath(dist_path(path), "tree.hash"), tree_hash)

    # Also, compute sha256 sum
    ball_hash = read(pipeline(`sha256sum -z $file_path`, `cut -d ' ' -f 1`), String)

    write(joinpath(dist_path(path), "ball.hash"), ball_hash)
    
    return nothing
end

function next_tag(path::AbstractString)
    last_tag = if haskey(ENV, "LAST_QUBOLIB_TAG")
        x = tryparse(VersionNumber, ENV["LAST_QUBOLIB_TAG"])

        if isnothing(x)
            @warn("Pushing tag forward")

            v"0.1.0"
        else
            x
        end
    else
        last_tag_path = abspath(path, "last.tag")

        if isfile(last_tag_path)
            text = read(last_tag_path, String)

            m = match(r"tag:\s*v(.*)", text)

            if isnothing(m)
                @error("Tag not found in '$last_tag_path'")

                exit(1)
            end

            parse(VersionNumber, m[1])
        else
            @error("File '$last_tag_path' not found")

            exit(1)
        end
    end

    next_tag = VersionNumber(
        last_tag.major,
        last_tag.minor,
        last_tag.patch + 1,
        last_tag.prerelease,
        last_tag.build,
    )

    return "v$next_tag"
end
