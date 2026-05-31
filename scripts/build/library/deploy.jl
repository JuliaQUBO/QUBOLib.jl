function deploy_qubolib!(index::QUBOLib.LibraryIndex)
    @assert Sys.islinux()

    root_path = abspath(QUBOLib.root_path(index))
    library_path = abspath(QUBOLib.library_path(index))
    dist_path = abspath(QUBOLib.dist_path(index))
    build_path = abspath(QUBOLib.build_path(index))

    close(index)

    @info "[QUBOLib] Display Path Info"
    @show "root_path    = $(root_path)"
    @show "library_path = $(library_path)"
    @show "dist_path    = $(dist_path)"
    @show "build_path   = $(build_path)"

    mkpath(build_path)

    # Calculate tree hash
    @info "[QUBOLib] Compute Tree Hash"

    git_tree_hash = bytes2hex(Pkg.GitTools.tree_hash(library_path))

    write(joinpath(build_path, "git-tree.hash"), git_tree_hash)

    # Build tarball
    @info "[QUBOLib] Build Tar ball"

    temp_path = abspath(Tar.create(library_path))

    # Compress tarball
    run(`gzip -9 -n $temp_path`)

    # Move tarball
    @info "[QUBOLib] Move Tar ball"

    tar_ball_path = joinpath(build_path, "qubolib.tar.gz")

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

    write(joinpath(build_path, "tar-ball.hash"), tar_ball_hash)

    # Retrieve last QUBOLib tag
    @info "[QUBOLib] Generate release tag"

    last_tag = last_data_tag(root_path)
    next_tag = next_data_tag(last_tag)

    write(joinpath(build_path, "next.tag"), next_tag)

    # Write Artifacts.toml entry
    @info "[QUBOLib] Generate Artifacts.toml"

    artifact_entry = qubolib_artifact_entry(git_tree_hash, tar_ball_hash, next_tag)

    write(joinpath(build_path, "Artifacts.toml"), artifact_entry)

    # Write release information
    @info "[QUBOLib] Generate release title"

    release_title = "QUBOLib Library Data $(next_tag)"

    write(joinpath(build_path, "title.txt"), release_title)

    @info "[QUBOLib] Generate release notes"

    release_notes = qubolib_release_notes(release_title, artifact_entry)

    write(joinpath(build_path, "NOTES.md"), release_notes)

    @info "[QUBOLib] Generate Mirror release notes"
    mirror_path  = mkpath(joinpath(build_path, "mirror"))
    mirror_notes = qubolib_mirror_release_notes()

    write(joinpath(mirror_path, "NOTES.md"), mirror_notes)

    @info "[QUBOLib] Deployment done!"

    return nothing
end

function qubolib_artifact_entry(
    git_tree_hash::AbstractString,
    tar_ball_hash::AbstractString,
    tag::AbstractString,
)
    return """
    [qubolib]
    git-tree-sha1 = "$(git_tree_hash)"
    lazy          = true

        [[qubolib.download]]
        url    = "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/$(tag)/qubolib.tar.gz"
        sha256 = "$(tar_ball_hash)"
    """
end

function _qoblib_release_counts(groups = QOBLIB_GROUPS)
    instance_count = sum(group.expected_count for group in groups)
    incumbent_count = sum(group.expected_incumbents for group in groups)

    return (
        instances = instance_count,
        incumbents = incumbent_count,
        missing_incumbents = instance_count - incumbent_count,
    )
end

function qubolib_release_notes(
    release_title::AbstractString,
    artifact_entry::AbstractString,
)
    counts = _qoblib_release_counts()

    return """
    # $(release_title) Release Notes

    ## Summary

    This release rebuilds the QUBOLib data artifact with QOBLIB QUBO benchmark models, incumbent bitstrings, and submission metadata from source commit `$(QOBLIB_SOURCE_COMMIT)`.

    QOBLIB contributes $(counts.instances) imported QUBO instances and $(counts.incumbents) validated incumbent records. The remaining $(counts.missing_incumbents) missing-incumbent cases are represented as `SolutionRecords` metadata instead of build failures.

    QUBOLib remains QUBO-focused. Benchmark comparisons should use canonical QUBO-space `qubo_value`, which is evaluated from the stored model and mapped bitstring. Source objective values are preserved as provenance and may differ because of source formulation conventions, offsets, signs, penalties, or auxiliary variables.

    ## Licensing and Citation

    QOBLIB source code and scripts are Apache-2.0 licensed. QOBLIB data is CC-BY-4.0 licensed. Cite QOBLIB with the collection citation stored in the artifact metadata.

    ## `Artifacts.toml`

    To access the `qubolib` artifact in your project, add the following entry to `Artifacts.toml`.

    ```toml
    $(artifact_entry)
    ```
    """
end

function qubolib_mirror_release_notes()
    return """
    # QUBOLib Data Mirror Release Notes

    This release provides access to mirrored and preprocessed instances from other libraries, including the pinned QOBLIB source archive used to build the packaged QUBOLib data artifact.
    """
end

function last_data_tag(index::QUBOLib.LibraryIndex)::Union{String,Nothing}
    return last_data_tag(QUBOLib.root_path(index))
end

function last_data_tag(path::AbstractString)::Union{String,Nothing}
    last_tag_path = joinpath(QUBOLib.build_path(path), "last.tag")
    artifacts_path = joinpath(path, "Artifacts.toml")

    if isfile(last_tag_path)
        tag = strip(read(last_tag_path, String))

        return isempty(tag) ? nothing : tag
    end

    tag = artifact_data_tag(path)

    if !isnothing(tag)
        return tag
    end

    @warn """
    No last tag information found @ '$last_tag_path' or '$artifacts_path'.
    """

    return nothing
end

function artifact_data_tag(path::AbstractString)::Union{String,Nothing}
    artifacts_path = joinpath(path, "Artifacts.toml")

    isfile(artifacts_path) || return nothing

    data = TOML.parsefile(artifacts_path)
    artifact = get(data, "qubolib", nothing)

    isnothing(artifact) && return nothing

    downloads = get(artifact, "download", Any[])

    downloads isa AbstractVector || return nothing

    for download in downloads
        download isa AbstractDict || continue

        url = get(download, "url", "")
        m = match(r"/releases/download/([^/]+)/qubolib\.tar\.gz$", String(url))

        if !isnothing(m)
            return only(m.captures)
        end
    end

    return nothing
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
