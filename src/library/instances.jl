function add_instance!(
    index::LibraryIndex,
    model::QUBOTools.Model{Int,Float64,Int},
    collection::AbstractString = "standalone";
    name::Union{<:AbstractString,Nothing} = nothing,
)::Integer
    @assert isopen(index)

    db = QUBOLib.database(index)
    h5 = QUBOLib.archive(index)

    # Retrieve coefficients
    L = map(last, QUBOTools.linear_terms(model))
    Q = map(last, QUBOTools.quadratic_terms(model))

    query = DBInterface.execute(
        db,
        """
        INSERT INTO
            Instances (
                collection       ,
                name             ,
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
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        (
            String(collection),
            isnothing(name) ? missing : String(name),
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

    i = DBInterface.lastrowid(query)::Integer

    group = HDF5.create_group(h5["instances"], string(i))

    QUBOTools.write_model(group, model, QUBOTools.QUBin())

    return i
end

function remove_instance!(index::LibraryIndex, i::Integer)
    @assert isopen(index)

    db = QUBOLib.database(index)
    h5 = QUBOLib.archive(index)

    DBInterface.execute(db, "DELETE FROM Instances WHERE instance = ?;", (i,))

    HDF5.delete_object(h5["instances"], string(i))

    return nothing
end

function load_instance(index::LibraryIndex, i::Integer)
    @assert isopen(index)

    h5 = QUBOLib.archive(index)

    return QUBOTools.read_model(h5["instances"][string(i)], QUBOTools.QUBin())
end
