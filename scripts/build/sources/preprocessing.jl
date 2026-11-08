const QUBOPREPROCESSING_SOLVER = "QUBOPreprocessing.jl"
const QUBOPREPROCESSING_VERSION = "0.2.1"
const QUBOPREPROCESSING_PREPARATION_TARGET_S = 5.0
const QUBOPREPROCESSING_SCHEDULE_OPTIONS = (
    enable_probing = true,
    max_block_size = 12,
    probe_rounds = 8,
    guaranteed_relation_work = 75_000,
    tie_break = :low,
)
const QUBOPREPROCESSING_REPOSITORY = "JuliaQUBO/QUBOPreprocessing.jl"
const QUBOPREPROCESSING_URL = "https://github.com/JuliaQUBO/QUBOPreprocessing.jl"

function _qubopreprocessing_edge_count(model::QUBOTools.Model)
    return length(QUBOTools.quadratic_terms(model))
end

_to_exact_rational_qubolib(x::Rational) = Rational{BigInt}(numerator(x), denominator(x))
_to_exact_rational_qubolib(x::Integer) = Rational{BigInt}(BigInt(x), BigInt(1))

function _to_exact_rational_qubolib(x::AbstractFloat)
    isfinite(x) || throw(ArgumentError("non-finite coefficient ($x) is not supported"))
    return Rational{BigInt}(x)
end

function _to_exact_rational_qubolib(x::Real)
    isfinite(x) || throw(ArgumentError("non-finite coefficient ($x) is not supported"))
    try
        return Rational{BigInt}(x)
    catch e
        e isa MethodError || rethrow()
    end
    y = Float64(x)
    isfinite(y) || throw(ArgumentError("non-finite coefficient ($x) is not supported"))
    return Rational{BigInt}(y)
end

