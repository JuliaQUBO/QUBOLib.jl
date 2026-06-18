function _write_solution(
    fp::P,
    sol::QUBOTools.AbstractSolution,
    fmt::QUBOTools.AbstractFormat,
) where {P<:Union{HDF5.File,HDF5.Group}}
    HDF5.create_group(fp, "solution")

    _write_solution_data(fp, sol, fmt)

    fp["solution"]["sense"]  = String(QUBOTools.sense(sol))
    fp["solution"]["domain"] = String(QUBOTools.domain(sol))

    _write_solution_metadata(fp, sol, fmt)

    return nothing
end

function _write_solution_data(
    fp::P,
    sol::QUBOTools.AbstractSolution{T,U},
    fmt::QUBOTools.AbstractFormat,
) where {P<:Union{HDF5.File,HDF5.Group},T,U}
    HDF5.create_group(fp["solution"], "data")

    if isempty(sol)
        states = zeros(U, 0, 0)
        values = zeros(T, 0)
        reads = zeros(Int, 0)
    else
        samples = collect(sol)
        states = Matrix{U}(undef, length(samples), length(QUBOTools.state(first(samples))))
        values = Vector{T}(undef, length(samples))
        reads = Vector{Int}(undef, length(samples))

        for (i, sample) in enumerate(samples)
            states[i, :] = QUBOTools.state(sample)
            values[i] = QUBOTools.value(sample)
            reads[i] = QUBOTools.reads(sample)
        end
    end

    write(HDF5.create_dataset(fp["solution"]["data"], "state", U, size(states)), states)
    write(HDF5.create_dataset(fp["solution"]["data"], "value", T, size(values)), values)
    write(HDF5.create_dataset(fp["solution"]["data"], "reads", Int, size(reads)), reads)

    return nothing
end

function _write_solution_metadata(
    fp::P,
    sol::QUBOTools.AbstractSolution,
    fmt::QUBOTools.AbstractFormat,
) where {P<:Union{HDF5.File,HDF5.Group}}
    fp["solution"]["metadata"] = JSON.json(QUBOTools.metadata(sol))

    return nothing
end

function _data_dict(data)
    return Dict{String,Any}(String(k) => v for (k, v) in pairs(data))
end

function _sql_value(value)
    return isnothing(value) ? missing : value
end

function _sql_value(value::AbstractString)
    return String(value)
end

function _sql_value(value::Symbol)
    return String(value)
end

function _metadata_value(metadata)
    if isnothing(metadata) || ismissing(metadata)
        return missing
    elseif metadata isa AbstractString
        return String(metadata)
    else
        return JSON.json(metadata)
    end
end

function _sql_bool_value(value)
    if isnothing(value) || ismissing(value)
        return missing
    elseif value isa Bool
        return value
    else
        error("Boolean SQL fields must be true, false, missing, or nothing")
    end
end

function _submission_value(data::AbstractDict, key::AbstractString)
    return _sql_value(get(data, key, missing))
end

function _normalize_bitstring(bitstring)
    if isnothing(bitstring) || ismissing(bitstring)
        return missing
    elseif bitstring isa AbstractString
        value = String(bitstring)

        if occursin(r"[^01]", value)
            error("Bitstrings must be ASCII strings containing only '0' and '1'")
        end

        return value
    elseif bitstring isa AbstractVector{<:Integer}
        return sprint() do io
            for bit in bitstring
                if bit == -1 || bit == 0
                    print(io, '0')
                elseif bit == 1
                    print(io, '1')
                else
                    error("Bitstring vectors must contain only 0/1 or -1/1 values")
                end
            end
        end
    else
        error("Bitstrings must be strings or integer vectors")
    end
end

function _bitstring_state(bitstring::AbstractString)
    return [bit == '1' ? 1 : 0 for bit in bitstring]
end

function _solution_bitstring(sol::QUBOTools.AbstractSolution)
    if isempty(sol)
        return missing
    else
        return _normalize_bitstring(QUBOTools.state(first(sol)))
    end
