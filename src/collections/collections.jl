function get_metadata(coll::String)
    return get_metadata(Symbol(coll))
end

function get_metadata(coll::Symbol)
    return get_metadata(Val(coll))
end

function set_metadata(coll::Symbol, metadata::Dict{String, Any})
    return set_metadata(Val(coll), metadata)
end

function validate_metadata(data::Dict{String, Any})
    @assert isnothing(JSONSchema.validate(data, COLLECTION_SCHEMA))

    return nothing
end

function load_collection!(index::Index, coll::String; cache::Bool = true)
    return load_collection!(index, Symbol(coll); cache)
end

function load_collection!(index::Index, coll::Symbol; cache::Bool = true)
    return load_collection!(index, Val(coll); cache)
end
