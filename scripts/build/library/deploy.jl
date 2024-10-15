function deploy_qubolib!(index::QUBOLib.LibraryIndex)
    @assert Sys.islinux()

    close(index)

    # Calculate tree hash
    @info "[QUBOLib] Compute Tree Hash"

    git_tree_hash = bytes2hex(Pkg.GitTools.tree_hash(QUBOLib.library_path(index)))

    write(joinpath(QUBOLib.build_path(index), "git-tree.hash"), git_tree_hash)

    # Build tarball
    @info "[QUBOLib] Build Tar ball"

    temp_path = abspath(Tar.create(QUBOLib.library_path(index)))

    # Compress tarball
    run(`gzip -9 $temp_path`)

    # Move tarball
    @info "[QUBOLib] Move Tar ball"

    tar_ball_path = joinpath(QUBOLib.build_path(index), "qubolib.tar.gz")

    rm(tar_ball_path; force = true)

    mkpath(dirname(tar_ball_path))

    cp("$temp_path.gz", tar_ball_path; force = true)

    # Remove temporary files
    @info "[QUBOLib] Clear Temporary files"

    rm(temp_path; force = true)
    rm("$temp_path.gz"; force = true)

    # Also, compute sha256 sum
    @info "[QUBOLib] Compute SHA256 hash sum"

    tar_ball_hash = strip(read(pipeline(`sha256sum -z $tar_ball_path`, `cut -d ' ' -f 1`), String))

    write(joinpath(QUBOLib.build_path(index), "tar-ball.hash"), tar_ball_hash)

    # Retrieve last QUBOLib tag
    @info "[QUBOLib] Generate release tag"

    last_tag = last_data_tag(index)
    next_tag = next_data_tag(last_tag)

    write(joinpath(QUBOLib.build_path(index), "next.tag"), next_tag)

    # Write Artifacts.toml entry
    @info "[QUBOLib] Generate Artifacts.toml"

    artifact_entry = """
    [qubolib]
    git-tree-sha1 = "$(git_tree_hash)"
    lazy          = true

        [[qubolib.download]]
        url    = "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/$(next_tag)/qubolib.tar.gz"
        sha256 = "$(tar_ball_hash)"
    """

    write(joinpath(QUBOLib.build_path(index), "Artifacts.toml"), artifact_entry)

    # Write release information
    @info "[QUBOLib] Generate release title"

    release_title = "QUBOLib Library Data $(next_tag)"

    write(joinpath(QUBOLib.build_path(index), "title.txt"), release_title)

    @info "[QUBOLib] Generate release notes"

    release_notes = """
    # $(release_title) Release Notes

    ## `Artifact.toml`

    To be able to access the `qubolib` artifact in your project, add the following entry to `Artifacts.toml`.

    ```toml
    $(artifact_entry)
    ```
    """

    write(joinpath(QUBOLib.build_path(index), "NOTES.md"), release_notes)

    @info "[QUBOLib] Generate Mirror release notes"

    mirror_notes = """
    # QUBOLib Data Mirror Release Notes

    This release provides access to mirrored and preprocessed instances from other libraries.
    """

    write(joinpath(QUBOLib.build_path(index), "mirror", "NOTES.md"), mirror_notes)

    @info "[QUBOLib] Deployment done!"
    
    return nothing
end

function last_data_tag(index::QUBOLib.LibraryIndex)::Union{String,Nothing}
    last_tag_path = joinpath(QUBOLib.build_path(index), "last.tag")

    if isdir(last_tag_path)
        return strip(read(last_tag_path, String))
    else
        @warn """
        No last tag information found @ '$last_tag_path'.
        """

        return nothing
    end
end

function next_data_tag(::Nothing)::String
    next_tag = let version = QUBOLib.__version__()
        VersionNumber(
            version.major,
            version.minor,
            version.patch,
            ("data",),
            (1,)
        )
    end

    return "v$(next_tag)"
end

function next_data_tag(last_tag::AbstractString)::String
    return next_data_tag(parse(VersionNumber, last_tag))
end

function next_data_tag(last_tag::VersionNumber)::String
    next_tag = let version = QUBOLib.__version__()
        if isempty(last_tag.prerelease)
            @assert isempty(last_tag.build)

            VersionNumber(
                version.major,
                version.minor,
                version.patch,
                ("data",),
                (1,),
            )
        else # !isempty(last_tag.prerelease)
            @assert only(last_tag.prerelease) == "data"

            if isempty(last_tag.build)
                VersionNumber(
                    version.major,
                    version.minor,
                    version.patch,
                    ("data",),
                    (1,),
                )
            else
                @assert only(last_tag.build) isa Integer "last_tag.build = $(last_tag.build)"

                VersionNumber(
                    version.major,
                    version.minor,
                    version.patch,
                    ("data",),
                    (only(last_tag.build) + 1,)
                )
            end
        end
    end

    return "v$(next_tag)"
end
