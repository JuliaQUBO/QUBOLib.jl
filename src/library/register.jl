@doc raw"""

"""
struct Registry
    sources::Vector{Symbol}

    Registry() = new(Symbol[])
end

const GLOBAL_REG = Registry()

function register!(reg::Registry, source::Symbol)
    push!(reg.source, source)
    
    return nothing
end

function register!(source::Symbol)
    register!(GLOBAL_REG, source)

    return nothing
end
