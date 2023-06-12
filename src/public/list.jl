function list_collections()
    db = database()
    df = DBInterface.execute(db, "SELECT code FROM collections") |> DataFrame

    return collect(df[!, :name])
end