function _exact_ising_fields_and_couplings(model::QUBOTools.Model)
    n = QUBOTools.dimension(model)
    n == 0 && return (Rational{BigInt}[], Rational{BigInt}[], Rational{BigInt}[])

    is_bool = Symbol(QUBOTools.domain(model)) == :bool
    lin_scale = is_bool ? (BigInt(1) // BigInt(2)) : (BigInt(1) // BigInt(1))
    quad_h_scale = is_bool ? (BigInt(1) // BigInt(4)) : (BigInt(0) // BigInt(1))
    quad_j_scale = is_bool ? (BigInt(1) // BigInt(4)) : (BigInt(1) // BigInt(1))

    h = fill(BigInt(0) // BigInt(1), n)
    l1 = fill(BigInt(0) // BigInt(1), n)
    l2_sq = fill(BigInt(0) // BigInt(1), n)

    for (i, v) in QUBOTools.linear_terms(model)
        h[i] += lin_scale * _to_exact_rational_qubolib(v)
    end

    for ((i, j), v) in QUBOTools.quadratic_terms(model)
        rv = _to_exact_rational_qubolib(v)
        if i == j
            is_bool && (h[i] += lin_scale * rv)
        else
            if is_bool
                dh = quad_h_scale * rv
                h[i] += dh
                h[j] += dh
            end
            aj = abs(quad_j_scale * rv)
            l1[i] += aj
            l1[j] += aj
            aj2 = aj * aj
            l2_sq[i] += aj2
            l2_sq[j] += aj2
        end
    end

    return (h, l1, l2_sq)
end

function _fast_float_ising_fields_and_couplings(model::QUBOTools.Model)
    n = QUBOTools.dimension(model)
    n == 0 && return (Float64[], Float64[], Float64[])

    is_bool = Symbol(QUBOTools.domain(model)) == :bool
    lin_scale = is_bool ? 0.5 : 1.0
    quad_h_scale = is_bool ? 0.25 : 0.0
    quad_j_scale = is_bool ? 0.25 : 1.0

    h = zeros(Float64, n)
    l1 = zeros(Float64, n)
    l2_sq = zeros(Float64, n)

    for (i, v) in QUBOTools.linear_terms(model)
        fv = Float64(v)
        @inbounds h[i] += lin_scale * fv
    end

    for ((i, j), v) in QUBOTools.quadratic_terms(model)
        fv = Float64(v)
        if i == j
            is_bool && (@inbounds h[i] += lin_scale * fv)
        else
            if is_bool
                dh = quad_h_scale * fv
                @inbounds h[i] += dh
                @inbounds h[j] += dh
            end
            aj = abs(quad_j_scale * fv)
            @inbounds l1[i] += aj
            @inbounds l1[j] += aj
            aj2 = aj * aj
            @inbounds l2_sq[i] += aj2
            @inbounds l2_sq[j] += aj2
        end
    end

    return (h, l1, l2_sq)
end

function _coercive_field_summary_dict(model::QUBOTools.Model)
    if _qubopreprocessing_edge_count(model) > 5_000
        hf, l1f, l2_sqf = _fast_float_ising_fields_and_couplings(model)
        n = length(hf)
        n_zero = count(x -> abs(x) <= 1e-12, hf)
        n_dom = count(i -> abs(hf[i]) > l1f[i] + 1e-12, 1:n)
        gi = (n_zero == n)
        zff = n > 0 ? n_zero / n : 1.0
        tdf = n > 0 ? n_dom / n : 0.0
        sum_l1 = 0.0; cnt_l1 = 0
        sum_l2 = 0.0; cnt_l2 = 0
        @inbounds for i in 1:n
            if l1f[i] > 1e-12
                sum_l1 += abs(hf[i]) / l1f[i]
                cnt_l1 += 1
            end
            if l2_sqf[i] > 1e-24
                sum_l2 += abs(hf[i]) / sqrt(l2_sqf[i])
                cnt_l2 += 1
            end
        end
        l1r = cnt_l1 > 0 ? sum_l1 / cnt_l1 : NaN
        l2r = cnt_l2 > 0 ? sum_l2 / cnt_l2 : NaN
        return Dict{String,Any}(
            "is_gauge_invariant"         => gi,
            "zero_field_fraction"        => round(zff; digits = 6),
            "trivial_dominance_fraction" => round(tdf; digits = 6),
            "coercive_l1_ratio"          => isnan(l1r) ? nothing : round(l1r; digits = 6),
            "coercive_l2_ratio"          => isnan(l2r) ? nothing : round(l2r; digits = 6),
        )
    end
    h, l1, l2_sq = _exact_ising_fields_and_couplings(model)
    n = length(h)
    n_zero = count(iszero, h)
    n_dom = count(i -> abs(h[i]) > l1[i], 1:n)
    gi = (n_zero == n)
    zff = n > 0 ? n_zero / n : 1.0
    tdf = n > 0 ? n_dom / n : 0.0

    sum_l1 = 0.0
    cnt_l1 = 0
    sum_l2 = 0.0
    cnt_l2 = 0
    for i in 1:n
        if !iszero(l1[i])
            sum_l1 += Float64(abs(h[i]) / l1[i])
            cnt_l1 += 1
        end
        if !iszero(l2_sq[i])
            sum_l2 += Float64(abs(h[i])) / sqrt(Float64(l2_sq[i]))
            cnt_l2 += 1
        end
    end
    l1r = cnt_l1 > 0 ? sum_l1 / cnt_l1 : NaN
    l2r = cnt_l2 > 0 ? sum_l2 / cnt_l2 : NaN

    return Dict{String,Any}(
        "is_gauge_invariant"         => gi,
        "zero_field_fraction"        => round(zff; digits = 6),
        "trivial_dominance_fraction" => round(tdf; digits = 6),
        "coercive_l1_ratio"          => isnan(l1r) ? nothing : round(l1r; digits = 6),
        "coercive_l2_ratio"          => isnan(l2r) ? nothing : round(l2r; digits = 6),
    )
end

function _field_alignment(
    model::QUBOTools.Model,
    state_domain::AbstractVector{<:Integer},
)
    n = QUBOTools.dimension(model)
    length(state_domain) == n || throw(
        DimensionMismatch(
            "state length $(length(state_domain)) does not match model dimension $n",
        ),
    )
    is_bool = Symbol(QUBOTools.domain(model)) == :bool
    for i in 1:n
        val = Int(state_domain[i])
        if is_bool
            (val == 0 || val == 1) ||
                throw(ArgumentError("expected bool state in {0, 1} at index $i, got $val"))
        else
            (val == -1 || val == 1) ||
                throw(ArgumentError("expected spin state in {-1, 1} at index $i, got $val"))
        end
    end
    if isdefined(QUBOTools, :field_alignment)
        fa = Float64(QUBOTools.field_alignment(model, collect(Int, state_domain)))
        return isnan(fa) ? nothing : round(fa; digits = 6)
    end

    h, _, _ = _exact_ising_fields_and_couplings(model)
    dir = Symbol(QUBOTools.sense(model)) == :max ? -1 : 1
    aligned = 0
    nonzero = 0
    for i in 1:n
        val = Int(state_domain[i])
        iszero(h[i]) && continue
        nonzero += 1
        s_i = is_bool ? (2 * val - 1) : val
        fav_s = (dir * h[i] > 0) ? -1 : 1
        s_i == fav_s && (aligned += 1)
    end
    return nonzero > 0 ? round(aligned / nonzero; digits = 6) : nothing
end

function _is_result_certified(res)::Bool
    if hasproperty(res, :certified)
        return Bool(getproperty(res, :certified))
    elseif res isa AbstractDict || applicable(get, res, :certified, false)
        return Bool(get(res, :certified, false))
    end
    return false
end

function _qubopreprocessing_summary_dict_from_runs(
    model::QUBOTools.Model,
    res_strong,
    res_weak;
    strong_time_s::Real = 0.0,
    weak_time_s::Real = 0.0,
)
    n_init = QUBOTools.dimension(model)
    m_init = _qubopreprocessing_edge_count(model)
    n_strong = QUBOTools.dimension(res_strong.model)
    m_strong = _qubopreprocessing_edge_count(res_strong.model)
    n_weak = QUBOTools.dimension(res_weak.model)
    m_weak = _qubopreprocessing_edge_count(res_weak.model)

    strong_var_red_pct = n_init > 0 ? 100.0 * (n_init - n_strong) / n_init : 0.0
    strong_edge_red_pct = m_init > 0 ? 100.0 * (m_init - m_strong) / m_init : 0.0
    weak_var_red_pct = n_init > 0 ? 100.0 * (n_init - n_weak) / n_init : 0.0
    weak_edge_red_pct = m_init > 0 ? 100.0 * (m_init - m_weak) / m_init : 0.0

    coercive_s = @elapsed coercive = _coercive_field_summary_dict(model)
    density(n, m) = n > 1 ? 2.0 * m / (Float64(n) * (n - 1)) : 0.0
    summary = Dict{String,Any}(
        "schema"              => "qubolib-builder-preprocessing-v1",
        "package"             => QUBOPREPROCESSING_SOLVER,
        "version"             => QUBOPREPROCESSING_VERSION,
        "repository"          => QUBOPREPROCESSING_REPOSITORY,
        "n_init"              => n_init,
        "m_init"              => m_init,
        "density_init"        => density(n_init, m_init),
        "density_strong"      => density(n_strong, m_strong),
        "density_weak"        => density(n_weak, m_weak),
        "n_strong"            => n_strong,
        "m_strong"            => m_strong,
        "strong_vars_removed" => n_init - n_strong,
        "strong_edges_removed" => m_init - m_strong,
        "strong_var_red_pct"  => round(strong_var_red_pct; digits = 4),
        "strong_edge_red_pct" => round(strong_edge_red_pct; digits = 4),
        "strong_certified"    => _is_result_certified(res_strong),
        "strong_time_s"       => round(Float64(strong_time_s); digits = 4),
        "n_weak"              => n_weak,
        "m_weak"              => m_weak,
        "weak_vars_removed"   => n_init - n_weak,
        "weak_edges_removed"  => m_init - m_weak,
        "weak_var_red_pct"    => round(weak_var_red_pct; digits = 4),
        "weak_edge_red_pct"   => round(weak_edge_red_pct; digits = 4),
        "weak_certified"      => _is_result_certified(res_weak),
        "weak_time_s"         => round(Float64(weak_time_s); digits = 4),
        "coercive_fields"     => coercive,
        "coercive_diagnostics_s" => coercive_s,
    )
    if hasproperty(res_strong, :diagnostics)
        summary["strong_run"] = res_strong.diagnostics
        summary["strong_time_s"] = res_strong.diagnostics["clocks"]["preparation_s"]
    end
    if hasproperty(res_weak, :diagnostics)
        summary["weak_run"] = res_weak.diagnostics
        summary["weak_time_s"] = res_weak.diagnostics["clocks"]["preparation_s"]
    end
    if hasproperty(res_strong, :rules)
        summary["strong_rules"] = res_strong.rules
    end
    if hasproperty(res_weak, :rules)
        summary["weak_rules"] = res_weak.rules
    end
    return summary
end

function _load_coercive_metrics_tsv(path::AbstractString)
    rows = Dict{Int,Dict{String,Any}}()
    lines = readlines(path)
    isempty(lines) && return rows

    for line in lines[2:end]
        isempty(strip(line)) && continue
        parts = split(line, '\t')
        inst_id = parse(Int, parts[1])
        gi = lowercase(strip(parts[9])) == "true"
        zff = parse(Float64, parts[10])
        tdf = parse(Float64, parts[11])
        l1_raw = strip(parts[12])
        l2_raw = strip(parts[13])
        l1r = (isempty(l1_raw) || lowercase(l1_raw) == "nan") ? NaN : parse(Float64, l1_raw)
        l2r = (isempty(l2_raw) || lowercase(l2_raw) == "nan") ? NaN : parse(Float64, l2_raw)

        rows[inst_id] = Dict{String,Any}(
            "is_gauge_invariant"         => gi,
            "zero_field_fraction"        => round(zff; digits = 6),
            "trivial_dominance_fraction" => round(tdf; digits = 6),
            "coercive_l1_ratio"          => isnan(l1r) ? nothing : round(l1r; digits = 6),
            "coercive_l2_ratio"          => isnan(l2r) ? nothing : round(l2r; digits = 6),
        )
    end

    return rows
end

function _load_preprocessing_summary_tsv(path::AbstractString)
    rows = Dict{Int,Dict{String,Any}}()
    lines = readlines(path)
    isempty(lines) && return rows

    for line in lines[2:end]
        isempty(strip(line)) && continue
        parts = split(line, '\t')
        inst_id = parse(Int, parts[1])
        n_init = parse(Int, parts[7])
        m_init = parse(Int, parts[8])
        n_strong = parse(Int, parts[9])
        m_strong = parse(Int, parts[10])
        strong_var_red_pct = parse(Float64, parts[11])
        strong_edge_red_pct = parse(Float64, parts[12])
        strong_dom = parse(Int, parts[13])
        strong_elim = parse(Int, parts[14])
        strong_star = parse(Int, parts[15])
        strong_rel = parse(Int, parts[16])
        strong_roof = parse(Int, parts[17])
        strong_submod = parse(Int, parts[18])
        strong_maxcut = parse(Int, parts[19])
        strong_probe = parse(Int, parts[20])
        strong_fill = parse(Int, parts[21])
        strong_cert_ok = lowercase(parts[22]) == "true"
        strong_time_s = parse(Float64, parts[23])
        n_weak = parse(Int, parts[24])
        m_weak = parse(Int, parts[25])
        weak_var_red_pct = parse(Float64, parts[26])
        weak_edge_red_pct = parse(Float64, parts[27])
        weak_dom = parse(Int, parts[28])
        weak_elim = parse(Int, parts[29])
        weak_star = parse(Int, parts[30])
        weak_rel = parse(Int, parts[31])
        weak_roof = parse(Int, parts[32])
        weak_submod = parse(Int, parts[33])
        weak_maxcut = parse(Int, parts[34])
        weak_probe = parse(Int, parts[35])
        weak_fill = parse(Int, parts[36])
        weak_cert_ok = lowercase(parts[37]) == "true"
        weak_time_s = parse(Float64, parts[38])

        rows[inst_id] = Dict{String,Any}(
            "package"              => QUBOPREPROCESSING_SOLVER,
            "version"              => nothing,
            "schedule"             => Dict("name" => "legacy_summary_tsv", "settings_recorded" => false),
            "repository"           => QUBOPREPROCESSING_REPOSITORY,
            "n_init"               => n_init,
            "m_init"               => m_init,
            "n_strong"             => n_strong,
            "m_strong"             => m_strong,
            "strong_vars_removed"  => n_init - n_strong,
            "strong_edges_removed" => m_init - m_strong,
            "strong_var_red_pct"   => strong_var_red_pct,
            "strong_edge_red_pct"  => strong_edge_red_pct,
            "strong_rules"         => Dict{String,Any}(
                "dominance"   => strong_dom,
                "elimination" => strong_elim,
                "star"        => strong_star,
                "relations"   => strong_rel,
                "roof"        => strong_roof,
                "submodular"  => strong_submod,
                "maxcut"      => strong_maxcut,
                "probing"     => strong_probe,
                "fill_edges"  => strong_fill,
            ),
            "strong_certified"     => strong_cert_ok,
            "strong_time_s"        => strong_time_s,
            "n_weak"               => n_weak,
            "m_weak"               => m_weak,
            "weak_vars_removed"    => n_init - n_weak,
            "weak_edges_removed"   => m_init - m_weak,
            "weak_var_red_pct"     => weak_var_red_pct,
            "weak_edge_red_pct"    => weak_edge_red_pct,
            "weak_rules"           => Dict{String,Any}(
                "dominance"   => weak_dom,
                "elimination" => weak_elim,
                "star"        => weak_star,
                "relations"   => weak_rel,
                "roof"        => weak_roof,
                "submodular"  => weak_submod,
                "maxcut"      => weak_maxcut,
                "probing"     => weak_probe,
                "fill_edges"  => weak_fill,
            ),
            "weak_certified"       => weak_cert_ok,
            "weak_time_s"          => weak_time_s,
        )
    end

    return rows
end

function _ensure_qubopreprocessing_solver!(index::QUBOLib.LibraryIndex)
    if !QUBOLib.has_solver(index, QUBOPREPROCESSING_SOLVER)
        QUBOLib.add_solver!(
            index,
            QUBOPREPROCESSING_SOLVER,
            Dict{String,Any}(
                "version"     => QUBOPREPROCESSING_VERSION,
                "description" => "Certified algebraic QUBO preprocessing and exact solution repair",
            ),
        )
    end
    return nothing
end

function _state_to_bool_vector(state::AbstractVector{<:Integer}, domain)
    if Symbol(domain) == :spin
        return [x > 0 ? 1 : 0 for x in state]
    else
        return [Int(x) for x in state]
    end
end

function _bool_vector_to_domain(bits::AbstractVector{<:Integer}, domain)
    if Symbol(domain) == :spin
        return [b == 1 ? 1 : -1 for b in bits]
    else
        return [Int(b) for b in bits]
    end
end

function _is_strictly_better_qubo(
    candidate::Real,
    baseline::Real,
    sense;
    atol::Real = 1e-8,
    rtol::Real = 1e-8,
)
    tol = max(Float64(atol), Float64(rtol) * max(1.0, abs(Float64(baseline))))
    if Symbol(sense) == :max
        return Float64(candidate) > Float64(baseline) + tol
    else
        return Float64(candidate) < Float64(baseline) - tol
    end
end

function _safe_materialize(preprocess_module::Module, ws; diagnostics = Dict{String,Any}())
    diagnostics["rounding"] = "none"
    diagnostics["fallback_reason"] = nothing
    try
        mat = preprocess_module.materialize(ws; coefficient_type = Float64)
        diagnostics["coefficient_type"] = "Float64"
        return mat
    catch e
        if e isa InexactError || e isa OverflowError || e isa ArgumentError
            diagnostics["fallback_reason"] = sprint(showerror, e)
            diagnostics["coefficient_type"] = "Rational{BigInt}"
            return preprocess_module.materialize(ws; coefficient_type = Rational{BigInt})
        end
        rethrow()
    end
end

function _reconstruct_qubopreprocessing(
    preprocess_module::Module,
    trace,
    reduced_state::AbstractVector{<:Integer},
)
    rec = preprocess_module.reconstruct(trace, reduced_state)
    return hasproperty(rec, :state) ? rec.state : rec
end

# No compatibility fallback: older releases cannot implement this policy.
function _construct_workspace(preprocess_module::Module, model::QUBOTools.Model)
    return preprocess_module.Workspace(
        model; rules = :mixed, integerize_scale = true, max_decimals = 9, atol = 0.0,
    )
end

function _canonical_exact_polynomial(model::QUBOTools.Model)
    s = _to_exact_rational_qubolib(QUBOTools.scale(model))
    off = s * _to_exact_rational_qubolib(QUBOTools.offset(model))
    lin = Dict{Int,Rational{BigInt}}()
    for (i, v) in QUBOTools.linear_terms(model)
        c = s * _to_exact_rational_qubolib(v)
        iszero(c) && continue
        idx = Int(i)
        c_new = get(lin, idx, zero(Rational{BigInt})) + c
        iszero(c_new) ? delete!(lin, idx) : (lin[idx] = c_new)
    end
    quad = Dict{Tuple{Int,Int},Rational{BigInt}}()
    is_bool = Symbol(QUBOTools.domain(model)) == :bool
    for ((i, j), v) in QUBOTools.quadratic_terms(model)
        c = s * _to_exact_rational_qubolib(v)
        iszero(c) && continue
        u, w = min(Int(i), Int(j)), max(Int(i), Int(j))
        if u == w
            if is_bool
                c_new = get(lin, u, zero(Rational{BigInt})) + c
                iszero(c_new) ? delete!(lin, u) : (lin[u] = c_new)
            else
                off += c
            end
        else
            key = (u, w)
            c_new = get(quad, key, zero(Rational{BigInt})) + c
            iszero(c_new) ? delete!(quad, key) : (quad[key] = c_new)
        end
    end
    return (offset = off, linear = lin, quadratic = quad)
end

function _is_identity_reduction(
    preprocess_module::Module,
    model::QUBOTools.Model,
    red_model::QUBOTools.Model,
    surviving::AbstractVector{<:Integer},
    trace;
    total_deductions::Int = 0,
)::Bool
    total_deductions == 0 || return false
    n_init = QUBOTools.dimension(model)
    QUBOTools.dimension(red_model) == n_init || return false
    length(surviving) == n_init || return false
    for i in 1:n_init
        Int(surviving[i]) == i || return false
    end
    Symbol(QUBOTools.sense(red_model)) == Symbol(QUBOTools.sense(model)) || return false
    Symbol(QUBOTools.domain(red_model)) == Symbol(QUBOTools.domain(model)) || return false
    _canonical_exact_polynomial(red_model) == _canonical_exact_polynomial(model) || return false
    if isdefined(preprocess_module, :reconstruct)
        low_val = Symbol(QUBOTools.domain(model)) == :spin ? -1 : 0
        probes = (
            fill(low_val, n_init),
            fill(1, n_init),
            [isodd(i) ? 1 : low_val for i in 1:n_init],
        )
        for probe in probes
            rec = try
                _reconstruct_qubopreprocessing(preprocess_module, trace, probe)
            catch
                return false
            end
            length(rec) == n_init || return false
            all(Int(rec[i]) == probe[i] for i in 1:n_init) || return false
        end
    end
    return true
end

function _verify_workspace_certificate(
    preprocess_module::Module,
    ws,
    model::QUBOTools.Model,
    red_model::QUBOTools.Model,
    surviving::AbstractVector{<:Integer},
    trace,
    total_deductions::Int,
)::Bool
    if !(isdefined(preprocess_module, :export_certificate) &&
         isdefined(preprocess_module, :verify_certificate))
        return false
    end
    cert = preprocess_module.export_certificate(ws)
    if isnothing(cert)
        return _is_identity_reduction(
            preprocess_module,
            model,
            red_model,
            surviving,
            trace;
            total_deductions = total_deductions,
        )
    end
    if hasproperty(cert, :steps) && isempty(cert.steps)
        return false
    end
    ver = preprocess_module.verify_certificate(ws, cert)
    return hasproperty(ver, :valid) ? Bool(ver.valid) : Bool(ver)
end

function _qubopreprocessing_policy(mode::Symbol, preparation_target_s::Real)
    mode in (:strong, :weak) || throw(ArgumentError("mode must be :strong or :weak"))
    (!(preparation_target_s isa Bool) && isfinite(preparation_target_s) &&
     preparation_target_s >= 0 && isfinite(Float64(preparation_target_s))) ||
        throw(ArgumentError("preparation_target_s must be finite nonnegative seconds"))
    options = Dict{String,Any}(string(k) => (v isa Symbol ? string(v) : v)
                               for (k, v) in pairs(QUBOPREPROCESSING_SCHEDULE_OPTIONS))
    return Dict{String,Any}(
        "name" => "QUBOPreprocessing.schedule_budgeted!",
        "preparation_target_s" => Float64(preparation_target_s),
        "target_kind" => "soft",
        "target_scope" => "configuration, workspace construction, scheduling, materialization/export, accounting",
        "excluded_costs" => ["model loading", "input/provenance hashing", "certificate verification",
                              "solution reconstruction/capture", "source objective evaluation",
                              "coercive-field diagnostics"],
        "mandatory_cheap_floor" => true,
        "hard_time_cap" => false,
        "downstream_solver_dispatched" => false,
        "mode" => string(mode),
        "allow_weak" => mode == :weak,
        "workspace" => Dict("rules" => "mixed", "integerize_scale" => true,
                             "max_decimals" => 9, "atol" => 0.0),
        "scheduler" => options,
        "materialization" => Dict("rounding" => "none", "preferred_coefficient_type" => "Float64",
                                   "exact_fallback_coefficient_type" => "Rational{BigInt}"),
    )
end

function _run_qubopreprocessing_mode(
    preprocess_module::Module,
    model::QUBOTools.Model;
    mode::Symbol = :strong,
    preparation_target_s::Real = QUBOPREPROCESSING_PREPARATION_TARGET_S,
)
    start_ns = time_ns()
    policy = _qubopreprocessing_policy(mode, preparation_target_s)
    _check_qubopreprocessing_version(pkgversion(preprocess_module))
    for name in (:Workspace, :schedule_budgeted!, :materialize, :export_model, :index_map)
        isdefined(preprocess_module, name) || error("$(QUBOPREPROCESSING_SOLVER) v$(QUBOPREPROCESSING_VERSION) with $name is required")
    end
    construction_start_ns = time_ns()
    ws = _construct_workspace(preprocess_module, model)
    construction_end_ns = time_ns()
    construction_s = (construction_end_ns - construction_start_ns) / 1e9
    elapsed_before_schedule_s = (construction_end_ns - start_ns) / 1e9
    # The public scheduler starts its own clock. Construction consumes the same
    # preparation allowance, but its mandatory cheap floor can overrun even zero.
    scheduler_budget_s = max(0.0, Float64(preparation_target_s) - elapsed_before_schedule_s)
    schedule = preprocess_module.schedule_budgeted!(
        ws; time_limit = scheduler_budget_s, allow_weak = mode == :weak,
        QUBOPREPROCESSING_SCHEDULE_OPTIONS...,
    )
    schedule_end_ns = time_ns()
    materialization = Dict{String,Any}()
    mat = _safe_materialize(preprocess_module, ws; diagnostics = materialization)
    red_model = preprocess_module.export_model(mat)
    materialization_end_ns = time_ns()
    mapping = preprocess_module.index_map(mat)
    surviving = sort!(findall(>(0), mapping); by = i -> mapping[i])
    families = [Dict{String,Any}(
        "family" => string(f.family), "calls" => f.calls, "time_s" => f.time_s,
        "variables_removed" => f.freed, "stop_reason" => string(f.stop_reason),
    ) for f in schedule.families]
    rules = Dict{String,Any}(f["family"] => f["variables_removed"] for f in families)
    total_deductions = sum(f.freed for f in schedule.families; init = 0)
    diagnostics = Dict{String,Any}(
        "policy" => policy,
        "scheduler_budget_s" => scheduler_budget_s,
        "stop_reason" => string(schedule.stop_reason),
        "passes" => schedule.passes,
        "scheduler_report_elapsed_s" => schedule.elapsed_s,
        "initial_variables" => schedule.initial_variables,
        "residual_variables" => schedule.residual_variables,
        "families" => families,
        "normalization" => Dict{String,Any}(
            "integerize_scale" => true, "max_decimals" => 9, "atol" => 0.0,
            "input_scale" => string(QUBOTools.scale(model)),
            "export_scale" => string(QUBOTools.scale(red_model)),
            "workspace_perturbed" => hasproperty(ws, :perturbed) ? ws.perturbed : nothing,
            "workspace_max_perturbation" => hasproperty(ws, :max_perturbation) ? string(ws.max_perturbation) : nothing,
            "export_perturbed" => hasproperty(mat, :perturbed) ? mat.perturbed : nothing,
            "export_max_perturbation" => hasproperty(mat, :max_perturbation) ? string(mat.max_perturbation) : nothing,
        ),
        "materialization" => materialization,
    )
    preparation_end_ns = time_ns()
    preparation_s = (preparation_end_ns - start_ns) / 1e9
    verification_start_ns = time_ns()
    certified = _verify_workspace_certificate(
        preprocess_module, ws, model, red_model, surviving, mat, total_deductions,
    )
    verification_end_ns = time_ns()
    diagnostics["clocks"] = Dict{String,Any}(
        "configuration_s" => (construction_start_ns - start_ns) / 1e9,
        "construction_s" => construction_s,
        "schedule_s" => (schedule_end_ns - construction_end_ns) / 1e9,
        "materialization_export_s" => (materialization_end_ns - schedule_end_ns) / 1e9,
        "accounting_s" => (preparation_end_ns - materialization_end_ns) / 1e9,
        "preparation_s" => preparation_s,
        "preparation_overrun_s" => max(0.0, preparation_s - Float64(preparation_target_s)),
        "certificate_verification_s" => (verification_end_ns - verification_start_ns) / 1e9,
        "total_mode_s" => (verification_end_ns - start_ns) / 1e9,
    )
    diagnostics["certificate_verified"] = certified
    return (model = red_model, surviving_variables = surviving, trace = mat,
            rules = rules, certified = certified, diagnostics = diagnostics)
end

const _QUBOLIB_REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))

function _git_build_output(args::Vector{String})
    try
        return String(strip(read(pipeline(`git -C $(_QUBOLIB_REPO_ROOT) $args`; stderr = devnull), String)))
    catch err
        err isa InterruptException && rethrow()
        return nothing
    end
end

# Commit and dirty flag of the QUBOLib checkout itself; `nothing` when this file
# is not inside a QUBOLib git checkout (git walks up to any enclosing repository).
function _qubolib_git_state()
    top = _git_build_output(["rev-parse", "--show-toplevel"])
    if isnothing(top) || !isdir(top) || realpath(top) != realpath(_QUBOLIB_REPO_ROOT)
        return (commit = nothing, dirty = nothing)
    end
    status = _git_build_output(["status", "--porcelain", "--untracked-files=no"])
    return (
        commit = _git_build_output(["rev-parse", "HEAD"]),
        dirty = isnothing(status) ? nothing : !isempty(status),
    )
end

_file_sha256(path::AbstractString) = bytes2hex(SHA.sha256(read(path)))
# Line endings are normalized so CRLF checkouts hash like the repository blob.
_source_sha256(path::AbstractString) = bytes2hex(SHA.sha256(replace(read(path, String), "\r\n" => "\n")))

# Hash of this file as loaded; provenance describes the code that runs, not later edits.
const _PREPROCESSING_SOURCE_SHA256 = _source_sha256(@__FILE__)

# Hashing is deliberately outside the preparation clock. Include native domain,
# sense and exact stored coefficients; this identifies input bytes mathematically
# without evaluating an objective or changing the Bool/Spin representation.
function _qubopreprocessing_model_identity(model::QUBOTools.Model)
    ctx = SHA.SHA2_256_CTX()
    add(parts...) = SHA.update!(ctx, codeunits(string(parts..., '\n')))
    add("qubolib-stored-model-v1 ", QUBOTools.dimension(model), ' ',
        Symbol(QUBOTools.domain(model)), ' ', Symbol(QUBOTools.sense(model)))
    add("scale ", _to_exact_rational_qubolib(QUBOTools.scale(model)))
    add("offset ", _to_exact_rational_qubolib(QUBOTools.offset(model)))
    for (i, v) in sort!(collect(QUBOTools.linear_terms(model)); by = first)
        add("linear ", i, ' ', _to_exact_rational_qubolib(v))
    end
    for ((i, j), v) in sort!(collect(QUBOTools.quadratic_terms(model)); by = first)
        add("quadratic ", i, ' ', j, ' ', _to_exact_rational_qubolib(v))
    end
    return Dict{String,Any}(
        "fingerprint_schema" => "qubolib-stored-model-v1",
        "sha256" => bytes2hex(SHA.digest!(ctx)),
        "dimension" => QUBOTools.dimension(model),
        "quadratic_terms" => _qubopreprocessing_edge_count(model),
        "domain" => string(Symbol(QUBOTools.domain(model))),
        "sense" => string(Symbol(QUBOTools.sense(model))),
    )
end

function _package_git_state(root)
    isnothing(root) && return (commit = nothing, dirty = nothing)
    output(args) = try
        strip(read(pipeline(`git -C $root $args`; stderr = devnull), String))
    catch err
        err isa InterruptException && rethrow()
        nothing
    end
    top = output(["rev-parse", "--show-toplevel"])
    (isnothing(top) || !isdir(top) || realpath(top) != realpath(root)) &&
        return (commit = nothing, dirty = nothing)
    status = output(["status", "--porcelain", "--untracked-files=no"])
    return (commit = output(["rev-parse", "HEAD"]),
            dirty = isnothing(status) ? nothing : !isempty(status))
end

function _check_qubopreprocessing_version(loaded::Union{VersionNumber,Nothing})
    if !isnothing(loaded) && loaded != VersionNumber(QUBOPREPROCESSING_VERSION)
        error("Loaded $(QUBOPREPROCESSING_SOLVER) v$(loaded) does not match " *
              "QUBOPREPROCESSING_VERSION = \"$(QUBOPREPROCESSING_VERSION)\"")
    end
    return nothing
end

# Build provenance stored with every instance's preprocessing metadata, so an
# index.db can be traced to the code and package versions that produced it.
# All fields describe the enrichment run; per-instance `result_source` and
# `coercive_source` say whether results came from that run or from an input TSV.
function _qubopreprocessing_build_provenance(
    preprocess_module::Module;
    summary_tsv::Union{AbstractString,Nothing} = nothing,
    coercive_tsv::Union{AbstractString,Nothing} = nothing,
)
    loaded = pkgversion(preprocess_module)
    _check_qubopreprocessing_version(loaded)
    _source_sha256(@__FILE__) == _PREPROCESSING_SOURCE_SHA256 ||
        error("$(@__FILE__) changed on disk since it was loaded; restart Julia before enrichment")
    pkg_root = pkgdir(preprocess_module)
    uuid = Base.PkgId(preprocess_module).uuid
    dep = isnothing(uuid) ? nothing : get(Pkg.dependencies(), uuid, nothing)
    git = _qubolib_git_state()
    package_git = _package_git_state(pkg_root)
    project = Base.active_project()
    manifest = isnothing(project) ? nothing : joinpath(dirname(project), "Manifest.toml")
    return Dict{String,Any}(
        "qubolib_build_commit"           => git.commit,
        "qubolib_build_tree_dirty"       => git.dirty,
        "qubolib_build_tree_hash"        => _git_build_output(["rev-parse", "HEAD^{tree}"]),
        "pipeline_source"                => "scripts/build/sources/preprocessing.jl",
        "pipeline_source_sha256"         => _PREPROCESSING_SOURCE_SHA256,
        "qubopreprocessing_version"      => isnothing(loaded) ? nothing : string(loaded),
        "qubopreprocessing_tree_hash"    => isnothing(pkg_root) ? nothing : bytes2hex(Pkg.GitTools.tree_hash(pkg_root)),
        "qubopreprocessing_git_revision" => isnothing(dep) ? nothing : dep.git_revision,
        "qubopreprocessing_git_commit"   => package_git.commit,
        "qubopreprocessing_tree_dirty"   => package_git.dirty,
        "julia_version"                 => string(VERSION),
        "julia_threads"                 => Threads.nthreads(),
        "project_sha256"                => isnothing(project) ? nothing : _file_sha256(project),
        "manifest_sha256"               => isnothing(manifest) || !isfile(manifest) ? nothing : _file_sha256(manifest),
        "summary_tsv_sha256"             => isnothing(summary_tsv) ? nothing : _file_sha256(summary_tsv),
        "coercive_tsv_sha256"            => isnothing(coercive_tsv) ? nothing : _file_sha256(coercive_tsv),
    )
end

# A uniform candidate reuses these submissions while releasing each instance's
# model and traces before loading the next one. Ordinary enrichment keeps its
# existing one-call behavior.
function _qubopreprocessing_submissions!(index, build_provenance)
    # Submission for certified exact reduction (n_reduced == 0)
    exact_submission = QUBOLib.add_submission!(
        index;
        submitter = QUBOPREPROCESSING_SOLVER,
        reference = QUBOPREPROCESSING_URL,
        modeling_approach = "QUBO",
        workflow = "Certified algebraic QUBO preprocessing to zero residual variables (n_reduced = 0)",
        algorithm_type = "Deterministic",
        remarks = "Exact ground state certified by QUBOPreprocessing.jl v$(QUBOPREPROCESSING_VERSION) without search",
        metadata = Dict{String,Any}(
            "package"         => QUBOPREPROCESSING_SOLVER,
            "version"         => QUBOPREPROCESSING_VERSION,
            "repository"      => QUBOPREPROCESSING_REPOSITORY,
            "submission_kind" => "certified_exact_reduction",
            "run_started_unix_s" => build_provenance["run_started_unix_s"],
        ),
    )

    # Submission for certified solution repair
    repair_submission = QUBOLib.add_submission!(
        index;
        submitter = QUBOPREPROCESSING_SOLVER,
        reference = QUBOPREPROCESSING_URL,
        modeling_approach = "QUBO",
        workflow = "Certified algebraic QUBO preprocessing + exact trace reconstruction on existing solution records",
        algorithm_type = "Deterministic",
        remarks = "Strictly improved solution obtained by projecting an existing QUBOLib solution to the reduced residual core and reconstructing fixed/eliminated variables via QUBOPreprocessing.reconstruct",
        metadata = Dict{String,Any}(
            "package"         => QUBOPREPROCESSING_SOLVER,
            "version"         => QUBOPREPROCESSING_VERSION,
            "repository"      => QUBOPREPROCESSING_REPOSITORY,
            "submission_kind" => "certified_solution_repair",
            "run_started_unix_s" => build_provenance["run_started_unix_s"],
        ),
    )

    return (exact = exact_submission, repair = repair_submission)
end

function _preprocessing_instance_filter(ids)
    isnothing(ids) && return ""
    all(id -> id isa Integer && !(id isa Bool) && 0 < id <= typemax(Int), ids) ||
        throw(ArgumentError("instance IDs must be positive machine-sized integers"))
    return isempty(ids) ? "WHERE 0" : "WHERE instance IN ($(join(sort!(Int.(collect(ids))), ',')))"
end

function _validate_preprocessing_submissions(index, ids)
    ids isa NamedTuple && keys(ids) == (:exact, :repair) ||
        throw(ArgumentError("submission_ids must contain exact and repair IDs"))
    all(id -> id isa Integer && !(id isa Bool) && 0 < id <= typemax(Int), values(ids)) &&
        ids.exact != ids.repair || throw(ArgumentError("invalid preprocessing submission IDs"))
    for (name, id, kind) in ((:exact, ids.exact, "certified_exact_reduction"),
                              (:repair, ids.repair, "certified_solution_repair"))
        rows = QUBOLib.DBInterface.execute(QUBOLib.database(index),
            "SELECT metadata FROM Submissions WHERE submission = ?;", (Int(id),)) |> QUBOLib.DataFrame
        size(rows, 1) == 1 || throw(ArgumentError("missing $name preprocessing submission"))
        meta = QUBOLib.JSON.parse(String(rows[1, :metadata]))
        get(meta, "submission_kind", nothing) == kind &&
            get(meta, "version", nothing) == QUBOPREPROCESSING_VERSION ||
            throw(ArgumentError("$name submission does not match preprocessing kind/version"))
    end
    return ids
end

function enrich_preprocessing!(
    index::QUBOLib.LibraryIndex,
    preprocess_module::Module;
    summary_tsv::Union{AbstractString,Nothing} = nothing,
    coercive_tsv::Union{AbstractString,Nothing} = nothing,
    repair_instance_ids::Union{AbstractSet{<:Integer},Nothing} = nothing,
    instance_ids::Union{AbstractSet{<:Integer},Nothing} = nothing,
    submission_ids = nothing,
)
    instance_filter = _preprocessing_instance_filter(instance_ids)
    _preprocessing_instance_filter(repair_instance_ids)
    if !isnothing(instance_ids)
        if isnothing(repair_instance_ids)
            repair_instance_ids = instance_ids
        else
            issubset(repair_instance_ids, instance_ids) ||
                throw(ArgumentError("repair IDs must be within the selected instance IDs"))
        end
    end
    isnothing(submission_ids) || _validate_preprocessing_submissions(index, submission_ids)
    provenance_s = @elapsed build_provenance = _qubopreprocessing_build_provenance(preprocess_module; summary_tsv, coercive_tsv)
    build_provenance["provenance_capture_s"] = provenance_s
    build_provenance["run_started_unix_s"] = time()
    _ensure_qubopreprocessing_solver!(index)
    db = QUBOLib.database(index)

    precomputed = isnothing(summary_tsv) ? Dict{Int,Dict{String,Any}}() :
                  _load_preprocessing_summary_tsv(summary_tsv)
    precomputed_coercive = isnothing(coercive_tsv) ? Dict{Int,Dict{String,Any}}() :
                           _load_coercive_metrics_tsv(coercive_tsv)

    instances_df = QUBOLib.DBInterface.execute(
        db,
        """
        SELECT instance, collection, name, dimension, density, sense, domain, metadata
        FROM Instances
        $instance_filter
        ORDER BY instance;
        """,
    ) |> QUBOLib.DataFrame
    isnothing(instance_ids) || size(instances_df, 1) == length(instance_ids) ||
        throw(ArgumentError("selected instance IDs are missing from the library"))

    # Cache live preprocessing results for instances we need to solve/repair
    live_results = Dict{Int,NamedTuple}()
    zero_var_instances = Int[]

    QUBOLib.DBInterface.execute(db, "SAVEPOINT enrich_preprocessing_metadata;")
    try
        update_stmt = QUBOLib.SQLite.Stmt(
            db,
            "UPDATE Instances SET metadata = ? WHERE instance = ?;",
        )
        for row in eachrow(instances_df)
            inst_id = Int(row[:instance])
            raw_meta = row[:metadata]
            meta = if ismissing(raw_meta) || isnothing(raw_meta) || isempty(strip(String(raw_meta)))
                Dict{String,Any}()
            else
                 parsed = QUBOLib.JSON.parse(String(raw_meta))
                 parsed isa AbstractDict ? Dict{String,Any}(String(k) => v for (k, v) in pairs(parsed)) : Dict{String,Any}()
            end

            load_s = 0.0
            hash_s = 0.0
            input_identity = nothing
            prep_info = if haskey(precomputed, inst_id)
                info = copy(precomputed[inst_id])
                if haskey(precomputed_coercive, inst_id)
                    info["coercive_fields"] = precomputed_coercive[inst_id]
                elseif !haskey(info, "coercive_fields")
                    load_s = @elapsed model_c = QUBOLib.load_instance(index, inst_id)
                    info["coercive_fields"] = _coercive_field_summary_dict(model_c)
                end
                info
            else
                load_s = @elapsed model = QUBOLib.load_instance(index, inst_id)
                hash_s = @elapsed input_identity = _qubopreprocessing_model_identity(model)
                t_s = @elapsed res_s = _run_qubopreprocessing_mode(preprocess_module, model; mode = :strong)
                t_w = @elapsed res_w = _run_qubopreprocessing_mode(preprocess_module, model; mode = :weak)
                live_results[inst_id] = (model = model, strong = res_s, weak = res_w)
                info = _qubopreprocessing_summary_dict_from_runs(
                    model,
                    res_s,
                    res_w;
                    strong_time_s = t_s,
                    weak_time_s = t_w,
                )
                if haskey(precomputed_coercive, inst_id)
                    info["coercive_fields"] = precomputed_coercive[inst_id]
                end
                info
            end

            provenance = copy(build_provenance)
            provenance["result_source"] = haskey(precomputed, inst_id) ? "summary_tsv" : "pipeline"
            if !isnothing(input_identity)
                input_identity["instance"] = inst_id
                input_identity["collection"] = row[:collection]
                input_identity["name"] = row[:name]
                prep_info["input"] = input_identity
            end
            prep_info["enrichment_clocks"] = Dict("model_loading_s" => load_s, "input_hashing_s" => hash_s)
            provenance["coercive_source"] =
                haskey(precomputed_coercive, inst_id) ? "coercive_tsv" :
                haskey(get(precomputed, inst_id, Dict{String,Any}()), "coercive_fields") ? "summary_tsv" :
                "pipeline"
            prep_info["provenance"] = provenance
            if haskey(meta, "preprocessing") || any(haskey(meta, k) for k in ("n_strong", "m_strong", "n_weak", "m_weak"))
                history = get!(meta, "preprocessing_runs", Any[])
                history isa AbstractVector || error("Existing preprocessing_runs must be an array")
                push!(history, Dict("schema" => "qubolib-builder-preprocessing-v1", "result" => prep_info))
            else
                for k in ("n_strong", "m_strong", "n_weak", "m_weak")
                    meta[k] = Int(prep_info[k])
                end
                meta["preprocessing"] = prep_info
            end

            strong_zero_cert =
                Int(prep_info["n_strong"]) == 0 &&
                get(prep_info, "strong_certified", false) == true
            weak_zero_cert =
                Int(prep_info["n_weak"]) == 0 &&
                get(prep_info, "weak_certified", false) == true
            if strong_zero_cert || weak_zero_cert
                push!(zero_var_instances, inst_id)
            end

            QUBOLib.DBInterface.execute(update_stmt, (QUBOLib.JSON.json(meta), inst_id))
        end
        QUBOLib.DBInterface.execute(db, "RELEASE SAVEPOINT enrich_preprocessing_metadata;")
    catch
        QUBOLib.DBInterface.execute(db, "ROLLBACK TO SAVEPOINT enrich_preprocessing_metadata;")
        QUBOLib.DBInterface.execute(db, "RELEASE SAVEPOINT enrich_preprocessing_metadata;")
        rethrow()
    end

    submissions = isnothing(submission_ids) ?
        _qubopreprocessing_submissions!(index, build_provenance) : submission_ids
    exact_submission, repair_submission = submissions.exact, submissions.repair

    exact_count = 0
    for inst_id in sort(unique(zero_var_instances))
        entry = get!(live_results, inst_id) do
            model = QUBOLib.load_instance(index, inst_id)
            res_s = _run_qubopreprocessing_mode(preprocess_module, model; mode = :strong)
            res_w = _run_qubopreprocessing_mode(preprocess_module, model; mode = :weak)
            (model = model, strong = res_s, weak = res_w)
        end
        model = entry.model
        domain = QUBOTools.domain(model)
        prep_meta = get(precomputed, inst_id, nothing)
        strong_meta_cert =
            isnothing(prep_meta) ? true : (get(prep_meta, "strong_certified", false) == true)
        weak_meta_cert =
            isnothing(prep_meta) ? true : (get(prep_meta, "weak_certified", false) == true)
        strong_ok =
            QUBOTools.dimension(entry.strong.model) == 0 &&
            _is_result_certified(entry.strong) &&
            strong_meta_cert
        weak_ok =
            QUBOTools.dimension(entry.weak.model) == 0 &&
            _is_result_certified(entry.weak) &&
            weak_meta_cert
        if strong_ok
            mode_sym = :strong
            res = entry.strong
        elseif weak_ok
            mode_sym = :weak
            res = entry.weak
        else
            continue
        end

        capture_start_ns = time_ns()
        reconstruction_s = @elapsed state_domain = _reconstruct_qubopreprocessing(preprocess_module, res.trace, Int[])
        evaluation_start_ns = time_ns()
        state_bool = _state_to_bool_vector(state_domain, domain)
        qubo_val = Float64(QUBOTools.value(model, state_domain))
        cert_val = Float64(QUBOTools.scale(res.model)) * Float64(QUBOTools.offset(res.model))
        if !isapprox(qubo_val, cert_val; rtol = 1e-8, atol = 1e-8)
            error(
                "[preprocessing] Certified offset ($cert_val) != evaluated QUBO value ($qubo_val) on instance $inst_id",
            )
        end

        stored_objective_check_s = (time_ns() - evaluation_start_ns) / 1e9
        source_evaluation_s = @elapsed begin
            evaluator = _qoblib_source_evaluator(index, inst_id; context = "preprocessing-exact-$inst_id")
            source_eval = _qoblib_source_evaluation(
                evaluator, state_bool; context = "preprocessing-exact-$inst_id",
            )
        end

        sol_meta = Dict{String,Any}(
            "solver"            => QUBOPREPROCESSING_SOLVER,
            "solver_version"    => QUBOPREPROCESSING_VERSION,
            "status"            => "optimal",
            "origin"            => "certified_exact_reduction",
            "reduction_mode"    => String(mode_sym),
            "n_init"            => QUBOTools.dimension(model),
            "m_init"            => _qubopreprocessing_edge_count(model),
            "n_reduced"         => 0,
            "m_reduced"         => 0,
            "certified_offset"  => cert_val,
            "field_alignment"   => _field_alignment(model, state_domain),
            "validation_status" => "validated",
            "preparation_run" => res.diagnostics,
            "capture_clocks" => Dict(
                "reconstruction_s" => reconstruction_s,
                "stored_objective_check_s" => stored_objective_check_s,
                "source_evaluation_s" => source_evaluation_s,
                "capture_before_storage_s" => (time_ns() - capture_start_ns) / 1e9,
                "scope" => "reconstruction, objective checks, source evaluation and metadata; excludes SampleSet/storage",
            ),
        )
        sol = QUBOTools.SampleSet{Float64,Int}(model, [state_domain]; metadata = sol_meta)

        QUBOLib.add_solution!(
            index,
            inst_id,
            sol;
            submission = exact_submission,
            qubo_value = qubo_val,
            source_value = qubo_val,
            source_objective = source_eval.source_objective,
            dual_bound = qubo_val,
            objective_bound = qubo_val,
            source_feasible = source_eval.source_feasible,
            proven_optimal = true,
            feasibility_status = "feasible",
            validation_status = "validated",
            incumbent_candidate = true,
            source_path = "QUBOPreprocessing.jl/$(mode_sym)/exact_reduction",
        )
        exact_count += 1
    end

    # Solution repair on existing validated solution records
    records_query = if isnothing(repair_instance_ids)
        QUBOLib.DBInterface.execute(
            db,
            """
            SELECT r.record, r.instance, r.submission, r.solution, r.bitstring,
                   r.qubo_value, r.proven_optimal, r.source_path, i.sense, i.domain, i.dimension
            FROM SolutionRecords AS r
            JOIN Instances AS i ON i.instance = r.instance
            WHERE r.bitstring IS NOT NULL
              AND r.qubo_value IS NOT NULL
              AND r.proven_optimal = 0
              AND (r.submission IS NULL OR (r.submission != ? AND r.submission != ?))
            ORDER BY r.record;
            """,
            (exact_submission, repair_submission),
        ) |> QUBOLib.DataFrame
    else
        ids_list = join(sort(collect(Int.(repair_instance_ids))), ",")
        isempty(ids_list) ? QUBOLib.DataFrame() :
        (
            QUBOLib.DBInterface.execute(
                db,
                """
                SELECT r.record, r.instance, r.submission, r.solution, r.bitstring,
                       r.qubo_value, r.proven_optimal, r.source_path, i.sense, i.domain, i.dimension
                FROM SolutionRecords AS r
                JOIN Instances AS i ON i.instance = r.instance
                WHERE r.instance IN ($ids_list)
                  AND r.bitstring IS NOT NULL
                  AND r.qubo_value IS NOT NULL
                  AND r.proven_optimal = 0
                  AND (r.submission IS NULL OR (r.submission != ? AND r.submission != ?))
                ORDER BY r.record;
                """,
                (exact_submission, repair_submission),
            ) |> QUBOLib.DataFrame
        )
    end

    repaired_strong_count = 0
    repaired_weak_count = 0

    for rec in eachrow(records_query)
        inst_id = Int(rec[:instance])
        rec_id = Int(rec[:record])
        bitstr = String(rec[:bitstring])
        length(bitstr) == Int(rec[:dimension]) || continue

        entry = get!(live_results, inst_id) do
            model = QUBOLib.load_instance(index, inst_id)
            res_s = _run_qubopreprocessing_mode(preprocess_module, model; mode = :strong)
            res_w = _run_qubopreprocessing_mode(preprocess_module, model; mode = :weak)
            (model = model, strong = res_s, weak = res_w)
        end
        model = entry.model
        sense = QUBOTools.sense(model)
        domain = QUBOTools.domain(model)
        orig_bits = QUBOLib._bitstring_state(bitstr)
        orig_state = _bool_vector_to_domain(orig_bits, domain)
        orig_val = Float64(QUBOTools.value(model, orig_state))
        orig_fa = _field_alignment(model, orig_state)
        prep_meta = get(precomputed, inst_id, nothing)
        strong_meta_cert =
            isnothing(prep_meta) ? true : (get(prep_meta, "strong_certified", false) == true)
        weak_meta_cert =
            isnothing(prep_meta) ? true : (get(prep_meta, "weak_certified", false) == true)

        # Strong repair
        res_s = entry.strong
        strong_certified = _is_result_certified(res_s) && strong_meta_cert
        red_state_s = [orig_state[v] for v in res_s.surviving_variables]
        capture_start_ns = time_ns()
        reconstruction_s = @elapsed rec_state_s = _reconstruct_qubopreprocessing(preprocess_module, res_s.trace, red_state_s)
        objective_evaluation_s = @elapsed rec_val_s = Float64(QUBOTools.value(model, rec_state_s))
        rec_bits_s = _state_to_bool_vector(rec_state_s, domain)

        evaluator = nothing
        if _is_strictly_better_qubo(rec_val_s, orig_val, sense)
            evaluator = _qoblib_source_evaluator(index, inst_id; context = "preprocessing-repair-$rec_id")
            source_evaluation_s = @elapsed source_eval = _qoblib_source_evaluation(
                evaluator,
                rec_bits_s;
                context = "preprocessing-repair-strong-$rec_id",
            )
            hamming_s = count(i -> orig_bits[i] != rec_bits_s[i], eachindex(orig_bits))
            rec_fa_s = _field_alignment(model, rec_state_s)
            fa_imp_s = (isnothing(rec_fa_s) || isnothing(orig_fa)) ? nothing : round(rec_fa_s - orig_fa; digits = 6)
            sol_meta = Dict{String,Any}(
                "solver"                      => QUBOPREPROCESSING_SOLVER,
                "solver_version"              => QUBOPREPROCESSING_VERSION,
                "origin"                      => "certified_solution_repair",
                "repair_package"              => QUBOPREPROCESSING_SOLVER,
                "repair_version"              => QUBOPREPROCESSING_VERSION,
                "repair_mode"                 => "strong",
                "parent_record"               => rec_id,
                "parent_solution"             => ismissing(rec[:solution]) ? nothing : Int(rec[:solution]),
                "parent_submission"           => ismissing(rec[:submission]) ? nothing : Int(rec[:submission]),
                "parent_qubo_value"           => orig_val,
                "qubo_improvement"            => rec_val_s - orig_val,
                "hamming_distance"            => hamming_s,
                "parent_field_alignment"      => orig_fa,
                "field_alignment"             => rec_fa_s,
                "field_alignment_improvement" => fa_imp_s,
                "n_init"                      => QUBOTools.dimension(model),
                "n_reduced"                   => QUBOTools.dimension(res_s.model),
                "validation_status"           => "validated",
                "preparation_run"             => res_s.diagnostics,
                "capture_clocks" => Dict(
                    "reconstruction_s" => reconstruction_s,
                    "stored_objective_evaluation_s" => objective_evaluation_s,
                    "source_evaluation_s" => source_evaluation_s,
                    "capture_before_storage_s" => (time_ns() - capture_start_ns) / 1e9,
                    "scope" => "reconstruction, objective/source evaluation and metadata; excludes SampleSet/storage",
                ),
            )
            sol = QUBOTools.SampleSet{Float64,Int}(model, [rec_state_s]; metadata = sol_meta)
            QUBOLib.add_solution!(
                index,
                inst_id,
                sol;
                submission = repair_submission,
                qubo_value = rec_val_s,
                source_value = rec_val_s,
                source_objective = source_eval.source_objective,
                source_feasible = source_eval.source_feasible,
                proven_optimal = (QUBOTools.dimension(res_s.model) == 0) && strong_certified,
                feasibility_status = "feasible",
                validation_status = "validated",
                incumbent_candidate = true,
                source_path = "QUBOPreprocessing.jl/strong/reconstruct(record=$rec_id)",
            )
            repaired_strong_count += 1
        end

        # Weak repair: add if strictly better than both original and strong repair
        res_w = entry.weak
        weak_certified = _is_result_certified(res_w) && weak_meta_cert
        red_state_w = [orig_state[v] for v in res_w.surviving_variables]
        capture_start_ns = time_ns()
        reconstruction_s = @elapsed rec_state_w = _reconstruct_qubopreprocessing(preprocess_module, res_w.trace, red_state_w)
        objective_evaluation_s = @elapsed rec_val_w = Float64(QUBOTools.value(model, rec_state_w))
        rec_bits_w = _state_to_bool_vector(rec_state_w, domain)

        best_so_far = _is_strictly_better_qubo(rec_val_s, orig_val, sense) ? rec_val_s : orig_val
        if _is_strictly_better_qubo(rec_val_w, best_so_far, sense)
            if isnothing(evaluator)
                evaluator = _qoblib_source_evaluator(index, inst_id; context = "preprocessing-repair-$rec_id")
            end
            source_evaluation_s = @elapsed source_eval = _qoblib_source_evaluation(
                evaluator,
                rec_bits_w;
                context = "preprocessing-repair-weak-$rec_id",
            )
            hamming_w = count(i -> orig_bits[i] != rec_bits_w[i], eachindex(orig_bits))
            rec_fa_w = _field_alignment(model, rec_state_w)
            fa_imp_w = (isnothing(rec_fa_w) || isnothing(orig_fa)) ? nothing : round(rec_fa_w - orig_fa; digits = 6)
            sol_meta = Dict{String,Any}(
                "solver"                      => QUBOPREPROCESSING_SOLVER,
                "solver_version"              => QUBOPREPROCESSING_VERSION,
                "origin"                      => "certified_solution_repair",
                "repair_package"              => QUBOPREPROCESSING_SOLVER,
                "repair_version"              => QUBOPREPROCESSING_VERSION,
                "repair_mode"                 => "weak",
                "parent_record"               => rec_id,
                "parent_solution"             => ismissing(rec[:solution]) ? nothing : Int(rec[:solution]),
                "parent_submission"           => ismissing(rec[:submission]) ? nothing : Int(rec[:submission]),
                "parent_qubo_value"           => orig_val,
                "qubo_improvement"            => rec_val_w - orig_val,
                "hamming_distance"            => hamming_w,
                "parent_field_alignment"      => orig_fa,
                "field_alignment"             => rec_fa_w,
                "field_alignment_improvement" => fa_imp_w,
                "n_init"                      => QUBOTools.dimension(model),
                "n_reduced"                   => QUBOTools.dimension(res_w.model),
                "validation_status"           => "validated",
                "preparation_run"             => res_w.diagnostics,
                "capture_clocks" => Dict(
                    "reconstruction_s" => reconstruction_s,
                    "stored_objective_evaluation_s" => objective_evaluation_s,
                    "source_evaluation_s" => source_evaluation_s,
                    "capture_before_storage_s" => (time_ns() - capture_start_ns) / 1e9,
                    "scope" => "reconstruction, objective/source evaluation and metadata; excludes SampleSet/storage",
                ),
            )
            sol = QUBOTools.SampleSet{Float64,Int}(model, [rec_state_w]; metadata = sol_meta)
            QUBOLib.add_solution!(
                index,
                inst_id,
                sol;
                submission = repair_submission,
                qubo_value = rec_val_w,
                source_value = rec_val_w,
                source_objective = source_eval.source_objective,
                source_feasible = source_eval.source_feasible,
                proven_optimal = (QUBOTools.dimension(res_w.model) == 0) && weak_certified,
                feasibility_status = "feasible",
                validation_status = "validated",
                incumbent_candidate = true,
                source_path = "QUBOPreprocessing.jl/weak/reconstruct(record=$rec_id)",
            )
            repaired_weak_count += 1
        end
    end

    return (
        exact_count = exact_count,
        repaired_strong_count = repaired_strong_count,
        repaired_weak_count = repaired_weak_count,
    )
end

