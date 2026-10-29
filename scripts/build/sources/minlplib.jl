const MINLPLIB_SOURCE_URL = "https://www.minlplib.org/"
const MINLPLIB_SOURCE_COMMIT = "9472b011"
const MINLPLIB_CITATION = """
@article{Bussieck2003MINLPLib,
  title={MINLPLib---a collection of test models for mixed-integer nonlinear programming},
  author={Bussieck, Michael R. and Drud, Arne Stolbjerg and Meeraus, Alexander},
  journal={INFORMS Journal on Computing},
  volume={15},
  number={1},
  pages={114--119},
  year={2003},
  doi={10.1287/ijoc.15.1.114.15159},
}
"""

const MINLPLIB_QPLIB_OVERLAP = [
    (minlplib_name = "sporttournament22", qplib_code = "QPLIB_3852", dimension = 231, sense = :max, primal_bound = 234.0, dual_bound = 234.0, proven_optimal = true),
    (minlplib_name = "sporttournament24", qplib_code = "QPLIB_3565", dimension = 276, sense = :max, primal_bound = 282.0, dual_bound = 282.0, proven_optimal = true),
    (minlplib_name = "sporttournament26", qplib_code = "QPLIB_3745", dimension = 325, sense = :max, primal_bound = 334.0, dual_bound = 334.0, proven_optimal = true),
    (minlplib_name = "sporttournament28", qplib_code = "QPLIB_3705", dimension = 378, sense = :max, primal_bound = 384.0, dual_bound = 384.0, proven_optimal = true),
    (minlplib_name = "sporttournament30", qplib_code = "QPLIB_3738", dimension = 435, sense = :max, primal_bound = 422.0, dual_bound = 425.0489482, proven_optimal = false),
    (minlplib_name = "sporttournament32", qplib_code = "QPLIB_3506", dimension = 496, sense = :max, primal_bound = 478.0, dual_bound = 484.0, proven_optimal = false),
    (minlplib_name = "sporttournament34", qplib_code = "QPLIB_3832", dimension = 561, sense = :max, primal_bound = 554.0, dual_bound = 563.0, proven_optimal = false),
    (minlplib_name = "sporttournament36", qplib_code = "QPLIB_3877", dimension = 630, sense = :max, primal_bound = 602.0, dual_bound = 611.5425502, proven_optimal = false),
    (minlplib_name = "sporttournament38", qplib_code = "QPLIB_3706", dimension = 703, sense = :max, primal_bound = 682.0, dual_bound = 699.029604, proven_optimal = false),
    (minlplib_name = "sporttournament40", qplib_code = "QPLIB_3838", dimension = 780, sense = :max, primal_bound = 746.0, dual_bound = 775.0633203, proven_optimal = false),
    (minlplib_name = "sporttournament42", qplib_code = "QPLIB_3822", dimension = 861, sense = :max, primal_bound = 850.0, dual_bound = 878.5122339, proven_optimal = false),
    (minlplib_name = "sporttournament44", qplib_code = "QPLIB_3650", dimension = 946, sense = :max, primal_bound = 922.0, dual_bound = 956.3308189, proven_optimal = false),
    (minlplib_name = "sporttournament46", qplib_code = "QPLIB_3642", dimension = 1035, sense = :max, primal_bound = 1034.0, dual_bound = 1070.944598, proven_optimal = false),
    (minlplib_name = "sporttournament48", qplib_code = "QPLIB_3693", dimension = 1128, sense = :max, primal_bound = 1154.0, dual_bound = 1200.414098, proven_optimal = false),
    (minlplib_name = "sporttournament50", qplib_code = "QPLIB_3850", dimension = 1225, sense = :max, primal_bound = 1198.0, dual_bound = 1249.748958, proven_optimal = false),
    (minlplib_name = "ising2_5-300_5555", qplib_code = "QPLIB_5721", dimension = 300, sense = :max, primal_bound = 8579363.0, dual_bound = 8656028.328, proven_optimal = false),
    (minlplib_name = "toroidal3g7_6666", qplib_code = "QPLIB_5725", dimension = 343, sense = :max, primal_bound = 33611981.0, dual_bound = 33611981.0, proven_optimal = true),
    (minlplib_name = "toroidal2g20_5555", qplib_code = "QPLIB_5755", dimension = 400, sense = :max, primal_bound = 24838942.0, dual_bound = 24838942.0, proven_optimal = true),
]

