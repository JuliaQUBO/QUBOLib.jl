struct QOBLIBQS <: QUBOTools.AbstractFormat end

const QOBLIB_COLLECTION = "qoblib"
const QOBLIB_REPOSITORY = "ZIB-AOPT/QOBLIB"
const QOBLIB_SOURCE_COMMIT = "80e45c176fc6281e5316451f02296482934785fa"
const QOBLIB_ARCHIVE_URL = "https://github.com/$(QOBLIB_REPOSITORY)/archive/$(QOBLIB_SOURCE_COMMIT).zip"

const QOBLIB_GROUPS = (
    (
        code                = "marketsplit",
        problem_class       = "Market Split",
        formulation         = "binary_unconstrained",
        path                = "01-marketsplit/models/binary_unconstrained/qs_files",
        solution_path       = "01-marketsplit/solutions",
        solution_format     = :bit_tokens,
        expected_count      = 156,
        expected_incumbents = 115,
        nested              = false,
    ),
    (
        code                = "labs",
        problem_class       = "LABS",
        formulation         = "quadratic_unconstrained",
        path                = "02-labs/models/quadratic_unconstrained/qs_files",
        solution_path       = "02-labs/solutions",
        solution_format     = :labs_bits,
        expected_count      = 99,
        expected_incumbents = 99,
        nested              = false,
    ),
    (
        code                = "portfolio",
        problem_class       = "Portfolio Optimization",
        formulation         = "unconstrained_quadratic_optimization",
        path                = "06-portfolio/models/unconstrained_quadratic_optimization/qs_files",
        solution_path       = "06-portfolio/solutions/uqo",
        solution_format     = :assignments,
        expected_count      = 128,
        expected_incumbents = 128,
        nested              = true,
    ),
    (
        code                = "independentset",
        problem_class       = "Maximum Independent Set",
        formulation         = "binary_unconstrained",
        path                = "07-independentset/models/binary_unconstrained/qs_files",
        solution_path       = "07-independentset/solutions",
        solution_format     = :active_indices,
        expected_count      = 50,
        expected_incumbents = 50,
        nested              = false,
    ),
)

const QOBLIB_CITATION = """
@misc{koch2025quantumoptimizationbenchmarkinglibrary,
  title={Quantum Optimization Benchmarking Library - The Intractable Decathlon},
  author={Thorsten Koch and David E. Bernal Neira and Ying Chen and Giorgio Cortiana and Daniel J. Egger and Raoul Heese and Narendra N. Hegade and Alejandro Gomez Cadavid and Rhea Huang and Toshinari Itoko and Thomas Kleinert and Pedro Maciel Xavier and Naeimeh Mohseni and Jhon A. Montanez-Barrera and Koji Nakano and Giacomo Nannicini and Corey O'Meara and Justin Pauckert and Manuel Proissl and Anurag Ramesh and Maximilian Schicker and Noriaki Shimada and Mitsuharu Takeori and Victor Valls and David Van Bulck and Stefan Woerner and Christa Zoufal},
  year={2025},
  eprint={2504.03832},
  archivePrefix={arXiv},
  primaryClass={quant-ph},
  url={https://arxiv.org/abs/2504.03832},
}
"""

const QOBLIB_DATA = Dict{String,Any}(
    "name"         => "Quantum Optimization Benchmarking Library (QOBLIB)",
    "author"       => [
        "Thorsten Koch",
        "David E. Bernal Neira",
        "Ying Chen",
        "Giorgio Cortiana",
        "Daniel J. Egger",
        "Raoul Heese",
        "Narendra N. Hegade",
        "Alejandro Gomez Cadavid",
        "Rhea Huang",
        "Toshinari Itoko",
        "Thomas Kleinert",
        "Pedro Maciel Xavier",
        "Naeimeh Mohseni",
        "Jhon A. Montanez-Barrera",
        "Koji Nakano",
        "Giacomo Nannicini",
        "Corey O'Meara",
        "Justin Pauckert",
        "Manuel Proissl",
        "Anurag Ramesh",
        "Maximilian Schicker",
        "Noriaki Shimada",
        "Mitsuharu Takeori",
        "Victor Valls",
        "David Van Bulck",
        "Stefan Woerner",
        "Christa Zoufal",
    ],
    "description"  => "QUBO-ready models from QOBLIB's quantum optimization benchmark suite.",
    "year"         => 2025,
    "url"          => "https://github.com/$(QOBLIB_REPOSITORY)",
    "license"      => "Apache-2.0",
    "data_license" => "CC-BY-4.0",
    "citation"     => QOBLIB_CITATION,
    "metadata"     => Dict{String,Any}(
        "source_name"   => "QOBLIB",
        "source_commit" => QOBLIB_SOURCE_COMMIT,
        "source_url"    => "https://github.com/$(QOBLIB_REPOSITORY)/tree/$(QOBLIB_SOURCE_COMMIT)",
        "arxiv"         => "2504.03832",
    ),
)

