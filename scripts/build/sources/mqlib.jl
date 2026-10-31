# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
# MQLib — Library of Max-Cut and QUBO Heuristics
# Source: https://github.com/MQLib/MQLib (MIT License)
# Reference: I. Dunning, S. Gupta, and J. Silberholz (2018),
#   "What Works Best When? A Systematic Evaluation of Heuristics for Max-Cut
#    and QUBO", INFORMS Journal on Computing 30(3):608-624,
#   https://doi.org/10.1287/ijoc.2017.0798
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

const MQLIB_COLLECTION    = "mqlib"
const MQLIB_REPOSITORY    = "MQLib/MQLib"
const MQLIB_SOURCE_COMMIT = "585496274af5abb0849d0d47e135496b4688680b"
const MQLIB_CITATION_DOI  = "10.1287/ijoc.2017.0798"
const MQLIB_S3_BASE_URL   = "https://mqlibinstances.s3.amazonaws.com"
const MQLIB_MIRROR_URL    = "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/data-mirror/mqlib.zip"
const MQLIB_MIRROR_SHA256 = "2d4845f55587fb590304df4425f485acfb3fd039b20a53cd399cb29e32ec1bfc"

const MQLIB_QPLIB_OVERLAP = Dict{String,Dict{String,Any}}(
    "be250.8" => Dict{String,Any}(
        "qplib_name"        => "QPLIB_5909.qplib",
        "qplib_source_name" => "QPLIB_5909",
        "biqmac_name"       => "bqp250-8",
    ),
    "be500.2" => Dict{String,Any}(
        "qplib_name"        => "QPLIB_5922.qplib",
        "qplib_source_name" => "QPLIB_5922",
        "biqmac_name"       => "bqp500-2",
    ),
)

const MQLIB_PALUBECKIS_DEFERRED = NamedTuple{(:name, :graphname, :n, :m, :best_objective, :best_heuristic, :seed),Tuple{String,String,Int,Int,Float64,String,Int}}[]

