struct Collection{key}
    name::String

    function Collection(key::Symbol; name::AbstractString = string(key))
        return new{key}(name)
    end
end

function Collection(data_path::AbstractString)
    data = TOML.parsefile(data_path)

end
