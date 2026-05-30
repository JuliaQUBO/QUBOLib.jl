struct QOBLIBQS <: QUBOTools.AbstractFormat end

const QOBLIB_COLLECTION = "qoblib"
const QOBLIB_REPOSITORY = "ZIB-AOPT/QOBLIB"
const QOBLIB_SOURCE_COMMIT = "80e45c176fc6281e5316451f02296482934785fa"
const QOBLIB_ARCHIVE_URL = "https://github.com/$(QOBLIB_REPOSITORY)/archive/$(QOBLIB_SOURCE_COMMIT).zip"

const QOBLIB_GROUPS = (
    (
        code           = "marketsplit",
        problem_class  = "Market Split",
        formulation    = "binary_unconstrained",
        path           = "01-marketsplit/models/binary_unconstrained/qs_files",
        expected_count = 156,
        nested         = false,
    ),
    (
        code           = "labs",
        problem_class  = "LABS",
        formulation    = "quadratic_unconstrained",
        path           = "02-labs/models/quadratic_unconstrained/qs_files",
        expected_count = 99,
        nested         = false,
    ),
    (
        code           = "portfolio",
        problem_class  = "Portfolio Optimization",
        formulation    = "unconstrained_quadratic_optimization",
        path           = "06-portfolio/models/unconstrained_quadratic_optimization/qs_files",
        expected_count = 128,
        nested         = true,
    ),
    (
        code           = "independentset",
        problem_class  = "Maximum Independent Set",
        formulation    = "binary_unconstrained",
        path           = "07-independentset/models/binary_unconstrained/qs_files",
        expected_count = 50,
        nested         = false,
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

        if !(1 <= i <= n) || !(1 <= j <= n)
            QUBOTools.syntax_error("QOBLIB QS variable index out of bounds: $line")
        end

        if i == j
            linear_terms[i] = get(linear_terms, i, 0.0) + c
        else
            u, v = minmax(i, j)
            quadratic_terms[(u, v)] = get(quadratic_terms, (u, v), 0.0) + c
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
    )

    if !isnothing(source_sense)
        metadata["source_sense"] = source_sense
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

    for group in groups
        group_path = joinpath(root_path, group.path)
        metrics = _read_qoblib_metrics(joinpath(group_path, "metrics.csv"))
        model_paths = _qoblib_model_paths(group_path)

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

            QUBOLib.add_instance!(
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

            count += 1
        end
    end

    expected_count = sum(group.expected_count for group in groups)

    if count != expected_count
        error("[qoblib] Expected to import $expected_count QS models, imported $count")
    end

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
        return length(_qoblib_coefficients(model)) / (n * (n + 1) / 2)
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
    expected_dimension = row["num_variables"]
    expected_density = row["density"]
    expected_min = row["min_coeff"]
    expected_max = row["max_coeff"]

    if isempty(coefficients)
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

    if !isapprox(minimum(coefficients), expected_min; rtol = 1e-8, atol = 1e-8)
        error(
            "[qoblib] Minimum coefficient mismatch for '$key': " *
            "expected $expected_min, got $(minimum(coefficients))",
        )
    end

    if !isapprox(maximum(coefficients), expected_max; rtol = 1e-8, atol = 1e-8)
        error(
            "[qoblib] Maximum coefficient mismatch for '$key': " *
            "expected $expected_max, got $(maximum(coefficients))",
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
