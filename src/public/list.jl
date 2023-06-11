function list_collections()
    dbpath = joinpath(collections, "index.sqlite")

    db = SQLite.DB(dbpath)
    df = DBInterface.execute(db, "SELECT code FROM collections") |> DataFrame

    return collect(df[!, :name])
end