function _qoblib_parse_float(value::AbstractString)
    try
        return parse(Float64, value)
    catch err
        QUBOTools.syntax_error("Invalid QOBLIB QS float: $value")

        throw(err)
    end
end

function _qoblib_parse_int(value::AbstractString)
    try
        return parse(Int, value)
    catch err
        QUBOTools.syntax_error("Invalid QOBLIB QS integer: $value")

        throw(err)
    end
end

function _qoblib_comment(line::AbstractString)
    return strip(line[2:end])
end

function _qoblib_source_sense(comment::AbstractString)
    line = lowercase(comment)

    if occursin(r"\bminimize\b", line)
        return "min"
    elseif occursin(r"\bmaximize\b", line)
        return "max"
    else
        return nothing
    end
end

function QUBOTools.read_model(io::IO, ::QOBLIBQS)
    n = nothing
    nnz = nothing
    terms = 0
    offset = 0.0
    source_sense = nothing
    raw_min_coeff = nothing
    raw_max_coeff = nothing
    linear_terms = Dict{Int,Float64}()
    quadratic_terms = Dict{Tuple{Int,Int},Float64}()

    for raw_line in eachline(io)
        line = strip(raw_line)

        if isempty(line)
            continue
        elseif startswith(line, "#")
            comment = _qoblib_comment(line)

            if startswith(comment, "ObjectiveOffset")
                parts = split(comment)

                if length(parts) != 2
                    QUBOTools.syntax_error("Invalid QOBLIB QS objective offset line: $line")
                end

                offset = _qoblib_parse_float(parts[2])
            else
                sense = _qoblib_source_sense(comment)

                if !isnothing(sense)
                    source_sense = sense
                end
            end

            continue
        end

        parts = split(line)

        if isnothing(n)
            if length(parts) != 2
                QUBOTools.syntax_error("Invalid QOBLIB QS header: $line")
            end

            n = _qoblib_parse_int(parts[1])
            nnz = _qoblib_parse_int(parts[2])

            if n < 0 || nnz < 0
                QUBOTools.syntax_error(
                    "QOBLIB QS header values must be non-negative: $line",
                )
            end

            continue
        elseif length(parts) != 3
            QUBOTools.syntax_error("Invalid QOBLIB QS coefficient line: $line")
        end

        i = _qoblib_parse_int(parts[1])
        j = _qoblib_parse_int(parts[2])
        c = _qoblib_parse_float(parts[3])
        raw_min_coeff = isnothing(raw_min_coeff) ? c : min(raw_min_coeff, c)
        raw_max_coeff = isnothing(raw_max_coeff) ? c : max(raw_max_coeff, c)

        if !(1 <= i <= n) || !(1 <= j <= n)
            QUBOTools.syntax_error("QOBLIB QS variable index out of bounds: $line")
        end

        if i == j
            linear_terms[i] = get(linear_terms, i, 0.0) + c
        else
            u, v = minmax(i, j)
            quadratic_terms[(u, v)] = get(quadratic_terms, (u, v), 0.0) + 2c
        end

        terms += 1
    end

    if isnothing(n)
        QUBOTools.syntax_error("Missing QOBLIB QS header")
    elseif terms != nnz
        QUBOTools.syntax_error("QOBLIB QS expected $nnz coefficients but found $terms")
    end

    metadata = Dict{String,Any}(
        "format"           => "QOBLIB QS",
        "objective_offset" => offset,
        "raw_nonzeros"     => terms,
    )

    if !isnothing(source_sense)
        metadata["source_sense"] = source_sense
    end

    if !isnothing(raw_min_coeff)
        metadata["raw_min_coeff"] = raw_min_coeff
        metadata["raw_max_coeff"] = raw_max_coeff
    end

    return QUBOTools.Model{Int,Float64,Int}(
        Set{Int}(1:n),
        linear_terms,
        quadratic_terms;
        offset,
        sense    = :min,
        domain   = :bool,
        metadata = metadata,
    )
end

function QUBOTools.read_model(path::AbstractString, fmt::QOBLIBQS)
    if endswith(path, ".xz")
        @assert run(`which xz`, devnull, devnull).exitcode == 0 "'xz' is required to read QOBLIB QS archives"

        return open(`xz -dc $path`, "r") do io
            QUBOTools.read_model(io, fmt)
        end
    else
        return open(path, "r") do io
            QUBOTools.read_model(io, fmt)
        end
    end
