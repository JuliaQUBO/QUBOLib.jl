@doc raw"""
    load_instance(collection::AbstractString, instance::AbstractString)

Loads a specific instance for a given collection as a QUBOTools model.
"""
function load_instance end

@doc raw"""
    list_collections()

List the codes of the registered collections.
"""
function list_collections end

@doc raw"""
    list_instances(collection::AbstractString)

Lists the codes for all instances in a collection.
"""
function list_instances end

@doc raw"""
    database()

Returns a SQLite pointer for the instance index database.
"""
function database end