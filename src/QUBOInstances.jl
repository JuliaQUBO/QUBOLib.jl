module QUBOInstances

using Pkg.Artifacts
using QUBOTools

const qubo_instances = artifact"qubo_instances"

@doc raw"""
    find_instance
"""
function find_instance end

include("find.jl")

@doc raw"""
    load_instance(id)
"""
function load_instance end

include("load.jl")

end # module QUBOInstances