end

function _qoblib_qs_stem(path::AbstractString)
    name = basename(path)

    if endswith(name, ".xz")
        name = first(splitext(name))
    end

    if endswith(name, ".qs")
        name = first(splitext(name))
    end

    return name
end

function _qoblib_solution_status(file::AbstractString)
    stem = first(splitext(file))

    if endswith(stem, ".opt")
        return (stem = chop(stem; tail = 4), status = "optimal", proven_optimal = true)
    elseif endswith(stem, ".bst")
        return (stem = chop(stem; tail = 4), status = "best_known", proven_optimal = false)
    else
        return (stem = stem, status = "reference", proven_optimal = false)
    end
end

function _qoblib_portfolio_key(stem::AbstractString)
    name = startswith(stem, "uqo_") ? stem[5:end] : String(stem)
    m = match(r"^(.*)_l([^_]+)$", name)

    if isnothing(m)
        return name
    else
        return "$(m.captures[1])|$(repr(parse(Float64, m.captures[2])))"
    end
end

function _qoblib_solution_key(group, path::AbstractString)
    stem = _qoblib_qs_stem(path)

    if hasproperty(group, :solution_format) && group.solution_format == :assignments
        return _qoblib_portfolio_key(stem)
    else
        return stem
    end
end

function _qoblib_portfolio_variant(value::AbstractString)
    variant = strip(value)

    if variant == "orig"
        return "orig"
    else
        return "s$(lpad(string(round(Int, parse(Float64, variant))), 2, '0'))"
    end
end

function _qoblib_parse_markdown_number(value::AbstractString)
    text = replace(strip(value), "\\" => "")
    text = replace(text, "*" => "")
    text = replace(text, "," => "")

    if isempty(text) || text == "[TO FILL]"
        return missing
    end

    return parse(Float64, text)
end

function _qoblib_portfolio_source_values(path::AbstractString)
    values = Dict{String,Float64}()

    if !isfile(path)
        return values
    end

    for line in eachline(path)
        text = strip(line)

        if !startswith(text, "|") || occursin("---", text)
            continue
        end

        cells = strip.(split(strip(text, ['|']), '|'))

        if length(cells) < 6 || lowercase(cells[1]) == "a"
            continue
        end

        source_value = _qoblib_parse_markdown_number(cells[6])

        if ismissing(source_value)
            continue
        end

        a = round(Int, parse(Float64, cells[1]))
        t = round(Int, parse(Float64, cells[2]))
        s = _qoblib_portfolio_variant(cells[3])
        b = round(Int, parse(Float64, cells[4]))
        lambda = parse(Float64, cells[5])
        base = "a$(lpad(string(a), 3, '0'))_t$(t)_$(s)_b$(lpad(string(b), 3, '0'))"

        values["$base|$(repr(lambda))"] = source_value
    end

    return values
end

function _qoblib_direct_solution_index(root_path::AbstractString, group)
    index = Dict{String,Any}()
    solution_path = joinpath(root_path, group.solution_path)

    if !isdir(solution_path)
        return index
    end

    for (root, _, files) in walkdir(solution_path)
        for file in files
            endswith(file, ".sol") || continue

            status = _qoblib_solution_status(file)
            path = joinpath(root, file)

            index[status.stem] = (
                kind = :file,
                path = path,
                member = nothing,
                status = status.status,
                proven_optimal = status.proven_optimal,
                source_value = missing,
            )
        end
    end

    return index
end

function _qoblib_tar_solution_index(root_path::AbstractString, group)
    @assert run(`which tar`, devnull, devnull).exitcode == 0 "'tar' is required to read QOBLIB solution archives"

    index = Dict{String,Any}()
    solution_path = joinpath(root_path, group.solution_path)
    source_values = _qoblib_portfolio_source_values(joinpath(solution_path, "README.md"))

    if !isdir(solution_path)
        return index
    end

    for archive_path in
        sort(filter(endswith(".tar.gz"), readdir(solution_path; join = true)))
        listing = read(Cmd(["tar", "-tzf", archive_path]), String)

        for member in eachsplit(listing, '\n')
            member = strip(member)

            if !endswith(member, ".sol")
                continue
            end

            key = _qoblib_portfolio_key(first(splitext(basename(member))))

            index[key] = (
                kind = :tar,
                path = archive_path,
                member = member,
                status = "best_known",
                proven_optimal = false,
                source_value = get(source_values, key, missing),
            )
        end
    end

    return index
end