const MINLPLIB_QUBO_INSTANCES = [
    (name = "autocorr_bern20-03", family = "autocorr_bern", formulation = "mbqcp_epigraph", dimension = 20, sense = :min, primal_bound = -72.0, dual_bound = -72.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "autocorr_bern25-03", family = "autocorr_bern", formulation = "mbqcp_epigraph", dimension = 25, sense = :min, primal_bound = -92.0, dual_bound = -92.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "chimera_k64ising-01", family = "chimera", formulation = "bqp_direct", dimension = 1192, sense = :max, primal_bound = 24.3, dual_bound = 24.3, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "chimera_k64ising-02", family = "chimera", formulation = "bqp_direct", dimension = 1225, sense = :max, primal_bound = 24.3, dual_bound = 24.3, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "chimera_k64maxcut-01", family = "chimera", formulation = "bqp_direct", dimension = 1101, sense = :max, primal_bound = 23.6, dual_bound = 23.6, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "chimera_k64maxcut-02", family = "chimera", formulation = "bqp_direct", dimension = 1145, sense = :max, primal_bound = 23.6, dual_bound = 23.6, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "chimera_lga-01", family = "chimera", formulation = "bqp_direct", dimension = 1120, sense = :max, primal_bound = 143.5, dual_bound = 143.5, gap = 0.0, proven_optimal = true, best_point = "p3", points = ["p3", "p2", "p1"]),
    (name = "chimera_lga-02", family = "chimera", formulation = "bqp_direct", dimension = 964, sense = :max, primal_bound = 132.3, dual_bound = 133.3888889, gap = 0.008230452758881334, proven_optimal = false, best_point = "p1", points = ["p1"]),
    (name = "chimera_mgw-c16-2031-01", family = "chimera", formulation = "bqp_direct", dimension = 2032, sense = :max, primal_bound = 2006.0, dual_bound = 2159.0, gap = 0.07627118644067797, proven_optimal = false, best_point = "p5", points = ["p5", "p4", "p3", "p2", "p1"]),
    (name = "chimera_mgw-c16-2031-02", family = "chimera", formulation = "bqp_direct", dimension = 2032, sense = :max, primal_bound = 2004.0, dual_bound = 2168.0, gap = 0.08183632734530938, proven_optimal = false, best_point = "p4", points = ["p4", "p3", "p2", "p1"]),
    (name = "chimera_mgw-c8-439-onc8-001", family = "chimera", formulation = "bqp_direct", dimension = 440, sense = :max, primal_bound = 405.0, dual_bound = 405.0, gap = 0.0, proven_optimal = true, best_point = "p2", points = ["p2", "p1"]),
    (name = "chimera_mgw-c8-439-onc8-002", family = "chimera", formulation = "bqp_direct", dimension = 440, sense = :max, primal_bound = 397.0, dual_bound = 397.0, gap = 0.0, proven_optimal = true, best_point = "p2", points = ["p2", "p1"]),
    (name = "chimera_mgw-c8-507-onc8-01", family = "chimera", formulation = "bqp_direct", dimension = 508, sense = :max, primal_bound = 493.0, dual_bound = 507.7941037, gap = 0.030008323935091265, proven_optimal = false, best_point = "p3", points = ["p3", "p2", "p1"]),
    (name = "chimera_mgw-c8-507-onc8-02", family = "chimera", formulation = "bqp_direct", dimension = 508, sense = :max, primal_bound = 495.0, dual_bound = 507.2484318, gap = 0.02474430666666665, proven_optimal = false, best_point = "p3", points = ["p3", "p2", "p1"]),
    (name = "chimera_mis-01", family = "chimera", formulation = "bqp_direct", dimension = 2032, sense = :max, primal_bound = 389.4, dual_bound = 389.4, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "chimera_mis-02", family = "chimera", formulation = "bqp_direct", dimension = 2032, sense = :max, primal_bound = 398.6, dual_bound = 398.6, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "chimera_rfr-01", family = "chimera", formulation = "bqp_direct", dimension = 2032, sense = :max, primal_bound = 1215.8, dual_bound = 1257.1, gap = 0.03396940286231284, proven_optimal = false, best_point = "p4", points = ["p4", "p3", "p2", "p1"]),
    (name = "chimera_rfr-02", family = "chimera", formulation = "bqp_direct", dimension = 2032, sense = :max, primal_bound = 1180.0, dual_bound = 1216.4, gap = 0.03084745762711872, proven_optimal = false, best_point = "p4", points = ["p4", "p3", "p2", "p1"]),
    (name = "chimera_selby-c16-01", family = "chimera", formulation = "bqp_direct", dimension = 2031, sense = :max, primal_bound = 746.4, dual_bound = 800.5, gap = 0.07248124330117903, proven_optimal = false, best_point = "p8", points = ["p8", "p7", "p6", "p5", "p4", "p3", "p2", "p1"]),
    (name = "chimera_selby-c16-02", family = "chimera", formulation = "bqp_direct", dimension = 2031, sense = :max, primal_bound = 743.9, dual_bound = 802.7, gap = 0.07904288210781028, proven_optimal = false, best_point = "p5", points = ["p5", "p4", "p3", "p2", "p1"]),
    (name = "chimera_selby-c8-onc8-01", family = "chimera", formulation = "bqp_direct", dimension = 507, sense = :max, primal_bound = 178.9, dual_bound = 183.6, gap = 0.026271660145332523, proven_optimal = false, best_point = "p4", points = ["p4", "p3", "p2", "p1"]),
    (name = "chimera_selby-c8-onc8-02", family = "chimera", formulation = "bqp_direct", dimension = 507, sense = :max, primal_bound = 169.7, dual_bound = 173.1, gap = 0.020035356511490902, proven_optimal = false, best_point = "p5", points = ["p5", "p4", "p3", "p2", "p1"]),
    (name = "sporttournament06", family = "sporttournament", formulation = "mbqcp_epigraph", dimension = 15, sense = :max, primal_bound = 12.0, dual_bound = 12.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "sporttournament08", family = "sporttournament", formulation = "mbqcp_epigraph", dimension = 28, sense = :max, primal_bound = 24.0, dual_bound = 24.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "sporttournament10", family = "sporttournament", formulation = "mbqcp_epigraph", dimension = 45, sense = :max, primal_bound = 44.0, dual_bound = 44.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "sporttournament12", family = "sporttournament", formulation = "mbqcp_epigraph", dimension = 66, sense = :max, primal_bound = 68.0, dual_bound = 68.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "sporttournament16", family = "sporttournament", formulation = "mbqcp_epigraph", dimension = 120, sense = :max, primal_bound = 130.0, dual_bound = 130.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "sporttournament18", family = "sporttournament", formulation = "mbqcp_epigraph", dimension = 153, sense = :max, primal_bound = 160.0, dual_bound = 160.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
    (name = "sporttournament20", family = "sporttournament", formulation = "mbqcp_epigraph", dimension = 190, sense = :max, primal_bound = 192.0, dual_bound = 192.0, gap = 0.0, proven_optimal = true, best_point = "p1", points = ["p1"]),
]

const MINLPLIB_INSTANCE_METADATA = Dict{String,NamedTuple}(
    row.name => row for row in MINLPLIB_QUBO_INSTANCES
)

const MINLPLIB_DATA = Dict{String,Any}(
    "name"         => "MINLPLib",
    "author"       => [
        "Michael R. Bussieck",
        "Arne Stolbjerg Drud",
        "Alexander Meeraus",
        "Stefan Vigerske",
    ],
    "description"  => "Mixed-Integer and Continuous Nonlinear Programming Library (Unconstrained Binary Quadratic Subset)",
    "year"         => 2003,
    "url"          => MINLPLIB_SOURCE_URL,
    "data_license" => "CC-BY-4.0",
    "citation"     => MINLPLIB_CITATION,
    "metadata"     => Dict{String,Any}(
        "source_name"           => "MINLPLib",
        "source_url"            => MINLPLIB_SOURCE_URL,
        "source_commit"         => MINLPLIB_SOURCE_COMMIT,
        "citation_doi"          => "10.1287/ijoc.15.1.114.15159",
        "license_evidence_url"  => MINLPLIB_SOURCE_URL,
        "provenance_status"     => "verified",
        "rights_status"         => "verified",
        "qplib_overlap_count"   => length(MINLPLIB_QPLIB_OVERLAP),
        "imported_qubo_count"   => length(MINLPLIB_QUBO_INSTANCES),
        "transformation_note"   => "QUBOLib selects the 29 pure binary unconstrained QUBO instances in MINLPLib not already included in QPLIB (2 autocorr_bern, 20 chimera, and 7 sporttournament06..20 instances; sporttournament14 is excluded because 70 of its 91 variables are continuous in MINLPLib), parses POLIP (.pip) models and .p*.sol solution records, factors exact 0.1 scaling where applicable, and stores the results in HDF5 and SQLite.",
    ),
)

function _parse_minlplib_pip_expr(expr_str::AbstractString)
    s = strip(replace(expr_str, r"\s+" => " "))
    if !startswith(s, "+") && !startswith(s, "-")
        s = "+ " * s
    end
    tokens = split(s, r"(?<![eE])(?=[+-])"; keepempty = false)
    L = Dict{String,Float64}()
    Q = Dict{Tuple{String,String},Float64}()
    offset = 0.0

    for tok in tokens
        tok = strip(tok)
        isempty(tok) && continue
        sign = startswith(tok, "-") ? -1.0 : 1.0
        body = strip(tok[2:end])
        isempty(body) && continue
        parts = split(body)
        val = tryparse(Float64, parts[1])
        if !isnothing(val)
            coef = sign * val
            vars_part = filter(!=("*"), parts[2:end])
        else
            coef = sign * 1.0
            vars_part = filter(!=("*"), parts)
        end

        if isempty(vars_part)
            offset += coef
        elseif length(vars_part) == 1
            v = replace(vars_part[1], "^2" => "")
            L[v] = get(L, v, 0.0) + coef
        elseif length(vars_part) == 2
            v1, v2 = vars_part[1], vars_part[2]
            if v1 == v2
                L[v1] = get(L, v1, 0.0) + coef
            else
                (startswith(v1, "b") && startswith(v2, "b")) ||
                    QUBOTools.syntax_error("Invalid quadratic variables in PIP term: $(tok)")
                i1 = parse(Int, v1[2:end])
                i2 = parse(Int, v2[2:end])
                k = i1 < i2 ? (v1, v2) : (v2, v1)
                Q[k] = get(Q, k, 0.0) + coef
            end
        else
            QUBOTools.syntax_error("Unsupported higher-order term in PIP expression: $(tok)")
        end
    end

    return (L, Q, offset)
end

function QUBOTools.read_model(path::AbstractString, fmt::Format{:minlplib_pip})
    return open(path, "r") do io
        QUBOTools.read_model(io, fmt)
    end
end

function QUBOTools.read_model(io::IO, ::Format{:minlplib_pip})
    pip_txt = read(io, String)
    sense_m = match(r"\b(Maximize|Minimize)\b", pip_txt)
    isnothing(sense_m) && QUBOTools.syntax_error("Missing Maximize/Minimize in PIP file")
    sense = sense_m.captures[1] == "Maximize" ? :max : :min

    obj_m = match(r"(?:Maximize|Minimize)\s+obj:\s*(.*?)\s*Subject To"s, pip_txt)
    sub_m = match(r"Subject To\s*(.*?)\s*(?:Bounds|Binary)"s, pip_txt)
    bin_m = match(r"Binary\s*(.*?)\s*End"s, pip_txt)
    (isnothing(obj_m) || isnothing(sub_m) || isnothing(bin_m)) &&
        QUBOTools.syntax_error("Malformed PIP sections")

    sub_txt = strip(sub_m.captures[1])
    if !isempty(sub_txt)
        L_obj, Q_obj, off_obj = _parse_minlplib_pip_expr(obj_m.captures[1])
        has_valid_epigraph_obj =
            get(L_obj, "objvar", 0.0) == 1.0 &&
            all(iszero(v) for (k, v) in L_obj if k != "objvar") &&
            all(iszero, values(Q_obj)) &&
            iszero(off_obj)
        has_valid_epigraph_obj ||
            QUBOTools.syntax_error("Epigraph PIP objective must be +1 objvar")

        m_eq = match(r"^e1:\s*(.*?)\s*<=\s*([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)$"s, sub_txt)
        isnothing(m_eq) &&
            QUBOTools.syntax_error("Unsupported constraint in MINLPLib QUBO PIP: $(sub_txt)")
        lhs_str, rhs_str = m_eq.captures[1], m_eq.captures[2]
        L_raw, Q_raw, off_raw = _parse_minlplib_pip_expr(lhs_str)
        rhs_val = parse(Float64, rhs_str)
        haskey(L_raw, "objvar") ||
            QUBOTools.syntax_error("Missing objvar in epigraph constraint")
        c_obj = pop!(L_raw, "objvar")
        ((sense == :max && c_obj > 0) || (sense == :min && c_obj < 0)) ||
            QUBOTools.syntax_error(
                "Epigraph constraint coefficient on objvar ($c_obj) does not bound $sense objective",
            )
        scale_obj = -1.0 / c_obj
        L = Dict{Int,Float64}()
        for (k, v) in L_raw
            startswith(k, "b") || QUBOTools.syntax_error("Unexpected variable '$k' in QUBO")
            sv = round(scale_obj * v; digits = 10)
            !iszero(sv) && (L[parse(Int, k[2:end])] = sv)
        end
        Q = Dict{Tuple{Int,Int},Float64}()
        for ((k1, k2), v) in Q_raw
            sv = round(scale_obj * v; digits = 10)
            !iszero(sv) && (Q[(parse(Int, k1[2:end]), parse(Int, k2[2:end]))] = sv)
        end
        offset = round((rhs_val - off_raw) / c_obj; digits = 10)
    else
        obj_str = obj_m.captures[1]
        L_raw, Q_raw, off_raw = _parse_minlplib_pip_expr(obj_str)
        L = Dict{Int,Float64}()
        for (k, v) in L_raw
            startswith(k, "b") || QUBOTools.syntax_error("Unexpected variable '$k' in QUBO")
            sv = round(v; digits = 10)
            !iszero(sv) && (L[parse(Int, k[2:end])] = sv)
        end
        Q = Dict{Tuple{Int,Int},Float64}()
        for ((k1, k2), v) in Q_raw
            sv = round(v; digits = 10)
            !iszero(sv) && (Q[(parse(Int, k1[2:end]), parse(Int, k2[2:end]))] = sv)
        end
        offset = round(off_raw; digits = 10)
    end

    V = Set{Int}()
    for tok in split(bin_m.captures[1])
        m_bin = match(r"^b([1-9][0-9]*)$", tok)
        isnothing(m_bin) &&
            QUBOTools.syntax_error("Invalid binary variable token '$tok' in PIP Binary section")
        idx = parse(Int, m_bin.captures[1])
        push!(V, idx)
        get!(L, idx, 0.0)
    end

    (!isempty(V) && V == Set{Int}(1:length(V))) ||
        QUBOTools.syntax_error("Binary variable indices in PIP must be contiguous 1..n")
    (all(i -> i in V, keys(L)) && all(((i, j),) -> (i in V && j in V), keys(Q))) ||
        QUBOTools.syntax_error("PIP expression references variable outside Binary section")

    all_vals = Iterators.flatten((values(L), values(Q), (offset,)))
    model_scale = 1.0
    if !all(isinteger, all_vals) && all(x -> isinteger(round(10 * x; digits = 8)), all_vals)
        model_scale = 0.1
        for (k, v) in L
            L[k] = round(10 * v)
        end
        for (k, v) in Q
            Q[k] = round(10 * v)
        end
        offset = round(10 * offset)
    end

    return QUBOTools.Model{Int,Float64,Int}(
        V,
        L,
        Q;
        scale  = model_scale,
        offset = offset,
        domain = :bool,
        sense  = sense,
    )
end

function _read_minlplib_solution(
    path::AbstractString,
    model::QUBOTools.Model{Int,Float64,Int};
    point::Union{Nothing,AbstractString} = nothing,
)
    return open(path, "r") do io
        _read_minlplib_solution!(io, model; point)
    end
end

function _read_minlplib_solution!(
    io::IO,
    model::QUBOTools.Model{Int,Float64,Int};
    point::Union{Nothing,AbstractString} = nothing,
)
    n = QUBOTools.dimension(model)
    ψ = zeros(Int, n)
    λ = nothing

    for raw_line in eachline(io)
        line = strip(raw_line)
        isempty(line) && continue
        parts = split(line)
        length(parts) == 2 || QUBOTools.syntax_error("Invalid MINLPLib solution line: '$line'")
        var_name, val_str = parts[1], parts[2]
        val = tryparse(Float64, val_str)
        isnothing(val) && QUBOTools.syntax_error("Invalid value in MINLPLib solution: '$line'")

        if var_name == "objvar"
            λ = val
        elseif startswith(var_name, "b")
            idx = tryparse(Int, var_name[2:end])
            (isnothing(idx) || !(1 <= idx <= n)) &&
                QUBOTools.syntax_error("Invalid variable '$var_name' in MINLPLib solution")
            ψ[idx] = round(Int, val)
        end
    end

    eval_val = QUBOTools.value(model, ψ)
    sol_val = isnothing(λ) ? eval_val : λ
    meta = Dict{String,Any}(
        "origin"           => "MINLPLib",
        "source_objective" => sol_val,
        "qubo_value"       => eval_val,
    )
    !isnothing(point) && (meta["point"] = String(point))

    samples = QUBOTools.Sample{Float64,Int}[QUBOTools.Sample{Float64,Int}(ψ, eval_val)]
    return QUBOTools.SampleSet{Float64,Int}(
        samples,
        meta;
        sense  = QUBOTools.sense(model),
        domain = :bool,
    )
end

function _minlplib_problem_class(family::AbstractString)
    if family == "autocorr_bern"
        return "Low Autocorrelation Binary Sequences"
    elseif family == "chimera"
        return "Max-Cut / Ising on Chimera Graphs"
    elseif family == "sporttournament"
        return "Max-Cut (Sport Tournament)"
    else
        return "Binary Quadratic Programming"
    end
end

function load_minlplib!(
    index::QUBOLib.LibraryIndex;
    root::Union{Nothing,AbstractString} = nothing,
    instances = MINLPLIB_QUBO_INSTANCES,
)
    data_path = mkpath(QUBOLib.cache_data_path(index, "minlplib"))
    selected = NamedTuple[]

    for info in instances
        name = info.name
        pip_dst = joinpath(data_path, "$(name).pip")
        if !isnothing(root)
            pip_src = joinpath(root, "$(name).pip")
            isfile(pip_src) || continue
            cp(pip_src, pip_dst; force = true)
            for pt in info.points
                sol_src = joinpath(root, "$(name).$(pt).sol")
                if isfile(sol_src)
                    cp(sol_src, joinpath(data_path, "$(name).$(pt).sol"); force = true)
                end
            end
            push!(selected, info)
        else
            if !isfile(pip_dst)
                Downloads.download("$(MINLPLIB_SOURCE_URL)pip/$(name).pip", pip_dst)
            end
            for pt in info.points
                sol_dst = joinpath(data_path, "$(name).$(pt).sol")
                if !isfile(sol_dst)
                    Downloads.download(
                        "$(MINLPLIB_SOURCE_URL)sol/$(name).$(pt).sol",
                        sol_dst,
                    )
                end
            end
            push!(selected, info)
        end
    end

    return selected
end

function build_minlplib!(
    index::QUBOLib.LibraryIndex;
    cache::Bool = true,
    root::Union{Nothing,AbstractString} = nothing,
    instances = MINLPLIB_QUBO_INSTANCES,
)
    if QUBOLib.has_collection(index, "minlplib")
        @info "[minlplib] Collection already exists"

        if cache
            return nothing
        else
            QUBOLib.remove_collection!(index, "minlplib")
        end
    end

    @info "[minlplib] Building MINLPLib QUBO collection"

    QUBOLib.add_collection!(index, "minlplib", MINLPLIB_DATA)
    selected = load_minlplib!(index; root, instances)
    data_path = QUBOLib.cache_data_path(index, "minlplib")

    for info in selected
        name = info.name
        pip_path = joinpath(data_path, "$(name).pip")
        model = QUBOTools.read_model(pip_path, Format(:minlplib_pip))

        inst_meta = Dict{String,Any}(
            "family"                => info.family,
            "formulation"           => info.formulation,
            "upstream_primal_bound" => info.primal_bound,
            "dual_bound"            => info.dual_bound,
            "gap"                   => info.gap,
            "proven_optimal"        => info.proven_optimal,
            "best_point"            => info.best_point,
            "points"                => info.points,
        )

        mod_i = QUBOLib.add_instance!(
            index,
            model,
            "minlplib";
            name              = "$(name).pip",
            source_name       = name,
            problem_class     = _minlplib_problem_class(info.family),
            formulation       = info.formulation,
            source_path       = "pip/$(name).pip",
            source_commit     = MINLPLIB_SOURCE_COMMIT,
            original_filename = "$(name).pip",
            source_url        = "$(MINLPLIB_SOURCE_URL)$(name).html",
            metadata          = inst_meta,
        )

        for pt in info.points
            sol_path = joinpath(data_path, "$(name).$(pt).sol")
            isfile(sol_path) || continue
            sol = _read_minlplib_solution(sol_path, model; point = pt)
            eval_val = QUBOTools.value(sol, 1)
            src_obj = get(QUBOTools.metadata(sol), "source_objective", eval_val)
            is_opt = info.proven_optimal &&
                     pt == info.best_point &&
                     isapprox(eval_val, info.primal_bound; atol = 1e-6)

            QUBOLib.add_solution!(
                index,
                mod_i,
                sol;
                qubo_value        = eval_val,
                source_value      = src_obj,
                source_objective  = src_obj,
                objective_bound   = info.primal_bound,
                dual_bound        = info.dual_bound,
                source_feasible   = true,
                proven_optimal    = is_opt,
                feasibility_status = "feasible",
                validation_status = isapprox(eval_val, src_obj; atol = 1e-6) ? "validated" : "evaluated",
                source_path       = "sol/$(name).$(pt).sol",
            )
        end
    end

    return nothing
end

function deploy_minlplib!(index::QUBOLib.LibraryIndex)
    close(index)

    src_path = QUBOLib.cache_data_path(index, "minlplib")
    dst_path = mkpath(joinpath(QUBOLib.build_path(index), "mirror"))
    zip_path = joinpath(dst_path, "minlplib.zip")

    run(`zip -q -j -r $zip_path $src_path`)

    return nothing
end
