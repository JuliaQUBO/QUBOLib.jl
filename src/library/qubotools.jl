function _qubin_format()
    if isdefined(QUBOTools, :Format)
        return Core.apply_type(getfield(QUBOTools, :Format), :qubin)()
    else
        return getfield(QUBOTools, :QUBin)()
    end
end
