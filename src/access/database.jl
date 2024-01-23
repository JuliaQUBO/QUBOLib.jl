function database(path::AbstractString)
    return SQLite.DB(abspath(path, "index.sqlite"))
end

function database()
    return database(data_path())
end
