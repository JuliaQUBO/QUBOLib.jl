@doc raw"""
    _index!(path::AbstractString)

Setups and builds the index database.
"""
function _index! end

@doc raw"""
    _document!(path::AbstractString)

Generates a README with a table-of-contents and other details of the database.

    _document!(path::AbstractString, collection::AbstractString)

Generates a README file summarizing the contents of a collection.
"""
function _document! end

@doc raw"""
    _tag!
"""
function _tag! end

@doc raw"""
    _metadata(path::AbstractString, collection::AbstractString; validate::Bool = true)
"""
function _metadata end

@doc raw"""
    _list_collections([path,])
"""
function _list_collections end

@doc raw"""
    _list_instances([path,], collection::AbstractString)
"""
function _list_instances end