const MOI = JuMP.MOI

function _instance_hdf5_group(index::LibraryIndex, instance::Integer)
    @assert isopen(index)

    instances = QUBOLib.archive(index)["instances"]
    key = string(instance)

    if !haskey(instances, key)
        error("Instance '$instance' does not exist")
    end

    return instances[key]
end

function _source_group(index::LibraryIndex, instance::Integer)
    group = _instance_hdf5_group(index, instance)

    if !haskey(group, "source")
        error("Instance '$instance' does not have a stored source formulation")
    end

    return group["source"]
end

function _read_hdf5_string(node)
    value = read(node)

    return value isa AbstractString ? String(value) : String(value)
end

function _source_format(source_group::HDF5.Group)
    attrs = HDF5.attrs(source_group)

    if !haskey(attrs, "source_format")
        error("Stored source formulation is missing the source_format attribute")
    end

    return String(attrs["source_format"])
end

function _source_content(source_group::HDF5.Group)
    if !haskey(source_group, "content")
        error("Stored source formulation is missing the content dataset")
    end

    return _read_hdf5_string(source_group["content"])
end

function _source_encoding(source_group::HDF5.Group)
    if !haskey(source_group, "encoding")
        error("Stored source formulation is missing the encoding dataset")
    end

    return JSON.parse(_read_hdf5_string(source_group["encoding"]))
end

function source_model(index::LibraryIndex, instance::Integer)
    source_group = _source_group(index, instance)
    source_format = lowercase(_source_format(source_group))

    if source_format != "lp"
        error("Unsupported source model format '$source_format'")
    end

    source_text = _source_content(source_group)

    return mktempdir() do path
        file = joinpath(path, "source.lp")

        write(file, source_text)

        return JuMP.read_from_file(file)
    end
end

function _encoding_variables(encoding::AbstractDict)
    if haskey(encoding, "variables")
        variables = encoding["variables"]
    elseif haskey(encoding, "encoding")
        variables = encoding["encoding"]
    else
        variables = encoding
    end

    if !(variables isa AbstractDict)
        error("Source encoding must contain a variables object")
    end

    return variables
end

function _encoding_index_base(encoding::AbstractDict)
    base = get(encoding, "index_base", 1)

    return _encoding_int(base, "index_base")
end

function _encoding_float(value, field::AbstractString)
    try
        if value isa AbstractString
            return parse(Float64, value)
        else
            return Float64(value)
        end
    catch err
        error("Invalid source encoding $field value '$value'")
    end
end

function _encoding_int(value, field::AbstractString)
    try
        if value isa AbstractString
            return parse(Int, value)
        else
            return Int(value)
        end
    catch err
        error("Invalid source encoding $field value '$value'")
    end
end

function _encoding_get_any(data::AbstractDict, keys::Tuple)
    for key in keys
        if haskey(data, key)
            return data[key]
        end
    end

    return nothing
end

function _encoding_constant(spec)
    if spec isa AbstractDict
        value = _encoding_get_any(spec, ("constant", "offset", "bias"))

        if isnothing(value)
            return 0.0
        else
            return _encoding_float(value, "constant")
        end
    else
        return 0.0
    end
end

function _encoding_terms(spec)
    if spec isa AbstractVector
        return spec
    elseif spec isa AbstractDict
        if !isnothing(
            _encoding_get_any(
                spec,
                ("index", "bit", "binary", "binary_index", "qubit"),
            ),
        )
            return Any[spec]
        end

        terms = _encoding_get_any(spec, ("terms", "bits", "binary_terms"))

        if !isnothing(terms)
            terms isa AbstractVector ||
                error("Source encoding terms must be an array")

            return terms
        end

        return [
            Dict("index" => key, "coefficient" => value) for (key, value) in spec if
            !(key in ("constant", "offset", "bias"))
        ]
    elseif spec isa Integer || spec isa AbstractString
        return Any[spec]
    else
        error("Unsupported source encoding term specification '$spec'")
    end
end