const MQLIB_HEURISTICS = Dict{String,NamedTuple{(:domain, :description),Tuple{String,String}}}(
    "ALKHAMIS1998"       => (domain = "QUBO",    description = "Simulated annealing (Alkhamis et al. 1998)"),
    "BEASLEY1998SA"      => (domain = "QUBO",    description = "Simulated annealing (Beasley 1998)"),
    "BEASLEY1998TS"      => (domain = "QUBO",    description = "Tabu search (Beasley 1998)"),
    "BURER2002"          => (domain = "MAX-CUT", description = "Rank-2 relaxation of Goemans-Williamson algorithm with local search (Burer et al. 2002)"),
    "DESOUSA2013"        => (domain = "MAX-CUT", description = "Estimation of distribution algorithm for Max-Cut (de Sousa et al. 2013)"),
    "DUARTE2005"         => (domain = "MAX-CUT", description = "Genetic algorithm with VNS local search (Duarte et al. 2005)"),
    "FESTA2002G"         => (domain = "MAX-CUT", description = "GRASP with local search (Festa et al. 2002)"),
    "FESTA2002GPR"       => (domain = "MAX-CUT", description = "GRASP with path-relinking (Festa et al. 2002)"),
    "FESTA2002GVNS"      => (domain = "MAX-CUT", description = "GRASP with VNS local search (Festa et al. 2002)"),
    "FESTA2002GVNSPR"    => (domain = "MAX-CUT", description = "GRASP & VNS with path-relinking (Festa et al. 2002)"),
    "FESTA2002VNS"       => (domain = "MAX-CUT", description = "Variable neighborhood search (Festa et al. 2002)"),
    "FESTA2002VNSPR"     => (domain = "MAX-CUT", description = "VNS with path-relinking (Festa et al. 2002)"),
    "GLOVER1998a"        => (domain = "QUBO",    description = "Tabu search (Glover et al. 1998a)"),
    "GLOVER2010"         => (domain = "QUBO",    description = "Tabu search with long-term memory (Glover et al. 2010)"),
    "HASAN2000GA"        => (domain = "QUBO",    description = "Genetic algorithm (Hasan et al. 2000)"),
    "HASAN2000TS"        => (domain = "QUBO",    description = "Tabu search (Hasan et al. 2000)"),
    "KATAYAMA2000"       => (domain = "QUBO",    description = "Genetic algorithm with k-opt local search (Katayama et al. 2000)"),
    "KATAYAMA2001"       => (domain = "QUBO",    description = "Simulated annealing (Katayama & Narihisa 2001)"),
    "LAGUNA2009CE"       => (domain = "MAX-CUT", description = "Cross-entropy method (Laguna et al. 2009)"),
    "LAGUNA2009HCE"      => (domain = "MAX-CUT", description = "Cross-entropy method with local search (Laguna et al. 2009)"),
    "LODI1999"           => (domain = "QUBO",    description = "Genetic algorithm (Lodi et al. 1999)"),
    "LU2010"             => (domain = "QUBO",    description = "Genetic algorithm with tabu search (Lü et al. 2010)"),
    "MERZ1999CROSS"      => (domain = "QUBO",    description = "Genetic algorithm with crossover only (Merz & Freisleben 1999)"),
    "MERZ1999GLS"        => (domain = "QUBO",    description = "Genetic algorithm with crossover and local search (Merz & Freisleben 1999)"),
    "MERZ1999MUTATE"     => (domain = "QUBO",    description = "Genetic algorithm with mutation only (Merz & Freisleben 1999)"),
    "MERZ2002GREEDY"     => (domain = "QUBO",    description = "GRASP without local search (Merz & Freisleben 2002)"),
    "MERZ2002GREEDYKOPT" => (domain = "QUBO",    description = "k-opt local search with GRASP (Merz & Freisleben 2002)"),
    "MERZ2002KOPT"       => (domain = "QUBO",    description = "k-opt local search with random restarts (Merz & Freisleben 2002)"),
    "MERZ2002ONEOPT"     => (domain = "QUBO",    description = "1-opt local search with random restarts (Merz & Freisleben 2002)"),
    "MERZ2004"           => (domain = "QUBO",    description = "Genetic algorithm with k-opt local search (Merz & Katayama 2004)"),
    "PALUBECKIS2004bMST1"=> (domain = "QUBO",    description = "Multi-start tabu search MST1 (Palubeckis 2004b)"),
    "PALUBECKIS2004bMST2"=> (domain = "QUBO",    description = "Iterated tabu search MST2 (Palubeckis 2004b)"),
    "PALUBECKIS2004bMST3"=> (domain = "QUBO",    description = "Tabu search with GRASP MST3 (Palubeckis 2004b)"),
    "PALUBECKIS2004bMST4"=> (domain = "QUBO",    description = "Tabu search with long-term memory MST4 (Palubeckis 2004b)"),
    "PALUBECKIS2004bMST5"=> (domain = "QUBO",    description = "Iterated tabu search MST5 (Palubeckis 2004b)"),
    "PALUBECKIS2004bSTS" => (domain = "QUBO",    description = "Simple tabu search STS (Palubeckis 2004b)"),
    "PALUBECKIS2006"     => (domain = "QUBO",    description = "Iterated tabu search (Palubeckis 2006)"),
    "PARDALOS2008"       => (domain = "QUBO",    description = "Global equilibrium search (Pardalos et al. 2008)"),
)

