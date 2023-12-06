function list_collections()
    db = database()
    df = DBInterface.execute(db, "SELECT collection FROM collections") |> DataFrame

    return collect(df[!, :collection])
end

function list_instances(collection::AbstractString)
    db = database()
    df = DBInterface.execute(db, "SELECT instance FROM instances WHERE collection = ?", [collection]) |> DataFrame

    return collect(df[!, :instance])
end
