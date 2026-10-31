const QUBOPREPROCESSING_SOLVER = "QUBOPreprocessing.jl"
const QUBOPREPROCESSING_VERSION = "0.1.5"
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

    summary = Dict{String,Any}(
        "package"             => QUBOPREPROCESSING_SOLVER,
        "version"             => QUBOPREPROCESSING_VERSION,
        "repository"          => QUBOPREPROCESSING_REPOSITORY,
        "n_init"              => n_init,
        "m_init"              => m_init,
        "n_strong"            => n_strong,
        "m_strong"            => m_strong,
        "strong_vars_removed" => n_init - n_strong,
        "strong_edges_removed" => m_init - m_strong,
        "strong_var_red_pct"  => round(strong_var_red_pct; digits = 4),
        "strong_edge_red_pct" => round(strong_edge_red_pct; digits = 4),
        "strong_certified"    => true,
        "strong_time_s"       => round(Float64(strong_time_s); digits = 4),
        "n_weak"              => n_weak,
        "m_weak"              => m_weak,
        "weak_vars_removed"   => n_init - n_weak,
        "weak_edges_removed"  => m_init - m_weak,
        "weak_var_red_pct"    => round(weak_var_red_pct; digits = 4),
        "weak_edge_red_pct"   => round(weak_edge_red_pct; digits = 4),
        "weak_certified"      => true,
        "weak_time_s"         => round(Float64(weak_time_s); digits = 4),
        "coercive_fields"     => _coercive_field_summary_dict(model),
    )
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
            "version"              => QUBOPREPROCESSING_VERSION,
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

function _safe_materialize(preprocess_module::Module, ws)
    try
        return preprocess_module.materialize(ws; coefficient_type = Float64)
    catch e
        if e isa InexactError || e isa OverflowError || e isa ArgumentError
            return preprocess_module.materialize(ws; coefficient_type = Rational{BigInt})
        end
        rethrow()
    end
end

