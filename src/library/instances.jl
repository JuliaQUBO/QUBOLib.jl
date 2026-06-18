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

function _instance_source_encoding_value(source_encoding)
    if isnothing(source_encoding)
        return nothing
    elseif source_encoding isa AbstractString
        # Validate caller-provided JSON before preserving its original text.
        JSON.parse(source_encoding)

        return String(source_encoding)
    else
        return JSON.json(source_encoding)
    end
end

function _instance_source_metadata_value(value)
    if isnothing(value) || ismissing(value)
        return nothing
    elseif value isa AbstractString
        return String(value)
    elseif value isa Symbol
        return String(value)
    elseif value isa Number || value isa Bool
        return value
    else
        return JSON.json(value)
    end
end

function _write_instance_source_metadata!(source_group::HDF5.Group, source_metadata)
    if isnothing(source_metadata)
        return nothing
    elseif !(source_metadata isa AbstractDict)
        error("source_metadata must be a dictionary")
    end

    attrs = HDF5.attrs(source_group)

    for (key, value) in pairs(source_metadata)
        key = String(key)

        if key == "source_format"
            continue
        end

        attr_value = _instance_source_metadata_value(value)

        if !isnothing(attr_value)
            attrs[key] = attr_value
        end
    end

    return nothing
end

function _write_instance_source!(
    group::HDF5.Group;
    source_format = nothing,
    source_text = nothing,
    source_encoding = nothing,
    source_metadata = nothing,
)
    if isnothing(source_format) &&
       isnothing(source_text) &&
       isnothing(source_encoding) &&
       isnothing(source_metadata)
        return nothing
    elseif isnothing(source_format)
        error(
            "source_format is required when source_text, source_encoding, or " *
            "source_metadata is provided",
        )
    end

    source_group = HDF5.create_group(group, "source")
    HDF5.attrs(source_group)["source_format"] = String(source_format)
    _write_instance_source_metadata!(source_group, source_metadata)

    if !isnothing(source_text)
        source_group["content"] = String(source_text)
    end

    encoding = _instance_source_encoding_value(source_encoding)

    if !isnothing(encoding)
        source_group["encoding"] = encoding
    end

    return nothing
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
    source_format = nothing,
    source_text = nothing,
    source_encoding = nothing,
    source_metadata = nothing,
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
    _write_instance_source!(
        group;
        source_format,
        source_text,
        source_encoding,
        source_metadata,
    )

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
