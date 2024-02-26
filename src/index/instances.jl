function add_instance!(
    index::LibraryIndex,
    coll::Symbol,
    model::QUBOTools.Model{Int,Float64,Int},
)::Integer
    @assert isopen(index)

    L = map(last, QUBOTools.linear_terms(model))
    Q = map(last, QUBOTools.quadratic_terms(model))

    q = DBInterface.execute(
        index.db,
        """
        INSERT INTO Instances (
            collection       ,
            dimension        ,
            min              ,
            max              ,
            abs_min          ,
            abs_max          ,
            linear_min       ,
            linear_max       ,
            quadratic_min    ,
            quadratic_max    ,
            density          ,
            linear_density   ,
            quadratic_density
        ) 
        VALUES (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
        );
        """,
        (
            string(coll),
            QUBOTools.dimension(model),
            min(minimum(L), minimum(Q)),
            max(maximum(L), maximum(Q)),
            min(minimum(abs, L), minimum(abs, Q)),
            max(maximum(abs, L), maximum(abs, Q)),
            minimum(L),
            maximum(L),
            minimum(Q),
            maximum(Q),
            QUBOTools.density(model),
            QUBOTools.linear_density(model),
            QUBOTools.quadratic_density(model),
        ),
    )

    i = DBInterface.lastrowid(q)
    g = HDF5.create_group(index.h5["instances"], string(i))

    QUBOTools.write_model(g, model, QUBOTools.QUBin())

    return i
end

function get_instance(index::LibraryIndex, i::Integer)
    @assert isopen(index)

    i = string(i)
    g = HDF5.open(index.h5["instances"], i)

    return QUBOTools.read_model(g, QUBOTools.QUBin())
end
