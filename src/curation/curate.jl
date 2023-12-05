if !isdefined(LaTeXStrings, :latexescape)
    const LATEX_ESCAPE_SUB_TABLE = Pair{String,String}[
        raw"\\"=>raw"\textbackslash{}",
        raw"&"=>raw"\&",
        raw"%"=>raw"\%",
        raw"$"=>raw"\$",
        raw"#"=>raw"\#",
        raw"_"=>raw"\_",
        raw"{"=>raw"\{",
        raw"}"=>raw"\}",
        raw"~"=>raw"\textasciitilde{}",
        raw"^"=>raw"\^{}",
        raw"<"=>raw"\textless{}",
        raw">"=>raw"\textgreater{}",
    ]

    function latexescape(s::AbstractString)
        return replace(s, LATEX_ESCAPE_SUB_TABLE...)
    end
end

if !isdefined(LaTeXStrings, :bibtexescape)
    const BIBTEX_ESCAPE_SUB_TABLE = Pair{String,String}[
        raw"\\"=>raw"\textbackslash{}",
        raw"&"=>raw"\&",
        raw"%"=>raw"\%",
        raw"$"=>raw"\$",
        raw"#"=>raw"\#",
        raw"_"=>raw"\_",
        raw"~"=>raw"\textasciitilde{}",
        raw"^"=>raw"\^{}",
        raw"<"=>raw"\textless{}",
        raw">"=>raw"\textgreater{}",
    ]

    function bibtexescape(s::AbstractString)
        return replace(s, BIBTEX_ESCAPE_SUB_TABLE...)
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
    return _problem_name(artifact"collections", problem)
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
    return _collection_size(artifact"collections", collection::AbstractString)
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
    return _collection_size_range(artifact"collections", collection::AbstractString)
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

                linear_min, linear_max = extrema(last, QUBOTools.linear_terms(model))
                quadratic_min, quadratic_max = extrema(last, QUBOTools.quadratic_terms(model))

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