function _qoblib_solution_index(root_path::AbstractString, group)
    if !hasproperty(group, :solution_path)
        return Dict{String,Any}()
    elseif hasproperty(group, :solution_format) && group.solution_format == :assignments
        return _qoblib_tar_solution_index(root_path, group)
    else
        return _qoblib_direct_solution_index(root_path, group)
    end
end

function _qoblib_source_value(line::AbstractString)
    m = match(
        r"(?i)(?:energy|objective\s+value)\s*[:=]\s*([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)",
        line,
    )

    return isnothing(m) ? missing : parse(Float64, m.captures[1])
end

function _qoblib_parse_bit_tokens(lines::Vector{String})
    tokens = String[]

    for line in lines
        append!(tokens, split(line))
    end

    return map(tokens) do token
        if token == "0"
            return 0
        elseif token == "1"
            return 1
        else
            QUBOTools.syntax_error("Invalid QOBLIB incumbent bit '$token'")
        end
    end
end

function _qoblib_read_bit_tokens(lines::Vector{String}, dimension::Integer)
    state = _qoblib_parse_bit_tokens(lines)

    if length(state) != dimension
        QUBOTools.syntax_error(
            "QOBLIB incumbent bitstring length mismatch: expected $dimension, got $(length(state))",
        )
    end

    return state
end

function _qoblib_read_labs_bits(lines::Vector{String}, dimension::Integer)
    state = _qoblib_parse_bit_tokens(lines)
    n = length(state)
    expected_dimension = n + div(n * (n - 1), 2)

    if dimension != expected_dimension
        QUBOTools.syntax_error(
            "QOBLIB LABS incumbent dimension mismatch: expected $dimension, reconstructed $expected_dimension",
        )
    end

    for i = 1:(n - 1)
        for j = (i + 1):n
            push!(state, state[i] * state[j])
        end
    end

    return state
end

function _qoblib_read_active_indices(lines::Vector{String}, dimension::Integer)
    state = zeros(Int, dimension)

    for line in lines
        for token in split(line)
            index = _qoblib_parse_int(token)

            if !(1 <= index <= dimension)
                QUBOTools.syntax_error(
                    "QOBLIB incumbent active index out of bounds: $index",
                )
            elseif state[index] == 1
                QUBOTools.syntax_error("Duplicate QOBLIB incumbent active index: $index")
            end

            state[index] = 1
        end
    end

    return state
end

function _qoblib_read_assignments(lines::Vector{String}, dimension::Integer)
    state = fill(-1, dimension)

    for line in lines
        m = match(
            r"^x#([0-9]+)\s+([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)$",
            strip(line),
        )

        if isnothing(m)
            QUBOTools.syntax_error("Invalid QOBLIB incumbent assignment: $line")
        end

        index = _qoblib_parse_int(m.captures[1])
        value = parse(Float64, m.captures[2])

        if !(1 <= index <= dimension)
            QUBOTools.syntax_error(
                "QOBLIB incumbent assignment index out of bounds: $index",
            )
        end

        bit = round(Int, value)

        if !isapprox(value, bit; atol = 1e-9) || !(bit == 0 || bit == 1)
            QUBOTools.syntax_error("Invalid QOBLIB incumbent assignment value: $value")
        elseif state[index] != -1
            QUBOTools.syntax_error("Duplicate QOBLIB incumbent assignment: x#$index")
        end

        state[index] = bit
    end

    missing = findfirst(==(-1), state)

    if !isnothing(missing)
        QUBOTools.syntax_error("Missing QOBLIB incumbent assignment: x#$missing")
    end

    return state
end

function _qoblib_read_solution(io::IO, format::Symbol, dimension::Integer)
    lines = String[]
    source_value = missing

    for raw_line in eachline(io)
        line = strip(raw_line)

        isempty(line) && continue

        if startswith(line, "#")
            value = _qoblib_source_value(line)

            if !ismissing(value)
                source_value = value
            end
        else
            push!(lines, line)
        end
    end

    state = if format == :bit_tokens
        _qoblib_read_bit_tokens(lines, dimension)
    elseif format == :labs_bits
        _qoblib_read_labs_bits(lines, dimension)
    elseif format == :active_indices
        _qoblib_read_active_indices(lines, dimension)
    elseif format == :assignments
        _qoblib_read_assignments(lines, dimension)
    else
        error("[qoblib] Unsupported incumbent solution format '$format'")
    end

    return (state = state, source_value = source_value)
end

