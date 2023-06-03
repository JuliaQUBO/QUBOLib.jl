module QUBOInstances

using LazyArtifacts
using QUBOTools

const collections = abspath(joinpath(@__DIR__, "..", "..", "QUBOInstancesData.jl", "collections"))
# const collections = artifact"collections"

export find_instance, load_instance, select

@doc raw"""
    find_instance
"""
function find_instance end

include("find.jl")

@doc raw"""
    load_instance(path)
"""
function load_instance end

include("load.jl")

@doc raw"""
    select(query)
"""
function select end

include("select.jl")

end # module QUBOInstances
