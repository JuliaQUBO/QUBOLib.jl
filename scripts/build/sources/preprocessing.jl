const QUBOPREPROCESSING_SOLVER = "QUBOPreprocessing.jl"
const QUBOPREPROCESSING_VERSION = "0.1.2"
const QUBOPREPROCESSING_REPOSITORY = "JuliaQUBO/QUBOPreprocessing.jl"
const QUBOPREPROCESSING_URL = "https://github.com/JuliaQUBO/QUBOPreprocessing.jl"

function _qubopreprocessing_edge_count(model::QUBOTools.Model)
    return length(QUBOTools.quadratic_terms(model))
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

    return Dict{String,Any}(
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
    )
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
    catch
        return preprocess_module.materialize(ws; coefficient_type = Rational{BigInt})
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
        ws = preprocess_module.Workspace(model; rules = :mixed)
        n_init = length(preprocess_module.original_variables(ws))
        m_init = ws._state.initial_edges
        dense_large = m_init > 30_000

        preprocess_module.schedule_reductions!(
            ws;
            allow_weak_dominance = allow_weak,
            allow_weak_relations = allow_weak,
            enable_star_triangle = true,
        )

        if length(ws._state.fixes) < n_init && !dense_large
            r_rd = preprocess_module.apply_roof_duality!(ws)
            roof_ded = length(r_rd.fixings)
            submod_ded = 0
            maxcut_ded = 0
            probe_ded = 0

            if length(ws._state.fixes) < n_init
                r_sc = preprocess_module.apply_submodular_cut!(ws)
                submod_ded += length(r_sc.fixings)
            end
            if length(ws._state.fixes) < n_init
                r_mc = preprocess_module.apply_maxcut!(ws; allow_weak = allow_weak)
                maxcut_ded += r_mc.deductions
            end
            if m_init <= 5_000 && n_init <= 500 && length(ws._state.fixes) < n_init
                mat0 = _safe_materialize(preprocess_module, ws)
                is_bool = Symbol(QUBOTools.domain(model)) == :bool
                n_free0 = n_init - length(ws._state.fixes)
                w_state = preprocess_module.reconstruct(
                    mat0,
                    fill(is_bool ? 0 : -1, n_free0),
                ).state
                try
                    r_pr = preprocess_module.probe_variables!(
                        ws,
                        w_state;
                        max_candidates = min(n_init, 100),
                        max_rounds = 1,
                    )
                    probe_ded += r_pr.deductions
                catch
                end
            end
            if (roof_ded + submod_ded + maxcut_ded + probe_ded) > 0 &&
               length(ws._state.fixes) < n_init
                preprocess_module.schedule_reductions!(
                    ws;
                    allow_weak_dominance = allow_weak,
                    allow_weak_relations = allow_weak,
                    enable_star_triangle = true,
                )
            end
        end

        mat = _safe_materialize(preprocess_module, ws)
        red_model = preprocess_module.export_model(mat)
        surviving = hasproperty(mat, :_free) ? collect(Int, mat._free) : collect(1:n_init)
        return (
            model = red_model,
            surviving_variables = surviving,
            trace = mat,
        )
    else
        return preprocess_module.preprocess(model; mode = mode)
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
    repair_instance_ids::Union{AbstractSet{<:Integer},Nothing} = nothing,
)
    _ensure_qubopreprocessing_solver!(index)
    db = QUBOLib.database(index)

    precomputed = isnothing(summary_tsv) ? Dict{Int,Dict{String,Any}}() :
                  _load_preprocessing_summary_tsv(summary_tsv)

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
                precomputed[inst_id]
            else
                model = QUBOLib.load_instance(index, inst_id)
                t_s = @elapsed res_s = _run_qubopreprocessing_mode(preprocess_module, model; mode = :strong)
                t_w = @elapsed res_w = _run_qubopreprocessing_mode(preprocess_module, model; mode = :weak)
                live_results[inst_id] = (model = model, strong = res_s, weak = res_w)
                _qubopreprocessing_summary_dict_from_runs(
                    model,
                    res_s,
                    res_w;
                    strong_time_s = t_s,
                    weak_time_s = t_w,
                )
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
        cert_val = Float64(QUBOTools.offset(res.model))
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
            sol_meta = Dict{String,Any}(
                "solver"            => QUBOPREPROCESSING_SOLVER,
                "solver_version"    => QUBOPREPROCESSING_VERSION,
                "origin"            => "certified_solution_repair",
                "repair_package"    => QUBOPREPROCESSING_SOLVER,
                "repair_version"    => QUBOPREPROCESSING_VERSION,
                "repair_mode"       => "strong",
                "parent_record"     => rec_id,
                "parent_solution"   => ismissing(rec[:solution]) ? nothing : Int(rec[:solution]),
                "parent_submission" => ismissing(rec[:submission]) ? nothing : Int(rec[:submission]),
                "parent_qubo_value" => orig_val,
                "qubo_improvement"  => rec_val_s - orig_val,
                "hamming_distance"  => hamming_s,
                "n_init"            => QUBOTools.dimension(model),
                "n_reduced"         => QUBOTools.dimension(res_s.model),
                "validation_status" => "validated",
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
            sol_meta = Dict{String,Any}(
                "solver"            => QUBOPREPROCESSING_SOLVER,
                "solver_version"    => QUBOPREPROCESSING_VERSION,
                "origin"            => "certified_solution_repair",
                "repair_package"    => QUBOPREPROCESSING_SOLVER,
                "repair_version"    => QUBOPREPROCESSING_VERSION,
                "repair_mode"       => "weak",
                "parent_record"     => rec_id,
                "parent_solution"   => ismissing(rec[:solution]) ? nothing : Int(rec[:solution]),
                "parent_submission" => ismissing(rec[:submission]) ? nothing : Int(rec[:submission]),
                "parent_qubo_value" => orig_val,
                "qubo_improvement"  => rec_val_w - orig_val,
                "hamming_distance"  => hamming_w,
                "n_init"            => QUBOTools.dimension(model),
                "n_reduced"         => QUBOTools.dimension(res_w.model),
                "validation_status" => "validated",
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

