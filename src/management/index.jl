function _get_metadata(path::AbstractString, collection::AbstractString; validate::Bool=true)
    metapath = joinpath(path, collection, "metadata.json")
    metadata = JSON.parsefile(metapath)

    if validate
        report = JSONSchema.validate(_METADATA_SCHEMA, metadata)

        if !isnothing(report)
            error(
                """
                Invalid collection metadata for $(collection):
                $(report)
                """
            )
        end
    end

    return metadata
end

function _get_metadata(index::InstanceIndex, collection::AbstractString; validate::Bool=true)
    return _get_metadata(index.list_path, collection; validate=validate)
end



function hash!(index::InstanceIndex)
    index.tree_hash[] =     

    return nothing
end

function deploy!(index::InstanceIndex)
    hash!(index)

    # Build tarball
    temp_path = abspath(Tar.create(index.dist_path))

    # Compress tarball
    run(`gzip -9 $temp_path`)

    # Move tarball
    file_path = mkpath(abspath(index.dist_path, "qubolib.tar.gz"))

    rm(file_path; force = true)

    cp("$temp_path.gz", file_path; force = true)

    # Remove temporary files
    rm(temp_path; force = true)
    rm("$temp_path.gz"; force = true)
    
    return nothing
end

function tag(path::AbstractString)
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

function tag!(index::InstanceIndex)
    index.next_tag[] = tag(index.root_path)

    return nothing
end





function _problem_name(problem::AbstractString)
    return _problem_name(data_path(), problem)
end

function _problem_name(path::AbstractString, collection::AbstractString)
    db = database(path::AbstractString)

    @assert isopen(db)

    df = DBInterface.execute(
        db,
        "SELECT problems.name
        FROM problems
        INNER JOIN collections ON problems.problem=collections.problem
        WHERE collections.collection = ?",
        [collection]
    ) |> DataFrame

    close(db)

    @assert !isopen(db)

    return only(df[!, :name])
end

function _collection_size(collection::AbstractString)
    return _collection_size(data_path(), collection::AbstractString)
end

function _collection_size(path::AbstractString, collection::AbstractString)
    db = database(path)

    @assert isopen(db)

    df = DBInterface.execute(
        db,
        "SELECT COUNT(*) FROM instances WHERE collection = ?;",
        [collection]
    ) |> DataFrame

    close(db)

    @assert !isopen(db)

    return only(df[!, begin])
end

function _collection_size_range(collection::AbstractString)
    return _collection_size_range(data_path(), collection::AbstractString)
end