function _run_qubopreprocessing_mode(
    preprocess_module::Module,
    model::QUBOTools.Model;
    mode::Symbol = :strong,
)
    if isdefined(preprocess_module, :Workspace) &&
       isdefined(preprocess_module, :schedule_reductions!) &&
       isdefined(preprocess_module, :materialize)
        allow_weak = (mode == :weak)
        ws = try
            preprocess_module.Workspace(model; rules = :mixed, integerize_scale = true, max_decimals = 14)
        catch e
            e isa MethodError || rethrow()
            preprocess_module.Workspace(model; rules = :mixed)
        end
        n_init = length(preprocess_module.original_variables(ws))
        m_init = ws._state.initial_edges
        dense_large = m_init > 10_000 && n_init > 500
        rel_budget = n_init <= 500 ? typemax(Int) : (m_init > 15_000 ? 25_000 : (m_init > 5_000 ? 75_000 : typemax(Int)))
        use_blocks = isdefined(preprocess_module, :apply_block_equivalence!) && n_init <= 1_500 && m_init <= 10_000

        has_blocks = isdefined(preprocess_module, :apply_block_equivalence!)
        r1 = if has_blocks
            preprocess_module.schedule_reductions!(
                ws;
                allow_weak_dominance = allow_weak,
                allow_weak_relations = allow_weak,
                enable_star_triangle = true,
                enable_blocks = use_blocks,
                relation_work_budget = rel_budget,
            )
        else
            preprocess_module.schedule_reductions!(
                ws;
                allow_weak_dominance = allow_weak,
                allow_weak_relations = allow_weak,
                enable_star_triangle = true,
                relation_work_budget = rel_budget,
            )
        end
        dom_ded = r1.dominance_deductions
        elim_ded = r1.elimination_deductions
        star_ded = r1.star_triangle_deductions
        rel_ded = r1.relation_deductions
        fill_edges = r1.fill_edges
        roof_ded = 0
        submod_ded = 0
        maxcut_ded = 0
        probe_ded = 0

        max_outer_rounds = (m_init <= 5_000 && n_init <= 500) ? 8 : 1
        post_probe_ded = 0
        for iter in 1:max_outer_rounds
            (length(ws._state.fixes) < n_init && !dense_large) || break
            round_ded = 0

            r_rd = preprocess_module.apply_roof_duality!(ws)
            rd_new = length(r_rd.fixings)
            roof_ded += rd_new
            round_ded += rd_new

            if length(ws._state.fixes) < n_init
                r_sc = preprocess_module.apply_submodular_cut!(ws)
                sc_new = length(r_sc.fixings)
                submod_ded += sc_new
                round_ded += sc_new
            end
            if length(ws._state.fixes) < n_init
                r_mc = preprocess_module.apply_maxcut!(ws; allow_weak = allow_weak)
                maxcut_ded += r_mc.deductions
                round_ded += r_mc.deductions
                fill_edges += r_mc.fill_edges
            end
            if round_ded > 0 && length(ws._state.fixes) < n_init
                r2 = if has_blocks
                    preprocess_module.schedule_reductions!(
                        ws;
                        allow_weak_dominance = allow_weak,
                        allow_weak_relations = allow_weak,
                        enable_star_triangle = true,
                        enable_blocks = use_blocks,
                        relation_work_budget = rel_budget,
                    )
                else
                    preprocess_module.schedule_reductions!(
                        ws;
                        allow_weak_dominance = allow_weak,
                        allow_weak_relations = allow_weak,
                        enable_star_triangle = true,
                        relation_work_budget = rel_budget,
                    )
                end
                dom_ded += r2.dominance_deductions
                elim_ded += r2.elimination_deductions
                star_ded += r2.star_triangle_deductions
                rel_ded += r2.relation_deductions
                fill_edges += r2.fill_edges
            end
            if iter > 1 && round_ded == 0 && post_probe_ded == 0
                break
            end
            pr_new = 0
            post_probe_ded = 0
            if m_init <= 5_000 && n_init <= 500 && length(ws._state.fixes) < n_init
                if isdefined(preprocess_module, :coercive_field_witness)
                    r_pr = preprocess_module.probe_variables!(
                        ws;
                        max_candidates = min(n_init, 100),
                        max_rounds = n_init <= 100 ? 8 : 1,
                        max_trial_fixes = n_init <= 100 ? 512 : 64,
                        max_work = n_init <= 100 ? 2_000_000 : 100_000,
                        max_exact_work = n_init <= 100 ? 2_000_000 : 100_000,
                        order = :coercive,
                    )
                    pr_new = r_pr.deductions
                else
                    mat0 = _safe_materialize(preprocess_module, ws)
                    red_m0 = preprocess_module.export_model(mat0)
                    h0, _, _ = _exact_ising_fields_and_couplings(red_m0)
                    is_bool = Symbol(QUBOTools.domain(model)) == :bool
                    low_val = is_bool ? 0 : -1
                    dir = Symbol(QUBOTools.sense(model)) == :max ? -1 : 1
                    free0 = Int[
                        iszero(h0[k]) ? low_val : ((dir * h0[k] > 0) ? low_val : 1) for
                        k in eachindex(h0)
                    ]
                    w_state = _reconstruct_qubopreprocessing(preprocess_module, mat0, free0)
                    r_pr = preprocess_module.probe_variables!(
                        ws,
                        w_state;
                        max_candidates = min(n_init, 100),
                        max_rounds = 1,
                        max_trial_fixes = 64,
                        max_work = 100_000,
                        max_exact_work = 100_000,
                    )
                    pr_new = r_pr.deductions
                end
                probe_ded += pr_new
                round_ded += pr_new
            end
            if pr_new > 0 && length(ws._state.fixes) < n_init
                r3 = if has_blocks
                    preprocess_module.schedule_reductions!(
                        ws;
                        allow_weak_dominance = allow_weak,
                        allow_weak_relations = allow_weak,
                        enable_star_triangle = true,
                        enable_blocks = use_blocks,
                        relation_work_budget = rel_budget,
                    )
                else
                    preprocess_module.schedule_reductions!(
                        ws;
                        allow_weak_dominance = allow_weak,
                        allow_weak_relations = allow_weak,
                        enable_star_triangle = true,
                        relation_work_budget = rel_budget,
                    )
                end
                dom_ded += r3.dominance_deductions
                elim_ded += r3.elimination_deductions
                star_ded += r3.star_triangle_deductions
                rel_ded += r3.relation_deductions
                fill_edges += r3.fill_edges
                post_probe_ded =
                    r3.dominance_deductions +
                    r3.elimination_deductions +
                    r3.star_triangle_deductions +
                    r3.relation_deductions
                round_ded += post_probe_ded
            end
            round_ded > 0 || break
        end

        mat = _safe_materialize(preprocess_module, ws)
        red_model = preprocess_module.export_model(mat)
        surviving = hasproperty(mat, :_free) ? collect(Int, mat._free) : collect(1:n_init)
        rules = Dict{String,Any}(
            "dominance"   => dom_ded,
            "elimination" => elim_ded,
            "star"        => star_ded,
            "relations"   => rel_ded,
            "roof"        => roof_ded,
            "submodular"  => submod_ded,
            "maxcut"      => maxcut_ded,
            "probing"     => probe_ded,
            "fill_edges"  => fill_edges,
        )
        return (
            model = red_model,
            surviving_variables = surviving,
            trace = mat,
            rules = rules,
        )
    else
        return try
            preprocess_module.preprocess(model; mode = mode, integerize_scale = true)
        catch e
            e isa MethodError || rethrow()
            preprocess_module.preprocess(model; mode = mode)
        end
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