const MQLIB_DATA = Dict{String,Any}(
    "name"         => "MQLib: Library of Max-Cut and QUBO Heuristics",
    "author"       => ["Iain Dunning", "Swati Gupta", "John Silberholz"],
    "year"         => 2018,
    "description"  => "Max-Cut and QUBO benchmark instances from MQLib (Standard Library, SteinLib, BiqMac, OR-Library, Berkeley Image Segmentation, TSPLIB95, DIMACS, Glasgow/Dharwadker, Rudy, Culberson, and NetworkX random graphs), validated heuristic bitstrings, and 38-heuristic evaluation records",
    "url"          => "https://github.com/MQLib/MQLib",
    "license"      => "MIT",
    "data_license" => "MIT",
    "citation"     => "I. Dunning, S. Gupta, and J. Silberholz (2018), What Works Best When? A Systematic Evaluation of Heuristics for Max-Cut and QUBO, INFORMS Journal on Computing 30(3):608-624. https://doi.org/10.1287/ijoc.2017.0798",
    "metadata"     => Dict{String,Any}(
        "source_repository"             => MQLIB_REPOSITORY,
        "source_commit"                 => MQLIB_SOURCE_COMMIT,
        "citation_doi"                  => MQLIB_CITATION_DOI,
        "license_evidence_url"          => "https://github.com/MQLib/MQLib/blob/$(MQLIB_SOURCE_COMMIT)/LICENSE.md",
        "s3_bucket_url"                 => MQLIB_S3_BASE_URL,
        "mirror_url"                    => MQLIB_MIRROR_URL,
        "mirror_sha256"                 => MQLIB_MIRROR_SHA256,
        "provenance_status"             => "verified",
        "rights_status"                 => "verified",
        "imported_standard_instances"   => 231,
        "imported_tier2_instances"      => 2771,
        "imported_total_instances"      => 3002,
        "deferred_palubeckis_instances" => 0,
        "deferred_synthetic_instances"  => 394,
        "deferred_total_instances"      => 394,
        "total_standard_csv_instances"  => 231,
        "total_corpus_instances"        => 3396,
        "transformation_note"           => "QUBOLib imports 3,002 instances (88.4%) from the 3,396-instance MQLib corpus: all 231 standard.csv instances (71 G-set, 60 Beasley, 45 GKA, 30 Spin-Glass, 21 Palubeckis p3000_1..p7000_3, and 4 DIMACS Torus) plus 2,771 Tier 2 instances covering 100% of all remaining literature and application benchmarks (1,376 SteinLib up to n=38,418, 312 BiqMac, 105 OR-Library, 100 Berkeley Image Segmentation up to n=28,552, 113 Glasgow/Dharwadker, 104 DIMACS/Coloring/Market, 11 TSPLIB95), 100% of all 224 Rudy random graphs (up to n=35,960), and all 531 Culberson and NetworkX random graphs with m <= 250,000. The remaining 394 ultra-dense synthetic instances (5 duplicate g0* Palubeckis copies and 389 NetworkX/Culberson graphs with m > 250,000, totaling 1.11B edges) are cataloged as deferred dense synthetic instances.",
        "qplib_overlap"                 => MQLIB_QPLIB_OVERLAP,
        "palubeckis_deferred_inventory" => [
            Dict{String,Any}(
                "name"                     => item.name,
                "graphname"                => item.graphname,
                "source"                   => "Palubeckis",
                "problem"                  => "QUBO",
                "n"                        => item.n,
                "m"                        => item.m,
                "s3_url"                   => "$(MQLIB_S3_BASE_URL)/$(item.graphname)",
                "best_heuristic_objective" => item.best_objective,
                "best_heuristic"           => item.best_heuristic,
                "seed"                     => item.seed,
                "disposition"              => "deferred_ultra_dense_synthetic",
            ) for item in MQLIB_PALUBECKIS_DEFERRED
        ],
    ),
)

function QUBOTools.read_model(path::AbstractString, fmt::Format{:mqlib_maxcut})
    return open(path, "r") do io
        QUBOTools.read_model(io, fmt)
    end
end

function QUBOTools.read_model(path::AbstractString, fmt::Format{:mqlib_qubo_maxcut})
    return open(path, "r") do io
        QUBOTools.read_model(io, fmt)
    end
end

function QUBOTools.read_model(path::AbstractString, fmt::Format{:mqlib_qubo})
    return open(path, "r") do io
        QUBOTools.read_model(io, fmt)
    end
end

function QUBOTools.read_model(io::IO, ::Format{:mqlib_maxcut})
    return _read_mqlib_edge_list(io; mode = :maxcut)
end

function QUBOTools.read_model(io::IO, ::Format{:mqlib_qubo_maxcut})
    return _read_mqlib_edge_list(io; mode = :qubo_master_node)
end

function QUBOTools.read_model(io::IO, ::Format{:mqlib_qubo})
    return _read_mqlib_edge_list(io; mode = :qubo_direct)
end