function _encoding_term(term, index_base::Integer)
    raw_index = nothing
    coefficient = 1.0

    if term isa Integer || term isa AbstractString
        raw_index = term
    elseif term isa AbstractVector
        isempty(term) && error("Source encoding term arrays cannot be empty")

        raw_index = term[1]

        if length(term) >= 2
            coefficient = _encoding_float(term[2], "coefficient")
        end
    elseif term isa AbstractDict
        raw_index = _encoding_get_any(
            term,
            ("index", "bit", "binary", "binary_index", "qubit"),
        )

        if isnothing(raw_index)
            error("Source encoding term is missing a binary index")
        end

        raw_coefficient =
            _encoding_get_any(term, ("coefficient", "coef", "scale", "weight"))

        if !isnothing(raw_coefficient)
            coefficient = _encoding_float(raw_coefficient, "coefficient")
        end
    else
        error("Unsupported source encoding term '$term'")
    end

    index = _encoding_int(raw_index, "index") - Int(index_base) + 1

    return (index = index, coefficient = coefficient)
end

function _project_variable(spec, state::AbstractVector{<:Real}, index_base::Integer)
    value = _encoding_constant(spec)

    for raw_term in _encoding_terms(spec)
        term = _encoding_term(raw_term, index_base)

        if !(1 <= term.index <= length(state))
            error(
                "Source encoding binary index $(term.index) is out of bounds " *
                "for bitstring length $(length(state))",
            )
        end

        value += term.coefficient * state[term.index]
    end

    return value
end

function _source_bitstring_state(index::LibraryIndex, instance::Integer, bitstring)
    normalized = _normalize_bitstring(bitstring)
    dimension = _instance_dimension(index, instance)

    if length(normalized) != dimension
        error(
            "Bitstring length mismatch for instance '$instance': " *
            "expected $dimension, got $(length(normalized))",
        )
    end

    return Float64.(_bitstring_state(normalized))
end

function project_solution(index::LibraryIndex, instance::Integer, bitstring)
    source_group = _source_group(index, instance)
    encoding = _source_encoding(source_group)
    variables = _encoding_variables(encoding)
    index_base = _encoding_index_base(encoding)
    state = _source_bitstring_state(index, instance, bitstring)
    assignment = Dict{String,Float64}()

    for (name, spec) in pairs(variables)
        key = String(name)

        if key in ("index_base", "metadata")
            continue
        end

        assignment[key] = _project_variable(spec, state, index_base)
    end

    return assignment
end

function _source_variable_value(assignment::AbstractDict, variable::JuMP.VariableRef)
    name = JuMP.name(variable)

    if !haskey(assignment, name)
        error("Source encoding does not define variable '$name'")
    end

    return assignment[name]
end

function _constraint_violation(value::Real, set; atol::Real)
    if set isa MOI.LessThan
        return max(0.0, Float64(value) - Float64(set.upper))
    elseif set isa MOI.GreaterThan
        return max(0.0, Float64(set.lower) - Float64(value))
    elseif set isa MOI.EqualTo
        return abs(Float64(value) - Float64(set.value))
    elseif set isa MOI.Interval
        return max(
            0.0,
            Float64(set.lower) - Float64(value),
            Float64(value) - Float64(set.upper),
        )
    elseif set isa MOI.ZeroOne
        binary_violation = min(abs(Float64(value)), abs(Float64(value) - 1.0))

        return binary_violation <= atol ? 0.0 : binary_violation
    elseif set isa MOI.Integer
        integer_violation = abs(Float64(value) - round(Float64(value)))

        return integer_violation <= atol ? 0.0 : integer_violation
    else
        error("Unsupported source constraint set '$(typeof(set))'")
    end
end

function evaluate_source(
    index::LibraryIndex,
    instance::Integer,
    bitstring;
    atol::Real = 1e-8,
)
    model = source_model(index, instance)
    assignment = project_solution(index, instance, bitstring)
    variable_value = variable -> _source_variable_value(assignment, variable)
    objective = JuMP.value(variable_value, JuMP.objective_function(model))
    violations = NamedTuple[]

    for (F, S) in JuMP.list_of_constraint_types(model)
        for constraint in JuMP.all_constraints(model, F, S)
            object = JuMP.constraint_object(constraint)
            value = JuMP.value(variable_value, object.func)
            violation = _constraint_violation(value, object.set; atol)

            if violation > atol
                push!(
                    violations,
                    (
                        constraint = string(constraint),
                        value = Float64(value),
                        set = string(object.set),
                        violation = violation,
                    ),
                )
            end
        end
    end

    return (
        objective = objective,
        feasible = isempty(violations),
        violations = violations,
    )
end