end

function _instance_dimension(index::LibraryIndex, instance::Integer)
    db = QUBOLib.database(index)
    df = DBInterface.execute(
        db,
        "SELECT dimension FROM Instances WHERE instance = ?;",
        (instance,),
    ) |> DataFrame

    if size(df, 1) == 0
        error("Instance '$instance' does not exist")
    end

    return only(df[!, :dimension])::Integer
end

function _evaluate_qubo_value(index::LibraryIndex, instance::Integer, bitstring::AbstractString)
    model = load_instance(index, instance)
    form = QUBOTools.form(model, :sparse; domain = :bool)

    return QUBOTools.value(_bitstring_state(bitstring), form)
end

function add_submission!(index::LibraryIndex; kwargs...)::Integer
    return add_submission!(index, _data_dict(kwargs))
end

function add_submission!(index::LibraryIndex, data::AbstractDict)::Integer
    @assert isopen(index)

    data = _data_dict(data)
    db = QUBOLib.database(index)

    query = DBInterface.execute(
        db,
        """
        INSERT INTO Submissions
            (
                submitter,
                date,
                reference,
                modeling_approach,
                workflow,
                algorithm_type,
                runs,
                feasible_runs,
                successful_runs,
                success_threshold,
                hardware,
                total_runtime,
                cpu_runtime,
                gpu_runtime,
                qpu_runtime,
                other_runtime,
                remarks,
                source_path,
                metadata
            )
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        (
            _submission_value(data, "submitter"),
            _submission_value(data, "date"),
            _submission_value(data, "reference"),
            _submission_value(data, "modeling_approach"),
            _submission_value(data, "workflow"),
            _submission_value(data, "algorithm_type"),
            _submission_value(data, "runs"),
            _submission_value(data, "feasible_runs"),
            _submission_value(data, "successful_runs"),
            _submission_value(data, "success_threshold"),
            _submission_value(data, "hardware"),
            _submission_value(data, "total_runtime"),
            _submission_value(data, "cpu_runtime"),
            _submission_value(data, "gpu_runtime"),
            _submission_value(data, "qpu_runtime"),
            _submission_value(data, "other_runtime"),
            _submission_value(data, "remarks"),
            _submission_value(data, "source_path"),
            _metadata_value(get(data, "metadata", missing)),
        ),
    )

    return DBInterface.lastrowid(query)::Integer
end

function add_solution_record!(
    index::LibraryIndex,
    instance::Integer;
    submission = nothing,
    solution = nothing,
    bitstring = nothing,
    qubo_value = nothing,
    source_value = nothing,
    source_objective = nothing,
    objective_bound = nothing,
    dual_bound = nothing,
    source_feasible = nothing,
    proven_optimal::Bool = false,
    feasibility_status = "unknown",
    validation_status = nothing,
    incumbent_candidate::Bool = true,
    source_path = nothing,
    metadata = nothing,
)::Integer
    @assert isopen(index)

    bitstring = _normalize_bitstring(bitstring)
    value = _sql_value(qubo_value)
    status = validation_status
    dimension = _instance_dimension(index, instance)

    if ismissing(value) && !ismissing(bitstring) && length(bitstring) == dimension
        value = _evaluate_qubo_value(index, instance, bitstring)

        if isnothing(status)
            status = "evaluated"
        end
    elseif isnothing(status)
        status = ismissing(value) ? "unevaluated" : "evaluated"
    end

    db = QUBOLib.database(index)

    query = DBInterface.execute(
        db,
        """
        INSERT INTO SolutionRecords
            (
                instance,
                submission,
                solution,
                bitstring,
                qubo_value,
                source_value,
                source_objective,
                objective_bound,
                dual_bound,
                source_feasible,
                proven_optimal,
                feasibility_status,
                validation_status,
                incumbent_candidate,
                source_path,
                metadata
            )
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        (
            instance,
            _sql_value(submission),
            _sql_value(solution),
            bitstring,
            value,
            _sql_value(source_value),
            _sql_value(source_objective),
            _sql_value(objective_bound),
            _sql_value(dual_bound),
            _sql_bool_value(source_feasible),
            proven_optimal,
            _sql_value(feasibility_status),
            _sql_value(status),
            incumbent_candidate,
            _sql_value(source_path),
            _metadata_value(metadata),
        ),
    )

    return DBInterface.lastrowid(query)::Integer