function _read_mqlib_edge_list(io::IO; mode::Symbol)
    n_header = 0
    m_header = 0
    n_final  = 0
    header_parsed = false
    L_vec = Float64[]
    qi = Int[]
    qj = Int[]
    qv = Float64[]

    for raw_line in eachline(io)
        line = strip(raw_line)
        (isempty(line) || startswith(line, '#')) && continue
        parts = split(line)
        if !header_parsed
            length(parts) >= 2 || QUBOTools.syntax_error("Invalid MQLib header line: '$line'")
            n_parsed = tryparse(Int, parts[1])
            m_parsed = tryparse(Int, parts[2])
            (isnothing(n_parsed) || isnothing(m_parsed)) &&
                QUBOTools.syntax_error("Invalid MQLib dimension in header: '$line'")
            n_header = n_parsed
            m_header = max(0, m_parsed)
            n_final = (mode == :qubo_master_node) ? (n_header - 1) : n_header
            n_final >= 0 || QUBOTools.syntax_error("Invalid MQLib final dimension: $n_final")
            L_vec = zeros(Float64, n_final)
            sizehint!(qi, m_header)
            sizehint!(qj, m_header)
            sizehint!(qv, m_header)
            header_parsed = true
            continue
        end

        length(parts) == 3 || QUBOTools.syntax_error("Invalid MQLib edge line: '$line'")
        u = tryparse(Int, parts[1])
        v = tryparse(Int, parts[2])
        w = tryparse(Float64, parts[3])
        (isnothing(u) || isnothing(v) || isnothing(w)) &&
            QUBOTools.syntax_error("Invalid MQLib edge entry: '$line'")

        if mode == :maxcut
            (1 <= u <= n_header && 1 <= v <= n_header) ||
                QUBOTools.syntax_error("MQLib Max-Cut vertex out of range 1..$n_header: ($u, $v)")
            u == v && continue
            i, j = minmax(u, v)
            L_vec[i] += w
            L_vec[j] += w
            push!(qi, i)
            push!(qj, j)
            push!(qv, -2.0 * w)
        elseif mode == :qubo_master_node
            (1 <= u <= n_header && 1 <= v <= n_header) ||
                QUBOTools.syntax_error("MQLib QUBO-MaxCut vertex out of range 1..$n_header: ($u, $v)")
            u == v && continue
            if u == n_header || v == n_header
                idx = (u == n_header) ? v : u
                L_vec[idx] += w
            else
                i, j = minmax(u, v)
                L_vec[i] += w
                L_vec[j] += w
                push!(qi, i)
                push!(qj, j)
                push!(qv, -2.0 * w)
            end
        elseif mode == :qubo_direct
            (1 <= u <= n_header && 1 <= v <= n_header) ||
                QUBOTools.syntax_error("MQLib QUBO vertex out of range 1..$n_header: ($u, $v)")
            if u == v
                L_vec[u] += w
            else
                i, j = minmax(u, v)
                push!(qi, i)
                push!(qj, j)
                push!(qv, 2.0 * w)
            end
        else
            error("Unsupported MQLib mode: $mode")
        end
    end

    header_parsed || QUBOTools.syntax_error("Empty MQLib input")

    li = Int[]
    lv = Float64[]
    for idx in 1:n_final
        val = L_vec[idx]
        if abs(val) > 1e-12
            push!(li, idx)
            push!(lv, val)
        end
    end

    L_sp = QUBOTools.SparseArrays.sparsevec(li, lv, n_final)
    Q_sp = QUBOTools.SparseArrays.sparse(qi, qj, qv, n_final, n_final)
    for k in eachindex(Q_sp.nzval)
        if abs(Q_sp.nzval[k]) <= 1e-12
            Q_sp.nzval[k] = 0.0
        end
    end
    QUBOTools.SparseArrays.dropzeros!(L_sp)
    QUBOTools.SparseArrays.dropzeros!(Q_sp)

    L_form = QUBOTools.SparseLinearForm(L_sp)
    Q_form = QUBOTools.SparseQuadraticForm(Q_sp)
    form   = QUBOTools.Form{Float64}(
        n_final,
        L_form,
        Q_form,
        1.0,
        0.0;
        sense  = QUBOTools.sense(:max),
        domain = QUBOTools.domain(:bool),
    )
    vmap = QUBOTools.VariableMap{Int}(collect(1:n_final))

    return QUBOTools.Model{Int,Float64,Int}(vmap, form)
end

function _read_mqlib_solution(
    path::AbstractString,
    model::QUBOTools.Model{Int,Float64,Int},
)
    return open(path, "r") do io
        _read_mqlib_solution!(io, model)
    end
end

