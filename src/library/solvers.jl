function has_solver(index::LibraryIndex, solver::AbstractString)
    @assert isopen(index)

    df = DBInterface.execute(
        index.db,
        "SELECT COUNT(*) FROM Solvers WHERE solver = ?",
        (String(solver),),
    ) |> DataFrame

    return (only(df[!, 1]) > 0)
end

function add_solver!(index::LibraryIndex, solver::AbstractString, data::AbstractDict)
    @assert isopen(index)

    db = QUBOLib.database(index)

    DBInterface.execute(
        db,
        """
        INSERT INTO Solvers
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

    return DBInterface.execute(index.db, "SELECT * FROM Solvers") |> DataFrame
end

function list_solvers(index::LibraryIndex)
    @assert isopen(index)

    df = DBInterface.execute(index.db, "SELECT solver FROM Solvers") |> DataFrame

    return collect(df[!, 1])
end
