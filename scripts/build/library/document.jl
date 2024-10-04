function document(index::LibraryIndex)
    df = DBInterface.execute(
        QUBOLib.database(index),
        "SELECT collection FROM Collections WHERE collection != 'standalone';"
    ) |> DataFrame

    for collection in df[!, :collection]
        @info "Generating Documentation for '$collection'"

        document(index, collection)
    end

    return nothing
end

function document(index::LibraryIndex, collection::AbstractString)
    coll_path = joinpath(path, collection)
    file_path = joinpath(coll_path, "README.md")

    readme = """
    # $(collection)

    $(summary_table(path, collection))

    $(references(path, collection))
    """

    write(file_path, readme)

    while !JuliaFormatter.format_file(file_path; format_markdown=true) end

    return nothing
end

function document(path::AbstractString)
    for collection in list_collections(path)
        document(path, collection)
    end

    file_path = joinpath(path, "README.md")
    
    readme = """
    # QUBO instance database
    
    $(_table_of_contents(path))
    """

    write(file_path, readme)

    while !JuliaFormatter.format_file(file_path; format_markdown=true) end

    return nothing
end

function _table_of_contents(path::AbstractString)
    coll_list = _list_collections(path)
    href_list = relpath.(joinpath.(path, coll_list), path)
    item_list = ["- [$coll]($href)" for (coll, href) in zip(coll_list, href_list)]

    return """
    ## Table of Contents

    $(join(item_list, "\n"))
    """
end

function _references(path::AbstractString, collection::AbstractString)
    metadata = _metadata(path, collection)

    if !haskey(metadata, "source") || isempty(metadata["source"])
        return ""
    end

    items = []

    for data in copy.(metadata["source"])
        item = """
        ```tex
        $(_bibtex_entry(data))
        ```
        """

        push!(items, item)
    end

    references = join(items, "\n")

    return """
    ## References

    $(references)
    """
end

function _summary_table(path::AbstractString, collection::AbstractString)
    l, u = _collection_size_range(path::AbstractString, collection)

    return """
    ## Summary

    |  Problem    | $(_problem_name(path::AbstractString, collection))          |
    | :---------: | :---------------------------------------------------------: |
    | Instances   | $(_collection_size(path::AbstractString, collection))       |
    | Size range  | $(l) - $(u)                                                 |
    """
end
