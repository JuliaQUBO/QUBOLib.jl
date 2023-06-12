function _document!(path::AbstractString, collection::AbstractString; verbose::Bool = false)
    verbose && @info "Writing docs: '$collection'"

    return nothing
end

function _document!(path::AbstractString; verbose::Bool = false)
    for collection in _list_collections(path)
        _document!(path, collection; verbose)
    end

    verbose && @info "Writing docs: Table of Contents"

    filepath = joinpath(path, "README.md")
    
    readme = """
    # QUBO instance database
    
    $(_table_of_contents(path))
    """

    write(filepath, readme)

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
