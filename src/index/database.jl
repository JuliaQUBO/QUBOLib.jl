const QUBOLIB_SQL_PATH = joinpath(@__DIR__, "qubolib.sql")

function _load_database(path::AbstractString)
    if !isfile(path)
        return nothing
    else
        return SQLite.DB(path)
    end
end

function _clear_database!(db)
    DBInterface.execute(db, "DROP TABLE IF EXISTS Collections;")
    DBInterface.execute(db, "DROP TABLE IF EXISTS Instances;")
    DBInterface.execute(db, "DROP TABLE IF EXISTS Solutions;")
    DBInterface.execute(db, "DROP TABLE IF EXISTS Solvers;")

    return nothing
end

function _create_database(path::AbstractString)
    # Remove file if it exists
    rm(path; force=true)

    db = SQLite.DB(path)

    @info "Creating tables"

    open(QUBOLIB_SQL_PATH) do file
        for stmt in (split(read(file, String), ";") .|> strip |> filter(!isempty))
            DBInterface.execute(db, stmt)
        end
    end

    return db
end