function _qoblib_read_solution(info, format::Symbol, dimension::Integer)
    if info.kind == :file
        return open(info.path, "r") do io
            _qoblib_read_solution(io, format, dimension)
        end
    elseif info.kind == :tar
        return open(Cmd(["tar", "-xOzf", info.path, String(info.member)]), "r") do io
            _qoblib_read_solution(io, format, dimension)
        end
    else
        error("[qoblib] Unsupported incumbent source kind '$(info.kind)'")
    end
end

function _qoblib_source_path(root_path::AbstractString, info)
    source_path = replace(relpath(info.path, root_path), '\\' => '/')

    if isnothing(info.member)
        return source_path
    else
        return "$(source_path)!$(info.member)"
    end
end

function _qoblib_source_url(root_path::AbstractString, info)
    source_path = replace(relpath(info.path, root_path), '\\' => '/')

    return "https://github.com/$(QOBLIB_REPOSITORY)/blob/$(QOBLIB_SOURCE_COMMIT)/$(source_path)"
end

function _qoblib_incumbent_metadata(
    root_path::AbstractString,
    group,
    info;
    source_value = missing,
)
    metadata = Dict{String,Any}(
        "source_name"       => "QOBLIB",
        "source_commit"     => QOBLIB_SOURCE_COMMIT,
        "source_path"       => _qoblib_source_path(root_path, info),
        "source_url"        => _qoblib_source_url(root_path, info),
        "source_status"     => info.status,
        "source_format"     => String(group.solution_format),
        "validation_status" => "validated",
        "qubo_value_source" => "QUBOTools.value(model, bitstring)",
    )

    if !ismissing(source_value)
        metadata["source_value"] = source_value
    end

    if !isnothing(info.member)
        metadata["source_member"] = info.member
    end

    return metadata
end

function _qoblib_missing_incumbent_metadata(
    root_path::AbstractString,
    group,
    model_path::AbstractString,
    key::AbstractString,
)
    return Dict{String,Any}(
        "source_name"           => "QOBLIB",
        "source_commit"         => QOBLIB_SOURCE_COMMIT,
        "source_status"         => "missing",
        "validation_status"     => "missing",
        "reason"                => "missing_source_solution",
        "expected_solution_key" => key,
        "model_source_path"     => replace(relpath(model_path, root_path), '\\' => '/'),
        "solution_path"         => hasproperty(group, :solution_path) ? group.solution_path : missing,
        "source_format"         => hasproperty(group, :solution_format) ? String(group.solution_format) : missing,
    )
end

function _add_qoblib_missing_incumbent!(
    index::QUBOLib.LibraryIndex,
    instance::Integer,
    root_path::AbstractString,
    group,
    model_path::AbstractString,
    key::AbstractString,
)
    QUBOLib.add_solution_record!(
        index,
        instance;
        feasibility_status = "missing",
        validation_status = "missing",
        incumbent_candidate = false,
        metadata = _qoblib_missing_incumbent_metadata(root_path, group, model_path, key),
    )

    return :missing
end

function _add_qoblib_incumbent!(
    index::QUBOLib.LibraryIndex,
    instance::Integer,
    model::QUBOTools.Model{Int,Float64,Int},
    root_path::AbstractString,
    group,
    model_path::AbstractString,
    solution_index::Dict{String,Any},
)
    if !hasproperty(group, :solution_path)
        return :skipped
    end

    key = _qoblib_solution_key(group, model_path)

    if !haskey(solution_index, key)
        return _add_qoblib_missing_incumbent!(
            index,
            instance,
            root_path,
            group,
            model_path,
            key,
        )
    end

    info = solution_index[key]
    dimension = QUBOTools.dimension(model)
    solution = _qoblib_read_solution(info, group.solution_format, dimension)
    source_value = ismissing(info.source_value) ? solution.source_value : info.source_value

    if length(solution.state) != dimension
        error(
            "[qoblib] Incumbent dimension mismatch for '$model_path': " *
            "expected $dimension, got $(length(solution.state))",
        )
    end

    qubo_value = QUBOTools.value(model, solution.state)
    metadata = _qoblib_incumbent_metadata(root_path, group, info; source_value)
    sol = QUBOTools.SampleSet{Float64,Int}(model, [solution.state]; metadata)

    if !isapprox(QUBOTools.value(sol, 1), qubo_value; rtol = 1e-8, atol = 1e-8)
        error("[qoblib] HDF5 incumbent sample value does not match QUBO value")
    end

    QUBOLib.add_solution!(
        index,
        instance,
        sol;
        qubo_value,
        source_value = ismissing(source_value) ? missing : source_value,
        proven_optimal = info.proven_optimal,
        feasibility_status = "feasible",
        validation_status = "validated",
        incumbent_candidate = true,
        source_path = _qoblib_source_path(root_path, info),
    )

    return :imported