end

function list_solution_records(index::LibraryIndex, instance::Integer)::DataFrame
    @assert isopen(index)

    db = QUBOLib.database(index)

    return DBInterface.execute(
        db,
        "SELECT * FROM SolutionRecords WHERE instance = ? ORDER BY record;",
        (instance,),
    ) |> DataFrame
end

function best_solution_record(index::LibraryIndex, instance::Integer)
    @assert isopen(index)

    db = QUBOLib.database(index)
    df = DBInterface.execute(
        db,
        "SELECT * FROM BestSolutions WHERE instance = ? LIMIT 1;",
        (instance,),
    ) |> DataFrame

    if size(df, 1) == 0
        return nothing
    else
        return df[1, :]
    end
end

function load_solution(index::LibraryIndex, solution::Integer)
    @assert isopen(index)

    h5 = QUBOLib.archive(index)

    return QUBOTools.read_solution(h5["solutions"][string(solution)], _qubin_format())
end

function load_solution(index::LibraryIndex, instance::Integer, solution::Integer)
    @assert isopen(index)

    db = QUBOLib.database(index)
    df = DBInterface.execute(
        db,
        """
        SELECT COUNT(*) AS n
        FROM Solutions
        WHERE instance = ? AND solution = ?;
        """,
        (instance, solution),
    ) |> DataFrame

    if only(df[!, :n]) == 0
        error("Solution '$solution' does not belong to instance '$instance'")
    end

    return load_solution(index, solution)
end

function load_best_solution(index::LibraryIndex, instance::Integer)
    record = best_solution_record(index, instance)

    if isnothing(record) || ismissing(record[:solution])
        return nothing
    else
        return load_solution(index, Int(record[:solution]))
    end
end

function add_solution!(
    index::LibraryIndex,
    instance::Integer,
    sol::QUBOTools.SampleSet{Float64,Int};
    submission = nothing,
    qubo_value = nothing,
    source_value = nothing,
    source_objective = nothing,
    objective_bound = nothing,
    dual_bound = nothing,
    source_feasible = nothing,
    proven_optimal = nothing,
    feasibility_status = "feasible",
    validation_status = nothing,
    incumbent_candidate::Bool = true,
    source_path = nothing,
)::Integer
    @assert isopen(index)
    @assert !isempty(sol)

    data = QUBOTools.metadata(sol)

    solver = get(data, "solver", nothing)
    value  = QUBOTools.value(sol, 1)

    optimal = if isnothing(proven_optimal)
        get(data, "status", nothing) == "optimal"
    else
        proven_optimal
    end

    provenance_value = isnothing(source_value) ? value : source_value

    db = QUBOLib.database(index)
    h5 = QUBOLib.archive(index)

    query = DBInterface.execute(
        db,
        """
        INSERT INTO Solutions
            (instance, solver, value, optimal) 
        VALUES
            (?, ?, ?, ?)   
        """,
        (instance, solver, value, optimal),
    )

    i = DBInterface.lastrowid(query)::Integer

    group = HDF5.create_group(h5["solutions"], string(i))

    _write_solution(group, sol, _qubin_format())

    add_solution_record!(
        index,
        instance;
        submission,
        solution = i,
        bitstring = _solution_bitstring(sol),
        qubo_value,
        source_value = provenance_value,
        source_objective,
        objective_bound,
        dual_bound,
        source_feasible,
        proven_optimal = optimal,
        feasibility_status,
        validation_status,
        incumbent_candidate,
        source_path,
        metadata = data,
    )

    return i
end
