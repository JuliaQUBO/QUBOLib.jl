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
            (" "^indent) * "$(rpad(k, keysize)) = {$(latexescape(string(v)))}"
            for (k, v) in data
        ],
        "\n"
    )

    return """
    @$doctype{$citekey,
    $entries
    }
    """
end

function _problem_name(problem::AbstractString)
    return _problem_name(artifact"collections", problem)
end

function _problem_name(path::AbstractString, problem::AbstractString)
    db = database(path::AbstractString)

    df = DBInterface.execute(
        db,
        "SELECT name FROM problems WHERE problem = ?",
        [problem]
    ) |> DataFrame

    try
        return only(df[!,:name])
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

    return only(df[!,begin])
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

    return (first(df[!,begin]), last(df[!,begin]))
end