end

function _validate_qoblib_incumbent_counts!(
    group,
    incumbent_count::Integer,
    missing_incumbent_count::Integer,
)
    if !hasproperty(group, :expected_incumbents)
        return nothing
    end

    expected_incumbents = group.expected_incumbents
    expected_missing = group.expected_count - expected_incumbents

    if incumbent_count != expected_incumbents
        error(
            "[qoblib] Expected $(expected_incumbents) incumbents for $(group.code), " *
            "imported $incumbent_count",
        )
    elseif missing_incumbent_count != expected_missing
        error(
            "[qoblib] Expected $(expected_missing) missing incumbents for $(group.code), " *
            "marked $missing_incumbent_count",
        )
    end

    return nothing
end

function build_qoblib!(
    index::QUBOLib.LibraryIndex;
    cache::Bool = true,
    source_path::Union{AbstractString,Nothing} = nothing,
    groups = QOBLIB_GROUPS,
)
    if QUBOLib.has_collection(index, QOBLIB_COLLECTION)
        @info "[qoblib] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, QOBLIB_COLLECTION)
        end
    end

    @info "[qoblib] Building QOBLIB"

    root_path = load_qoblib!(index; source_path, groups)

    QUBOLib.add_collection!(index, QOBLIB_COLLECTION, QOBLIB_DATA)

    count = 0
    incumbent_count = 0
    missing_incumbent_count = 0

    for group in groups
        group_path = joinpath(root_path, group.path)
        metrics = _read_qoblib_metrics(joinpath(group_path, "metrics.csv"))
        model_paths = _qoblib_model_paths(group_path)
        solution_index = _qoblib_solution_index(root_path, group)
        group_incumbent_count = 0
        group_missing_incumbent_count = 0

        if length(model_paths) != group.expected_count
            error(
                "[qoblib] Expected $(group.expected_count) QS models in $(group.path), " *
                "found $(length(model_paths))",
            )
        end

        for model_path in model_paths
            metadata = _qoblib_instance_metadata(root_path, group, model_path)
            model = QUBOTools.read_model(model_path, QOBLIBQS())

            merge!(QUBOTools.metadata(model), metadata)
            _validate_qoblib_metrics!(model, metrics, model_path)

            instance = QUBOLib.add_instance!(
                index,
                model,
                QOBLIB_COLLECTION;
                name              = metadata["name"],
                source_name       = metadata["source_name"],
                problem_class     = metadata["problem_class"],
                formulation       = metadata["formulation"],
                source_path       = metadata["source_path"],
                source_commit     = metadata["source_commit"],
                original_filename = metadata["original_filename"],
                source_url        = metadata["source_url"],
                metadata          = metadata,
            )

            incumbent_status = _add_qoblib_incumbent!(
                index,
                instance,
                model,
                root_path,
                group,
                model_path,
                solution_index,
            )

            if incumbent_status == :imported
                group_incumbent_count += 1
                incumbent_count += 1
            elseif incumbent_status == :missing
                group_missing_incumbent_count += 1
                missing_incumbent_count += 1
            end

            count += 1
        end

        _validate_qoblib_incumbent_counts!(
            group,
            group_incumbent_count,
            group_missing_incumbent_count,
        )
    end

    expected_count = sum(group.expected_count for group in groups)

    if count != expected_count
        error("[qoblib] Expected to import $expected_count QS models, imported $count")
    end

    @info "[qoblib] Imported $incumbent_count incumbents; marked $missing_incumbent_count missing"

    return nothing
end

function load_qoblib!(
    index::QUBOLib.LibraryIndex;
    source_path::Union{AbstractString,Nothing} = nothing,
    groups = QOBLIB_GROUPS,
)
    source = if isnothing(source_path)
        get(ENV, "QUBOLIB_QOBLIB_SOURCE", nothing)
    else
        source_path
    end

    if isnothing(source) || isempty(String(source))
        archive_path = _download_qoblib_archive!(index)

        root_path = _extract_qoblib_archive!(index, archive_path, groups)
    elseif isdir(source)
        root_path = abspath(source)
    elseif isfile(source)
        root_path = _extract_qoblib_archive!(index, source, groups)
    else
        error(
            "[qoblib] QOBLIB source checkout/archive not found at '$source'. " *
            "Set QUBOLIB_QOBLIB_SOURCE to a QOBLIB checkout or zip archive.",
        )
    end

    _validate_qoblib_source!(root_path, groups)

    return root_path
end

