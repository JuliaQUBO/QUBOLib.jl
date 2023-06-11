function _table_of_contents(path::AbstractString)
    pathlist = listdirs(path)
    namelist = basename.(pathlist)
    hreflist = relpath.(pathlist, path)
    itemlist = join(
        ["- [$name]($href)" for (name, href) in zip(namelist, hreflist)],
        "\n"
    )
    
    return """
    ## Contents

    $(itemlist)
    """
end

function _document!(path::AbstractString)
    for collection in _list_collections(path)
        _document!(path, collection)
    end

    filepath = joinpath(path, "README.md")
    
    toc = _table_of_contents(path)

    readme = """
    # QUBO instance database
    
    $(toc)
    """

    write(filepath, readme)

    return nothing
end

function _document!(path::AbstractString, collection::AbstractString)

    return nothing
end

# function instance_references(metadata)
#     if !haskey(metadata, "source") || isempty(metadata["source"])
#         return ""
#     end

#     items = []

#     for data in copy.(metadata["source"])
#         item = """
#         ```tex
#         $(bibtex_entry(data))
#         ```
#         """

#         push!(items, item)
#     end

#     references = join(items, "\n\n")

#     return """
#     ## References

#     $references
#     """
# end

# function summary_table(metadata::Dict{String,Any})
#     col_size    = metadata["size"]
#     type        = metadata["problem"]["type"]
#     name        = PROBLEM_TYPES[type]
#     file_format = metadata["format"]

#     if isempty(sizes)
#         size_range = "?"
#     else
#         a, b = extrema(sizes)
#         size_range = "$a - $b"
#     end

#     return """
#     ## Summary

#     |  Problem    | $(name)          |
#     | :---------: | :--------------: |
#     | Instances   |  $(col_size)     |
#     | Size range  |  $(size_range)   |
#     | File format | $(file_format)   |
#     """
# end

# function generate_collection_readme(path)
#     metadata = get_metadata(path)
#     filepath = joinpath(path, "README.md")

#     code = metadata["code"]
#     summ = summary_table(metadata)
#     refs = instance_references(metadata)

#     readme = """
#     # $code 

#     $summ

#     ---

#     $refs
#     """

#     write(filepath, readme)

#     while !JuliaFormatter.format_file(filepath; format_markdown=true)
#     end

#     return nothing
# end