function _read_mqlib_solution!(
    io::IO,
    model::QUBOTools.Model{Int,Float64,Int},
)
    n = QUBOTools.dimension(model)
    header_meta = Dict{String,String}()
    bit_lines = String[]

    for raw_line in eachline(io)
        line = strip(raw_line)
        isempty(line) && continue
        if startswith(line, '#')
            for token in split(strip(line[2:end]))
                kv = split(token, '='; limit = 2)
                length(kv) == 2 && (header_meta[String(kv[1])] = String(kv[2]))
            end
        else
            push!(bit_lines, line)
        end
    end

    length(bit_lines) == 1 || QUBOTools.syntax_error("Expected single bitstring line in MQLib .sol file")
    bitstr = bit_lines[1]
    ncodeunits(bitstr) == n ||
        QUBOTools.syntax_error("MQLib solution bitstring length $(ncodeunits(bitstr)) != model dimension $n")

    ψ = Vector{Int}(undef, n)
    for i in 1:n
        c = codeunit(bitstr, i)
        if c == UInt8('0')
            ψ[i] = 0
        elseif c == UInt8('1')
            ψ[i] = 1
        else
            QUBOTools.syntax_error("Invalid character in MQLib solution bitstring: '$(Char(c))'")
        end
    end

    eval_val = Float64(QUBOTools.value(model, ψ))
    heur = get(header_meta, "heuristic", "MQLib")
    solver_code = startswith(heur, "MQLib::") ? heur : "MQLib::$(heur)"
    rep_obj = haskey(header_meta, "objective") ? tryparse(Float64, header_meta["objective"]) : eval_val
    seed = haskey(header_meta, "seed") ? tryparse(Int, header_meta["seed"]) : nothing
    rt = haskey(header_meta, "runtime") ? tryparse(Float64, header_meta["runtime"]) : nothing
    paper_best = haskey(header_meta, "paper_best") ? tryparse(Float64, header_meta["paper_best"]) : nothing

    meta = Dict{String,Any}(
        "origin"           => "MQLib",
        "solver"           => solver_code,
        "heuristic"        => heur,
        "source_objective" => isnothing(rep_obj) ? eval_val : rep_obj,
        "qubo_value"       => eval_val,
    )
    !isnothing(seed) && (meta["seed"] = seed)
    !isnothing(rt) && (meta["runtime_s"] = rt)
    !isnothing(paper_best) && (meta["paper_best_objective"] = paper_best)

    samples = QUBOTools.Sample{Float64,Int}[QUBOTools.Sample{Float64,Int}(ψ, eval_val)]
    return QUBOTools.SampleSet{Float64,Int}(
        samples,
        meta;
        sense  = QUBOTools.sense(model),
        domain = :bool,
    )
end

function _mqlib_problem_class(problem::AbstractString, source::AbstractString)
    if problem == "MAX-CUT"
        if source == "G-set"
            return "Max-Cut (Stanford G-set)"
        elseif source == "spin-glass"
            return "Max-Cut (Spin-Glass)"
        elseif source == "torus"
            return "Max-Cut (DIMACS Torus)"
        elseif source == "SteinLib"
            return "Max-Cut (SteinLib Steiner Tree)"
        elseif source == "BiqMac"
            return "Max-Cut (BiqMac Library)"
        elseif source == "OR-Library"
            return "Max-Cut (OR-Library BQP/GKA Graph)"
        elseif source == "ImageSegmentation" || source == "ImageSeg"
            return "Max-Cut (Berkeley Image Segmentation)"
        elseif source == "Culberson"
            return "Max-Cut (Culberson Quasi-Random Coloring)"
        elseif source == "Rudy"
            return "Max-Cut (Rudy Random Graph)"
        elseif source == "NetworkX"
            return "Max-Cut (NetworkX Random Graph)"
        elseif source == "TSPLIB95"
            return "Max-Cut (TSPLIB95)"
        elseif source == "StanfordGraphBase"
            return "Max-Cut (Stanford GraphBase)"
        elseif source == "MarketGraphs"
            return "Max-Cut (Boginski Market Graph)"
        elseif source == "GlasgowIsomorphism"
            return "Max-Cut (Glasgow Graph Isomorphism)"
        elseif source == "Dharwadker"
            return "Max-Cut (Dharwadker Benchmark Graph)"
        elseif source == "DIMACS"
            return "Max-Cut (DIMACS Graph)"
        else
            return "Max-Cut ($(source))"
        end
    else
        if source == "Beasley"
            return "Binary Quadratic Programming (Beasley OR-Library)"
        elseif source == "GKA"
            return "Binary Quadratic Programming (Glover-Kochenberger-Alidaee)"
        elseif source == "Palubeckis"
            return "Binary Quadratic Programming (Palubeckis)"
        else
            return "Binary Quadratic Programming ($(source))"
        end
    end
end

function _parse_mqlib_csv(path::AbstractString)
    rows = Dict{String,String}[]
    open(path, "r") do io
        header_line = strip(readline(io))
        headers = String.(split(header_line, ','))
        for raw_line in eachline(io)
            line = strip(raw_line)
            isempty(line) && continue
            vals = String.(split(line, ','; keepempty = true))
            length(vals) == length(headers) ||
                error("[mqlib] CSV column count mismatch in '$path': '$line'")
            push!(rows, Dict{String,String}(headers[i] => vals[i] for i in eachindex(headers)))
        end
    end
    return rows
