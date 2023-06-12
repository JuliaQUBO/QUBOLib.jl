function database()
    return SQLite.DB(joinpath(collections, "index.sqlite"))
end