function _download_qoblib_archive!(index::QUBOLib.LibraryIndex)
    cache_path = mkpath(QUBOLib.cache_path(index, QOBLIB_COLLECTION))
    archive_path = joinpath(cache_path, "qoblib-$(QOBLIB_SOURCE_COMMIT).zip")

    if isfile(archive_path)
        @info "[qoblib] Archive already downloaded"
    else
        @info "[qoblib] Downloading archive"

        Downloads.download(QOBLIB_ARCHIVE_URL, archive_path)
    end

    return archive_path
end

function _extract_qoblib_archive!(
    index::QUBOLib.LibraryIndex,
    archive_path::AbstractString,
    groups,
)
    @assert run(`which unzip`, devnull, devnull).exitcode == 0 "'unzip' is required to extract QOBLIB archive"

    data_path = QUBOLib.cache_data_path(index, QOBLIB_COLLECTION)
    root = _qoblib_archive_root(archive_path)
    patterns = _qoblib_archive_patterns(root, groups)

    rm(data_path; recursive = true, force = true)
    mkpath(data_path)

    @info "[qoblib] Extracting archive"

    run(Cmd(vcat(["unzip", "-qq", "-o", archive_path], patterns, ["-d", data_path])))

    return joinpath(data_path, root)
end

function _qoblib_archive_root(archive_path::AbstractString)
    names = read(Cmd(["unzip", "-Z1", archive_path]), String)

    for name in eachsplit(names, '\n')
        path = strip(name)

        if isempty(path)
            continue
        end

        root = first(split(path, '/'))

        if !isempty(root)
            return root
        end
    end

    error("[qoblib] Could not determine root directory in archive '$archive_path'")
end

function _qoblib_archive_patterns(root::AbstractString, groups)
    patterns = ["$root/README.md", "$root/LICENSE", "$root/LICENSE.data"]

    for group in groups
        push!(patterns, "$root/$(group.path)/README.md")
        push!(patterns, "$root/$(group.path)/metrics.csv")

        if group.nested
            push!(patterns, "$root/$(group.path)/*/*.qs.xz")
        else
            push!(patterns, "$root/$(group.path)/*.qs.xz")
        end

        if hasproperty(group, :solution_path)
            push!(patterns, "$root/$(group.solution_path)/README.md")

            if hasproperty(group, :solution_format) && group.solution_format == :assignments
                push!(patterns, "$root/$(group.solution_path)/*.tar.gz")
            else
                push!(patterns, "$root/$(group.solution_path)/*.sol")
            end
        end
    end

    return patterns
end

function _validate_qoblib_source!(root_path::AbstractString, groups)
    missing = String[]

    for path in ("README.md", "LICENSE", "LICENSE.data")
        if !isfile(joinpath(root_path, path))
            push!(missing, path)
        end
    end

    for group in groups
        group_path = joinpath(root_path, group.path)

        if !isdir(group_path)
            push!(missing, group.path)
        end

        for file in ("README.md", "metrics.csv")
            path = joinpath(group.path, file)

            if !isfile(joinpath(root_path, path))
                push!(missing, path)
            end
        end

        if hasproperty(group, :solution_path)
            if !isdir(joinpath(root_path, group.solution_path))
                push!(missing, group.solution_path)
            end

            path = joinpath(group.solution_path, "README.md")

            if !isfile(joinpath(root_path, path))
                push!(missing, path)
            end
        end
    end

    if !isempty(missing)
        missing_list = join(missing, ", ")

        error(
            "[qoblib] QOBLIB source at '$root_path' has an unexpected layout; " *
            "missing: $missing_list",
        )
    end

    return nothing
end

function _qoblib_model_paths(path::AbstractString)
    model_paths = String[]

    for (root, _, files) in walkdir(path)
        for file in files
            if endswith(file, ".qs") || endswith(file, ".qs.xz")
                push!(model_paths, joinpath(root, file))
            end
        end
    end

    sort!(model_paths; by = path -> replace(relpath(path), '\\' => '/'))

    return model_paths
end

function _read_qoblib_metrics(path::AbstractString)
    if !isfile(path)
        error("[qoblib] Missing metrics file '$path'")
    end

    metrics = Dict{String,Dict{String,Any}}()

    open(path, "r") do io
        header = split(strip(readline(io)), ',')

        for line in eachline(io)
            isempty(strip(line)) && continue

            values = split(strip(line), ',')

            if length(values) != length(header)
                error("[qoblib] Invalid metrics row in '$path': $line")
            end

            row = Dict{String,String}(
                String(k) => String(v) for (k, v) in zip(header, values)
            )
            metrics[row["file"]] = Dict{String,Any}(
                "num_variables" => parse(Int, row["num_variables"]),
                "density"       => parse(Float64, row["density"]),
                "min_coeff"     => parse(Float64, row["min_coeff"]),
                "max_coeff"     => parse(Float64, row["max_coeff"]),
            )
        end
    end

    return metrics
