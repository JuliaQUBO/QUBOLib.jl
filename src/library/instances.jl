function _instance_sql_value(value)
    return isnothing(value) ? missing : value
end

function _instance_sql_value(value::AbstractString)
    return String(value)
end

function _instance_sql_value(value::Symbol)
    return String(value)
end

function _instance_metadata_value(metadata)
    if isnothing(metadata) || ismissing(metadata)
        return missing
    elseif metadata isa AbstractString
        return String(metadata)
    else
        return JSON.json(metadata)
    end
end

function add_instance!(
    index::LibraryIndex,
    model::QUBOTools.Model{Int,Float64,Int},
    collection::AbstractString = "standalone";
    name::Union{<:AbstractString,Nothing} = nothing,
    source_name = nothing,
    problem_class = nothing,
    formulation = nothing,
    source_path = nothing,
    source_commit = nothing,
    original_filename = nothing,
    source_url = nothing,
    metadata = nothing,
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
                sense            ,
                domain           ,
                source_name       ,
                problem_class     ,
                formulation       ,
                source_path       ,
                source_commit     ,
                original_filename ,
                source_url        ,
                metadata          ,
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
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        (
            String(collection),
            isnothing(name) ? missing : String(name),
            QUBOTools.dimension(model),
            String(QUBOTools.sense(model)),
            String(QUBOTools.domain(model)),
            _instance_sql_value(source_name),
            _instance_sql_value(problem_class),
            _instance_sql_value(formulation),
            _instance_sql_value(source_path),
            _instance_sql_value(source_commit),
            _instance_sql_value(original_filename),
            _instance_sql_value(source_url),
            _instance_metadata_value(metadata),
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

    QUBOTools.write_model(group, model, _qubin_format())

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

    return QUBOTools.read_model(h5["instances"][string(i)], _qubin_format())
end
