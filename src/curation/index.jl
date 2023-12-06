function create_database(path::AbstractString)
    rm(path; force=true) # remove file if it exists

    db = SQLite.DB(path)

    DBInterface.execute(db, "PRAGMA foreign_keys = ON;")

    DBInterface.execute(db, "DROP TABLE IF EXISTS problems;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE problems (
            problem TEXT PRIMARY KEY, -- Problem identifier
            name    TEXT NOT NULL     -- Problem name
        );
        """
    )

    DBInterface.execute(
        db,
        """
        INSERT INTO problems (problem, name)
        VALUES
            ('3R3X', '3-Regular 3-XORSAT'),
            ('5R5X', '5-Regular 5-XORSAT'),
            ('QUBO', 'Quadratic Unconstrained Binary Optimization');
        """
    )

    DBInterface.execute(db, "DROP TABLE IF EXISTS collections;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE collections (
            collection TEXT    PRIMARY KEY, -- Collection identifier
            problem    TEXT    NOT NULL,    -- Problem type
            size       INTEGER NOT NULL,    -- Number of instances 
            FOREIGN KEY (problem) REFERENCES problems (problem)
        );
        """
    )

    DBInterface.execute(db, "DROP TABLE IF EXISTS instances;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE instances (
            instance   TEXT    PRIMARY KEY, -- Instance identifier
            dimension  INTEGER NOT NULL,    -- Number of variables
            collection TEXT    NOT NULL,    -- Collection identifier
            min                REAL,        -- Minimum value
            max                REAL,        -- Maximum value
            linear_min         REAL,        -- Minimum linear coefficient
            linear_max         REAL,        -- Maximum linear coefficient
            quadratic_min      REAL,        -- Minimum quadratic coefficient
            quadratic_max      REAL,        -- Maximum quadratic coefficient
            density            REAL,        -- Coefficient density
            linear_density     REAL,        -- Linear coefficient density
            quadratic_density  REAL,        -- Quadratic coefficient density
            FOREIGN KEY (collection) REFERENCES collections (collection)
        );
        """
    )

    return db
end

function create_archive(path::AbstractString)
    rm(path; force=true) # remove file if it exists

    fp = HDF5.h5open(path, "w")

    HDF5.create_group(fp, "collections")

    return fp
end

struct InstanceIndex
    db::SQLite.DB
    fp::HDF5.File
    root_path::String
    dist_path::String
    list_path::String
    tree_hash::Ref{String}
    next_tag::Ref{String}
end

function create_index(
    root_path::AbstractString,
    dist_path::AbstractString=abspath(root_path, "dist")
)
    mkpath(dist_path) # create dist directory if it doesn't exist

    db = create_database(joinpath(dist_path, "index.sqlite"))
    fp = create_archive(joinpath(dist_path, "archive.h5"))

    list_path = abspath(root_path, "collections")

    @assert isdir(list_path) "'$list_path' is not a directory"

    return InstanceIndex(db, fp, abspath(root_path), abspath(dist_path), list_path, Ref{String}(), Ref{String}())
end

function _list_collections(path::AbstractString)
    return basename.(filter(isdir, readdir(path; join=true)))
end

function _list_collections(index::InstanceIndex)
    return _list_collections(index.list_path)
end

function _list_instances(path::AbstractString, collection::AbstractString)
    data_path = joinpath(path, collection, "data")

    @assert isdir(data_path) "'$data_path' is not a directory"

    return readdir(data_path; join=false)
end

function _list_instances(index::InstanceIndex, collection::AbstractString)
    return _list_instances(index.list_path, collection)
end

const _METADATA_SCHEMA = JSONSchema.Schema(JSON.parsefile(joinpath(@__DIR__, "metadata.schema.json")))

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

function _get_instance_model(path::AbstractString, collection::AbstractString, instance::AbstractString; on_read_error::Function=msg -> @warn(msg))
    model_path = abspath(path, collection, "data", instance)

    return try
        QUBOTools.read_model(model_path)
    catch
        on_read_error("Failed to read model at '$model_path'")

        nothing
    end
end

function _get_instance_model(index::InstanceIndex, collection::AbstractString, instance::AbstractString; on_read_error::Function=msg -> @warn(msg))
    return _get_instance_model(index.list_path, collection, instance; on_read_error)
end

function hash!(index::InstanceIndex)
    index.tree_hash[] = bytes2hex(Pkg.GitTools.tree_hash(index.list_path))

    return nothing
end

function deploy!(index::InstanceIndex; curate_data::Bool = false, on_read_error::Function=msg -> @warn(msg))
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
    file_path = mkpath(abspath(dist_path, "qubolib.tar.gz"))

    rm(file_path; force = true)

    cp("$temp_path.gz", file_path; force = true)

    # Remove temporary files
    rm(temp_path; force = true)
    rm("$temp_path.gz"; force = true)
    
    return nothing
end

function tag(path::AbstractString)
    last_tag = if haskey(ENV, "LAST_QUBOLIB_TAG")
        parse(VersionNumber, ENV["LAST_QUBOLIB_TAG"])
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

if !isdefined(LaTeXStrings, :latexescape)
    function latexescape(s::AbstractString)
        return replace(
            s,
            raw"\\" => raw"\textbackslash{}",
            raw"&"  => raw"\&",
            raw"%"  => raw"\%",
            raw"$"  => raw"\$",
            raw"#"  => raw"\#",
            raw"_"  => raw"\_",
            raw"{"  => raw"\{",
            raw"}"  => raw"\}",
            raw"~"  => raw"\textasciitilde{}",
            raw"^"  => raw"\^{}",
            raw"<"  => raw"\textless{}",
            raw">"  => raw"\textgreater{}",
        )
    end
end

if !isdefined(LaTeXStrings, :bibtexescape)
    function bibtexescape(s::AbstractString)
        return replace(s,
            raw"\\" => raw"\textbackslash{}",
            raw"&"  => raw"\&",
            raw"%"  => raw"\%",
            raw"$"  => raw"\$",
            raw"#"  => raw"\#",
            raw"_"  => raw"\_",
            raw"~"  => raw"\textasciitilde{}",
            raw"^"  => raw"\^{}",
            raw"<"  => raw"\textless{}",
            raw">"  => raw"\textgreater{}",
        )
    end
end

function _bibtex_entry(data::Dict{String,Any}; indent=2)
    # Replace list with author names by them joined together
    data["author"] = join(pop!(data, "author", []), " and ")

    # The document type / media type defaults to @misc
    doctype = pop!(data, "type", "misc")

    # Citekey: use '?' as placeholder if none is given
    citekey = pop!(data, "citekey", "?")

    # Get the size of longest key to align them
    keysize = maximum(length.(keys(data)))

    entries = join(
        [
            (" "^indent) * "$(rpad(k, keysize)) = {$(bibtexescape(string(v)))}"
            for (k, v) in data
        ],
        "\n",
    )

    return """
    @$doctype{$citekey,
    $entries
    }"""
end

function _problem_name(problem::AbstractString)
    return _problem_name(data_path(), problem)
end

function _problem_name(path::AbstractString, collection::AbstractString)
    db = database(path::AbstractString)

    df = DBInterface.execute(
        db,
        "SELECT problems.name
        FROM problems
        INNER JOIN collections ON problems.problem=collections.problem
        WHERE collections.collection = ?",
        [collection]
    ) |> DataFrame

    try
        return only(df[!, :name])
    catch e
        @show problem
        @show df
        rethrow(e)
    end
end

function _collection_size(collection::AbstractString)
    return _collection_size(data_path(), collection::AbstractString)
end

function _collection_size(path::AbstractString, collection::AbstractString)
    db = database(path)

    df = DBInterface.execute(
        db,
        "SELECT COUNT(*) FROM instances WHERE collection = ?;",
        [collection]
    ) |> DataFrame

    return only(df[!, begin])
end

function _collection_size_range(collection::AbstractString)
    return _collection_size_range(data_path(), collection::AbstractString)
end

function _collection_size_range(path::AbstractString, collection::AbstractString)
    db = database(path)

    df = DBInterface.execute(
        db,
        "SELECT MIN(size), MAX(size) FROM instances WHERE collection = ?;",
        [collection]
    ) |> DataFrame

    return (only(df[!, 1]), only(df[!, 2]))
end

function curate(root_path::AbstractString, dist_path::AbstractString=abspath(root_path, "dist"); on_read_error::Function=msg -> @warn(msg))
    index = create_index(root_path, dist_path)

    curate!(index; on_read_error)

    return index
end

function curate!(index::InstanceIndex; on_read_error::Function=msg -> @warn(msg))
    # curate collections
    for collection in _list_collections(index)
        # extract collection metadata
        coll_metadata = _get_metadata(index, collection)

        problem = get(coll_metadata, "problem", "QUBO")

        DBInterface.execute(
            index.db,
            """
            INSERT INTO collections (collection, problem, size)
            VALUES
                (?, ?, 0);
            """,
            [collection, problem]
        )

        # add collection to HDF5 file
        HDF5.create_group(index.fp["collections"], collection)

        @showprogress desc = "Reading instances @ '$collection'" for instance in _list_instances(index, collection)

            # Add instance to HDF5 file
            HDF5.create_group(index.fp["collections"][collection], instance)

            let model = _get_instance_model(index, collection, instance; on_read_error)
                isnothing(model) && continue

                dimension = QUBOTools.dimension(model)
                density = QUBOTools.density(model)
                linear_density = QUBOTools.linear_density(model)
                quadratic_density = QUBOTools.quadratic_density(model)

                linear_min, linear_max = extrema(last, QUBOTools.linear_terms(model); init = (0, 0))
                quadratic_min, quadratic_max = extrema(last, QUBOTools.quadratic_terms(model); init = (0, 0))

                _min = min(linear_min, quadratic_min)
                _max = max(linear_max, quadratic_max)

                DBInterface.execute(
                    index.db,
                    """
                    INSERT INTO instances
                        (
                            instance,
                            dimension,
                            collection,
                            min,
                            max,
                            linear_min,
                            linear_max,
                            quadratic_min,
                            quadratic_max,
                            density,
                            linear_density,
                            quadratic_density
                        )
                    VALUES
                        (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    [
                        instance,
                        dimension,
                        collection,
                        _min,
                        _max,
                        linear_min,
                        linear_max,
                        quadratic_min,
                        quadratic_max,
                        density,
                        linear_density,
                        quadratic_density,
                    ]
                )

                # add instance to HDF5 file
                QUBOTools.write_model(index.fp["collections"][collection][instance], model, QUBOTools.QUBin())
            end
        end

        DBInterface.execute(
            index.db,
            """
            UPDATE collections
            SET size = (SELECT COUNT(*) FROM instances WHERE collection == ?)
            WHERE collection = ?;
            """,
            [collection, collection]
        )
    end

    return nothing
end