end

function _qoblib_metric_key(path::AbstractString)
    name = basename(path)

    if endswith(name, ".xz")
        name = first(splitext(name))
    end

    return name
end

function _qoblib_coefficients(model::QUBOTools.Model{Int,Float64,Int})
    coefficients = Float64[]

    for (_, value) in QUBOTools.linear_terms(model)
        push!(coefficients, value)
    end

    for (_, value) in QUBOTools.quadratic_terms(model)
        push!(coefficients, value)
    end

    return coefficients
end

function _qoblib_density(model::QUBOTools.Model{Int,Float64,Int})
    n = QUBOTools.dimension(model)

    if n == 0
        return 0.0
    else
        raw_nonzeros = get(
            QUBOTools.metadata(model),
            "raw_nonzeros",
            length(_qoblib_coefficients(model)),
        )

        return raw_nonzeros / (n * (n + 1) / 2)
    end
end

function _validate_qoblib_metrics!(
    model::QUBOTools.Model{Int,Float64,Int},
    metrics::Dict{String,Dict{String,Any}},
    path::AbstractString,
)
    key = _qoblib_metric_key(path)

    if !haskey(metrics, key)
        error("[qoblib] Missing metrics row for '$key'")
    end

    row = metrics[key]
    coefficients = _qoblib_coefficients(model)
    metadata = QUBOTools.metadata(model)
    expected_dimension = row["num_variables"]
    expected_density = row["density"]
    expected_min = row["min_coeff"]
    expected_max = row["max_coeff"]
    raw_nonzeros = get(metadata, "raw_nonzeros", length(coefficients))

    if raw_nonzeros == 0
        error("[qoblib] Model '$path' has no nonzero coefficients")
    end

    if QUBOTools.dimension(model) != expected_dimension
        error(
            "[qoblib] Dimension mismatch for '$key': " *
            "expected $expected_dimension, got $(QUBOTools.dimension(model))",
        )
    end

    if !isapprox(_qoblib_density(model), expected_density; rtol = 1e-6, atol = 1e-9)
        error(
            "[qoblib] Density mismatch for '$key': " *
            "expected $expected_density, got $(_qoblib_density(model))",
        )
    end

    raw_min_coeff = if haskey(metadata, "raw_min_coeff")
        metadata["raw_min_coeff"]
    else
        minimum(coefficients)
    end

    raw_max_coeff = if haskey(metadata, "raw_max_coeff")
        metadata["raw_max_coeff"]
    else
        maximum(coefficients)
    end

    if !isapprox(raw_min_coeff, expected_min; rtol = 1e-8, atol = 1e-8)
        error(
            "[qoblib] Minimum coefficient mismatch for '$key': " *
            "expected $expected_min, got $raw_min_coeff",
        )
    end

    if !isapprox(raw_max_coeff, expected_max; rtol = 1e-8, atol = 1e-8)
        error(
            "[qoblib] Maximum coefficient mismatch for '$key': " *
            "expected $expected_max, got $raw_max_coeff",
        )
    end

    return nothing
end

function _qoblib_instance_metadata(root_path::AbstractString, group, path::AbstractString)
    source_path = replace(relpath(path, root_path), '\\' => '/')
    name = replace(relpath(path, joinpath(root_path, group.path)), '\\' => '/')
    source_url = "https://github.com/$(QOBLIB_REPOSITORY)/blob/$(QOBLIB_SOURCE_COMMIT)/$(source_path)"

    return Dict{String,Any}(
        "name"              => name,
        "source_name"       => "QOBLIB",
        "problem_class"     => group.problem_class,
        "formulation"       => group.formulation,
        "source_path"       => source_path,
        "source_commit"     => QOBLIB_SOURCE_COMMIT,
        "original_filename" => basename(path),
        "source_url"        => source_url,
        "source_reference"  => "https://github.com/$(QOBLIB_REPOSITORY)/tree/$(QOBLIB_SOURCE_COMMIT)/$(dirname(source_path))",
        "collection"        => QOBLIB_COLLECTION,
    )
end

function deploy_qoblib!(index::QUBOLib.LibraryIndex)
    close(index)

    src_path = QUBOLib.cache_data_path(index, QOBLIB_COLLECTION)
    dst_path = mkpath(joinpath(QUBOLib.build_path(index), "mirror"))
    zip_path = joinpath(dst_path, "qoblib.zip")

    run(Cmd(`zip -q -r $zip_path .`, dir = src_path))

    return nothing
end
