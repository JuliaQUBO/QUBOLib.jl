function deploy!(path::AbstractString)
    @assert Sys.islinux()

    # Calculate tree hash
    git_tree_hash = bytes2hex(Pkg.GitTools.tree_hash(QUBOLib.library_path(path)))

    # Build tarball
    temp_path = abspath(Tar.create(QUBOLib.library_path(path)))

    # Compress tarball
    run(`gzip -9 $temp_path`)

    # Move tarball
    tar_ball_path = mkpath(abspath(QUBOLib.dist_path(path), "qubolib.tar.gz"))

    rm(tar_ball_path; force = true)

    cp("$temp_path.gz", tar_ball_path; force = true)

    # Remove temporary files
    rm(temp_path; force = true)
    rm("$temp_path.gz"; force = true)

    # Write hash to file
    write(joinpath(QUBOLib.build_path(path), "git-tree.hash"), git_tree_hash)

    # Also, compute sha256 sum
    tar_ball_hash = read(pipeline(`sha256sum -z $tar_ball_path`, `cut -d ' ' -f 1`), String)

    write(joinpath(QUBOLib.build_path(path), "tar-ball.hash"), tar_ball_hash)

    # Retrieve last QUBOLib tag
    # last_tag = read(joinpath(QUBOLib.build_path(path), "last.tag"), String)
    # next_tag = next_data_tag(last_tag)

    # write(joinpath(QUBOLib.build_path(path), "next.tag"), next_tag)

    # # Write Artifacts.toml entry
    # artifact_entry = """
    # [qubolib]
    # git-tree-sha1 = "$(git_tree_hash)"
    # lazy          = true

    #     [[qubolib.download]]
    #     url    = "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/$(qubolib_tag)/qubolib.tar.gz"
    #     sha256 = "$(tar_ball_hash)"
    # """

    # write(joinpath(QUBOLib.build_path(path), "Artifacts.toml"), artifact_entry)
    
    return nothing
end

function next_data_tag(last_tag::AbstractString)::String
    return next_data_tag(parse(VersionNumber, last_tag))
end

function next_data_tag(last_tag::VersionNumber)::String
    next_tag = if isempty(last_tag.prerelease)
        @assert isempty(last_tag.build)

        VersionNumber(
            last_tag.major,
            last_tag.minor,
            last_tag.patch,
            ("data",),
            (1,),
        )
    else # !isempty(last_tag.prerelease)
        @assert only(last_tag.prerelease) == "data"

        if isempty(last_tag.build)
            VersionNumber(
                last_tag.major,
                last_tag.minor,
                last_tag.patch,
                last_tag.prerelease,
                (1,),
            )
        else
            @assert only(last_tag.build) isa Integer "last_tag.build = $(last_tag.build)"

            VersionNumber(
                last_tag.major,
                last_tag.minor,
                last_tag.patch,
                last_tag.prerelease,
                (only(last_tag.build) + 1,)
            )
        end
    end

    return "v$(next_tag)"
end
