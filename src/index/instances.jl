function add_instance!(
    index::LibraryIndex,
    coll::Symbol,
    model::QUBOTools.Model{Int,Float64,Int},
)
    @assert isopen(index)

    DBInterface.execute(
        index.db,
        """
        INSERT INTO instances (
            collection,
            dimension,
        ) 
        VALUES (
            ?,
            ?
        )   
        """,
        (string(coll), QUBOTools.dimension(model)),
    )

    i = string(DBInterface.lastrowid(index.db))
    g = HDF5.create_group(index.h5["instances"], i)

    QUBOTools.write_model(g, model, QUBOTools.QUBin())

    return nothing
end

function get_instance(index::LibraryIndex, i::Integer)
    @assert isopen(index)

    i = string(i)
    g = HDF5.open(index.h5["instances"], i)

    return QUBOTools.read_model(g, QUBOTools.QUBin())
end
