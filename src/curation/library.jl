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

function _problem_name(code::String)
    db_path = joinpath(path, "index.sqlite")

    db = SQLite.DB(db_path)

    df = DBInterface.execute(
        db,
        "SELECT name FROM problems WHERE code = ?",
        [code]
    ) |> DataFrame

    return only(df[!,:name])
end

function _size_range(path::AbstractString)
    db_path = joinpath(path, "index.sqlite")

    db = SQLite.DB(db_path)

    df = DBInterface.execute(
        db,
        "SELECT MIN(size), MAX(size) FROM instances;",
    ) |> DataFrame

    return (first(df[!,1]), last(df[!,1]))
end

function _size_range(path::AbstractString, collection::AbstractString)
    db_path = joinpath(path, "index.sqlite")

    db = SQLite.DB(db_path)

    df = DBInterface.execute(
        db,
        "SELECT MIN(size), MAX(size) FROM instances WHERE collection = ?;",
        [collection]
    ) |> DataFrame

    return (first(df[!,1]), last(df[!,1]))
end
