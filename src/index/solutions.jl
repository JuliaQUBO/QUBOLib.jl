function add_solution!(index::LibraryIndex, instance::Integer, sol::SampleSet{Float64,Int})
    @assert isopen(index)
    @assert !isempty(sol)

    data = QUBOTools.metadata(sol)

    if !haskey(data, "solver")
        data["solver"] = "unknown"
    end

    DBInterface.execute(
        index.db,
        """
        INSERT INTO solutions (
            instance,
            value,
            solver,
        ) 
        VALUES (
            ?,
            ?,
            ?
        )   
        """,
        (instance, QUBOTools.value(sol[begin]), sol.num_occurrences[1]),
    )

    i = string(DBInterface.lastrowid(index.db))
    g = HDF5.create_group(index.h5["solutions"], i)

    QUBOTools.write_sampleset(g, sol, QUBOTools.QUBin())

    return nothing
end