function enrich_preprocessing!(
    index::QUBOLib.LibraryIndex,
    preprocess_module::Module;
    summary_tsv::Union{AbstractString,Nothing} = nothing,
    coercive_tsv::Union{AbstractString,Nothing} = nothing,
    repair_instance_ids::Union{AbstractSet{<:Integer},Nothing} = nothing,
)
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
        ORDER BY instance;
        """,
    ) |> QUBOLib.DataFrame

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

            prep_info = if haskey(precomputed, inst_id)
                info = copy(precomputed[inst_id])
                if haskey(precomputed_coercive, inst_id)
                    info["coercive_fields"] = precomputed_coercive[inst_id]
                elseif !haskey(info, "coercive_fields")
                    model_c = QUBOLib.load_instance(index, inst_id)
                    info["coercive_fields"] = _coercive_field_summary_dict(model_c)
                end
                info
            else
                model = QUBOLib.load_instance(index, inst_id)
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

            meta["n_strong"] = Int(prep_info["n_strong"])
            meta["m_strong"] = Int(prep_info["m_strong"])
            meta["n_weak"] = Int(prep_info["n_weak"])
            meta["m_weak"] = Int(prep_info["m_weak"])
            meta["preprocessing"] = prep_info

            if Int(prep_info["n_strong"]) == 0 || Int(prep_info["n_weak"]) == 0
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
            "date"            => "2026-10-28",
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
            "date"            => "2026-10-28",
        ),
    )

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
        mode_sym = QUBOTools.dimension(entry.strong.model) == 0 ? :strong : :weak
        res = mode_sym == :strong ? entry.strong : entry.weak

        state_domain = _reconstruct_qubopreprocessing(preprocess_module, res.trace, Int[])
        state_bool = _state_to_bool_vector(state_domain, domain)
        qubo_val = Float64(QUBOTools.value(model, state_domain))
        cert_val = Float64(QUBOTools.scale(res.model)) * Float64(QUBOTools.offset(res.model))
        if !isapprox(qubo_val, cert_val; rtol = 1e-8, atol = 1e-8)
            error(
                "[preprocessing] Certified offset ($cert_val) != evaluated QUBO value ($qubo_val) on instance $inst_id",
            )
        end

        evaluator = _qoblib_source_evaluator(index, inst_id; context = "preprocessing-exact-$inst_id")
        source_eval = _qoblib_source_evaluation(
            evaluator,
            state_bool;
            context = "preprocessing-exact-$inst_id",
        )

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

        # Strong repair
        res_s = entry.strong
        red_state_s = [orig_state[v] for v in res_s.surviving_variables]
        rec_state_s = _reconstruct_qubopreprocessing(preprocess_module, res_s.trace, red_state_s)
        rec_val_s = Float64(QUBOTools.value(model, rec_state_s))
        rec_bits_s = _state_to_bool_vector(rec_state_s, domain)

        evaluator = nothing
        if _is_strictly_better_qubo(rec_val_s, orig_val, sense)
            evaluator = _qoblib_source_evaluator(index, inst_id; context = "preprocessing-repair-$rec_id")
            source_eval = _qoblib_source_evaluation(
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
                proven_optimal = QUBOTools.dimension(res_s.model) == 0,
                feasibility_status = "feasible",
                validation_status = "validated",
                incumbent_candidate = true,
                source_path = "QUBOPreprocessing.jl/strong/reconstruct(record=$rec_id)",
            )
            repaired_strong_count += 1
        end

        # Weak repair: add if strictly better than both original and strong repair
        res_w = entry.weak
        red_state_w = [orig_state[v] for v in res_w.surviving_variables]
        rec_state_w = _reconstruct_qubopreprocessing(preprocess_module, res_w.trace, red_state_w)
        rec_val_w = Float64(QUBOTools.value(model, rec_state_w))
        rec_bits_w = _state_to_bool_vector(rec_state_w, domain)

        best_so_far = _is_strictly_better_qubo(rec_val_s, orig_val, sense) ? rec_val_s : orig_val
        if _is_strictly_better_qubo(rec_val_w, best_so_far, sense)
            if isnothing(evaluator)
                evaluator = _qoblib_source_evaluator(index, inst_id; context = "preprocessing-repair-$rec_id")
            end
            source_eval = _qoblib_source_evaluation(
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
                proven_optimal = QUBOTools.dimension(res_w.model) == 0,
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

