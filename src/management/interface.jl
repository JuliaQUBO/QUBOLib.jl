@doc raw"""
    build(; cache::Bool = true)
"""
function build end

@doc raw"""
    build!(index::Index; cache::Bool = true)

    build!(index::Index, collection::Collection; cache::Bool = true)
"""
function build! end

@doc raw"""
    cache!(index::Index)

    cache!(index::Index, collection::Collection)
"""
function cache! end

@doc raw"""
    index!(index::Index)

    index!(index::Index, collection::Collection)
"""
function index! end

@doc raw"""
    document!(index::Index)

    document!(index::Index, collection::Collection)
"""
function document! end