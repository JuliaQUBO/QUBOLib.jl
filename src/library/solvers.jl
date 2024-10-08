function has_solver(index::LibraryIndex, solver::String)
    @assert isopen(index)

    df = DBInterface.query(
        index.db,
        "SELECT COUNT(*) FROM solvers WHERE solver = ?",
        (solver,),
    ) |> DataFrame

    return (only(df[!, 1]) > 0)
end

function add_solver!(index::LibraryIndex, solver::AbstractString, data::Dict{String,Any})
    @assert isopen(index)

    db = QUBOLib.database(index)

    DBInterface.execute(
        db,
        """
        INSERT INTO solvers
            (solver, version, description) 
        VALUES
            (?, ?, ?);
        """,
        (
            String(solver),
            get(data, "version", missing),
            get(data, "description", missing),
        ),
    )

    return nothing
end

function get_solvers(index::LibraryIndex)
    @assert isopen(index)

    return DBInterface.query(index.db, "SELECT * FROM solvers") |> DataFrame
end

function list_solvers(index::LibraryIndex)
    @assert isopen(index)

    df = DBInterface.query(index.db, "SELECT solver FROM solvers") |> DataFrame

    return collect(df[!, 1])
end
