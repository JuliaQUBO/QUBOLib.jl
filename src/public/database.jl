function database()
    return SQLite.DB(joinpath(artifact"collections", "index.sqlite"))
end