end

function load_mqlib!(
    index::QUBOLib.LibraryIndex;
    root::Union{Nothing,AbstractString} = nothing,
)
    data_path = mkpath(QUBOLib.cache_data_path(index, MQLIB_COLLECTION))

    if !isnothing(root)
        for fname in readdir(root)
            src = joinpath(root, fname)
            isfile(src) && cp(src, joinpath(data_path, fname); force = true)
        end
    elseif !isfile(joinpath(data_path, "standard.csv"))
        cache_dir = mkpath(QUBOLib.cache_path(index, MQLIB_COLLECTION))
        zip_path = joinpath(cache_dir, "mqlib.zip")
        if !isfile(zip_path)
            @info "[mqlib] Downloading mirror archive from $(MQLIB_MIRROR_URL)"
            Downloads.download(MQLIB_MIRROR_URL, zip_path)
        end
        run(`unzip -qq -o $zip_path -d $data_path`)
    end

    std_rows = _parse_mqlib_csv(joinpath(data_path, "standard.csv"))
    selected = filter(
        r -> r["source"] != "Palubeckis" || r["graphname"] == "p3000_1.zip",
        std_rows,
    )
    tier2_path = joinpath(data_path, "catalog_tier2.csv")
    if isfile(tier2_path)
        append!(selected, _parse_mqlib_csv(tier2_path))
    end
    append!(
        selected,
        filter(
            r -> r["source"] == "Palubeckis" && r["graphname"] != "p3000_1.zip",
            std_rows,
        ),
    )
    return selected
end

