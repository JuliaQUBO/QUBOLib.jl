function list_collections()
    db = database()
    df = DBInterface.execute(db, "SELECT collection FROM collections") |> DataFrame

    return collect(df[!, :collection])
end