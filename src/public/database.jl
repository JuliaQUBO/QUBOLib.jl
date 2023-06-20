function database(path::AbstractString)
    return SQLite.DB(joinpath(path, "index.sqlite"))
end

function database()
    return database(artifact"collections")
end
