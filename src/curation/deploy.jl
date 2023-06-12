function _deploy(path::AbstractString; verbose::Bool = false)
    coll_path = joinpath(path, "collections")

    _index!(coll_path; verbose)
    _hash!(coll_path; verbose)
    _build!(coll_path; verbose)
    _document!(coll_path; verbose)
    _tag!(path; verbose)

    return nothing
end