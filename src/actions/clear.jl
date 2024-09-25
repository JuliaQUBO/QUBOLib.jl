function QUBOLib.clear!(reg::Registry = GLOBAL_REG)
    for source in reg.sources
        QUBOLib.clear!(source)
    end

    return nothing
end

function QUBOLib.clear!(source::Symbol)
    QUBOLib.clear!(Val(source))

    return nothing
end

function QUBOLib.clear!(::Val{source}) where {source}
    @assert source isa Symbol

    @warn "No clearing routine defined for '$(source)'"

    return nothing
end