function build_mqlib!(
    index::QUBOLib.LibraryIndex;
    cache::Bool = true,
    root::Union{Nothing,AbstractString} = nothing,
)
    if QUBOLib.has_collection(index, MQLIB_COLLECTION)
        @info "[mqlib] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, MQLIB_COLLECTION)
        end
    end

    @info "[mqlib] Building MQLib collection"

    QUBOLib.add_collection!(index, MQLIB_COLLECTION, MQLIB_DATA)
    selected = load_mqlib!(index; root)
    data_path = QUBOLib.cache_data_path(index, MQLIB_COLLECTION)

    # Register 38 MQLib heuristic solvers and submissions
    heuristic_submissions = Dict{String,Int}()
    for heur in sort(collect(keys(MQLIB_HEURISTICS)))
        hinfo = MQLIB_HEURISTICS[heur]
        solver_name = "MQLib::$(heur)"
        if !QUBOLib.has_solver(index, solver_name)
            QUBOLib.add_solver!(
                index,
                solver_name,
                Dict(
                    "version"     => MQLIB_SOURCE_COMMIT[1:7],
                    "description" => hinfo.description,
                ),
            )
        end
        sub_id = QUBOLib.add_submission!(
            index;
            submitter         = "Iain Dunning, Swati Gupta, and John Silberholz (MQLib 2018)",
            date              = "2016-07-10",
            reference         = "https://doi.org/$(MQLIB_CITATION_DOI)",
            modeling_approach = hinfo.domain == "MAX-CUT" ? "Max-Cut heuristic" : "QUBO heuristic",
            workflow          = solver_name,
            algorithm_type    = hinfo.description,
            runs              = 5,
            feasible_runs     = 5,
            hardware          = "Amazon EC2 m3.medium (Intel Xeon E5-2670 v2, single core)",
            remarks           = "MQLib systematic evaluation across 38 heuristics (5 random seeds per instance)",
            source_path       = heur == "DESOUSA2013" ? "data/results_imgseg.zip!results_imgseg.csv" : "data/results.zip!results.csv",
            metadata          = Dict{String,Any}(
                "heuristic_code"    => heur,
                "native_domain"     => hinfo.domain,
                "source_repository" => MQLIB_REPOSITORY,
                "source_commit"     => MQLIB_SOURCE_COMMIT,
            ),
        )
        heuristic_submissions[heur] = sub_id
    end

    # Parse metrics_standard.csv and results_standard.csv if available
    metrics_by_graph = Dict{String,Dict{String,Any}}()
    metrics_path = joinpath(data_path, "metrics_standard.csv")
    if isfile(metrics_path)
        for row in _parse_mqlib_csv(metrics_path)
            g = row["graphname"]
            m_dict = Dict{String,Any}()
            for (k, v) in row
                k == "graphname" && continue
                parsed = tryparse(Float64, v)
                m_dict[k] = isnothing(parsed) ? v : parsed
            end
            metrics_by_graph[g] = m_dict
        end
    end

    results_by_graph = Dict{String,Dict{String,Dict{String,Any}}}()
    best_result_by_graph = Dict{String,NamedTuple{(:heuristic, :objective, :seed, :limit, :timestamp),Tuple{String,Float64,Int,Float64,String}}}()
    results_path = joinpath(data_path, "results_standard.csv")
    if isfile(results_path)
        for row in _parse_mqlib_csv(results_path)
            g = row["graphname"]
            h = row["heuristic"]
            obj = parse(Float64, row["best_objective"])
            seed = parse(Int, row["seed"])
            limit = parse(Float64, row["limit"])
            ts = row["timestamp"]
            g_dict = get!(results_by_graph, g, Dict{String,Dict{String,Any}}())
            g_dict[h] = Dict{String,Any}(
                "best_objective" => obj,
                "seed"           => seed,
                "limit_s"        => limit,
                "timestamp"      => ts,
            )
            if !haskey(best_result_by_graph, g) || obj > best_result_by_graph[g].objective
                best_result_by_graph[g] = (heuristic = h, objective = obj, seed = seed, limit = limit, timestamp = ts)
            end
        end
    end

    for row in selected
        graphname = row["graphname"]
        base = endswith(graphname, ".zip") ? graphname[1:(end - 4)] : graphname
        source_family = row["source"]
        problem = row["problem"]
        opt_str = strip(get(row, "optimal", ""))
        opt_source = strip(get(row, "optimalSource", ""))
        has_proven_opt = !isempty(opt_str)
        opt_val = has_proven_opt ? parse(Float64, opt_str) : nothing

        txt_path = joinpath(data_path, "$(base).txt")
        zip_inst_path = joinpath(data_path, graphname)
        fmt = problem == "MAX-CUT" ? Format(:mqlib_maxcut) : Format(:mqlib_qubo_maxcut)
        model = if isfile(txt_path)
            QUBOTools.read_model(txt_path, fmt)
        elseif isfile(zip_inst_path)
            open(`unzip -p $zip_inst_path`, "r") do io
                QUBOTools.read_model(io, fmt)
            end
        else
            continue
        end

        paper_best_info = get(best_result_by_graph, graphname, nothing)
        primal_bound = !isnothing(opt_val) ? opt_val : (!isnothing(paper_best_info) ? paper_best_info.objective : nothing)

        inst_meta = Dict{String,Any}(
            "family"          => source_family,
            "mqlib_problem"   => problem,
            "mqlib_graphname" => graphname,
            "mqlib_tier"      => haskey(row, "optimal") ? "standard" : "tier2",
            "proven_optimal"  => has_proven_opt,
        )
        comment_str = strip(get(row, "comment", ""))
        !isempty(comment_str) && (inst_meta["header_comment"] = comment_str)
        !isnothing(primal_bound) && (inst_meta["upstream_primal_bound"] = primal_bound)
        if has_proven_opt
            inst_meta["dual_bound"] = opt_val
            inst_meta["optimal_source"] = opt_source
        end
        if !isnothing(paper_best_info)
            inst_meta["paper_best_objective"] = paper_best_info.objective
            inst_meta["paper_best_heuristic"] = paper_best_info.heuristic
            inst_meta["paper_best_seed"] = paper_best_info.seed
        end
        if haskey(MQLIB_QPLIB_OVERLAP, base)
            inst_meta["qplib_equivalent"] = MQLIB_QPLIB_OVERLAP[base]
        end
        if haskey(metrics_by_graph, graphname)
            inst_meta["mqlib_metrics"] = metrics_by_graph[graphname]
        end
        if haskey(results_by_graph, graphname)
            inst_meta["mqlib_heuristic_benchmarks"] = results_by_graph[graphname]
        end

        mod_i = QUBOLib.add_instance!(
            index,
            model,
            MQLIB_COLLECTION;
            name              = "$(base).txt",
            source_name       = base,
            problem_class     = _mqlib_problem_class(problem, source_family),
            formulation       = problem == "MAX-CUT" ? "maxcut_edge_list" : "qubo_master_node_edge_list",
            source_path       = graphname,
            source_commit     = MQLIB_SOURCE_COMMIT,
            original_filename = graphname,
            source_url        = "$(MQLIB_S3_BASE_URL)/$(graphname)",
            metadata          = inst_meta,
        )

        sol_path = joinpath(data_path, "$(base).sol")
        if isfile(sol_path)
            sol = _read_mqlib_solution(sol_path, model)
            eval_val = Float64(QUBOTools.value(sol, 1))
            sol_meta = QUBOTools.metadata(sol)
            src_obj = Float64(get(sol_meta, "source_objective", eval_val))
            heur = String(get(sol_meta, "heuristic", ""))
            sub_id = get(heuristic_submissions, heur, nothing)
            is_opt = has_proven_opt && isapprox(eval_val, opt_val; atol = 1e-6)

            QUBOLib.add_solution!(
                index,
                mod_i,
                sol;
                submission         = sub_id,
                qubo_value         = eval_val,
                source_value       = src_obj,
                source_objective   = src_obj,
                objective_bound    = has_proven_opt ? opt_val : primal_bound,
                dual_bound         = has_proven_opt ? opt_val : nothing,
                source_feasible    = true,
                proven_optimal     = is_opt,
                feasibility_status = "feasible",
                validation_status  = isapprox(eval_val, src_obj; atol = 1e-6) ? "validated" : "evaluated",
                incumbent_candidate = true,
                source_path        = "$(base).sol",
            )

            # If the 20-minute paper benchmark in results.zip achieved a strictly higher value
            # than the bitstring run, also record the paper benchmark as a value-only submission record
            if !isnothing(paper_best_info) && paper_best_info.objective > eval_val + 1e-6
                p_sub_id = get(heuristic_submissions, paper_best_info.heuristic, nothing)
                p_is_opt = has_proven_opt && isapprox(paper_best_info.objective, opt_val; atol = 1e-6)
                QUBOLib.add_solution_record!(
                    index,
                    mod_i;
                    submission          = p_sub_id,
                    qubo_value          = paper_best_info.objective,
                    source_value        = paper_best_info.objective,
                    source_objective    = paper_best_info.objective,
                    objective_bound     = has_proven_opt ? opt_val : paper_best_info.objective,
                    dual_bound          = has_proven_opt ? opt_val : nothing,
                    source_feasible     = true,
                    proven_optimal      = p_is_opt,
                    feasibility_status  = "unavailable",
                    validation_status   = "unavailable",
                    incumbent_candidate = false,
                    source_path         = startswith(base, "imgseg_") ? "data/results_imgseg.zip!results_imgseg.csv" : "data/results.zip!results.csv",
                    metadata            = Dict{String,Any}(
                        "origin"         => "MQLib",
                        "heuristic"      => paper_best_info.heuristic,
                        "seed"           => paper_best_info.seed,
                        "limit_s"        => paper_best_info.limit,
                        "timestamp"      => paper_best_info.timestamp,
                        "reason"         => "value_only_benchmark_record",
                    ),
                )
            end
        elseif !isnothing(paper_best_info)
            p_sub_id = get(heuristic_submissions, paper_best_info.heuristic, nothing)
            p_is_opt = has_proven_opt && isapprox(paper_best_info.objective, opt_val; atol = 1e-6)
            QUBOLib.add_solution_record!(
                index,
                mod_i;
                submission          = p_sub_id,
                qubo_value          = paper_best_info.objective,
                source_value        = paper_best_info.objective,
                source_objective    = paper_best_info.objective,
                objective_bound     = has_proven_opt ? opt_val : paper_best_info.objective,
                dual_bound          = has_proven_opt ? opt_val : nothing,
                source_feasible     = true,
                proven_optimal      = p_is_opt,
                feasibility_status  = "unavailable",
                validation_status   = "unavailable",
                incumbent_candidate = false,
                source_path         = startswith(base, "imgseg_") ? "data/results_imgseg.zip!results_imgseg.csv" : "data/results.zip!results.csv",
                metadata            = Dict{String,Any}(
                    "origin"         => "MQLib",
                    "heuristic"      => paper_best_info.heuristic,
                    "seed"           => paper_best_info.seed,
                    "limit_s"        => paper_best_info.limit,
                    "timestamp"      => paper_best_info.timestamp,
                    "reason"         => "value_only_benchmark_record",
                ),
            )
        end
    end

    return nothing
end

function deploy_mqlib!(index::QUBOLib.LibraryIndex)
    close(index)

    src_path = QUBOLib.cache_data_path(index, MQLIB_COLLECTION)
    dst_path = mkpath(joinpath(QUBOLib.build_path(index), "mirror"))
    zip_path = joinpath(dst_path, "mqlib.zip")

    run(`zip -q -1 -n .zip -j -r $zip_path $src_path`)

    return nothing
end
