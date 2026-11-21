"""Import saved, audited Originals; never compile LPs or run preprocessing."""
module QOBLIBToQUBO

import QUBOLib
import SHA
import Pkg
import Tar
const JSON = QUBOLib.JSON
const QT = QUBOLib.QUBOTools
const COLLECTION = "qoblib_toqubo"
const SCHEMA = "qubolib-qoblib-toqubo-import-v1"
const POLYNOMIAL_SCHEMA = "qoblib-generated-exact-polynomial-v1"
const FINGERPRINT_SCHEMA = "qubolib-represented-polynomial-v1"
const QOBLIB_COMMIT = "16a166ee67c24c112551c803aab5394743b815b5"
const TOQUBO_COMMIT = "2d4b234fc40c7f9fa1a642a9ca3bf406c268b9f7"
const AUDITOR_SHA = "9fa19ac9e0c2fdd46874388f31d064dae9bc845c31f92de7763bbf7ebf066469"
const REPORT_SHA = "f539c7e04ee2ca959f328c461865a71a9a14c12bab137f46f84377698fa7baee"
const STUDY_AUTHORITY = (report_sha256 = REPORT_SHA, cohort_count = 347, original_count = 243,
    source_plan_sha256 = "a8acdd4db972f27d3b48cccf0fa729c496e43bac3d39adceff218f4f5be54113",
    license_sha256 = "b0795076b6787cb92063ffd73df82a6930705dca321b249e10a9ad5175428fff",
    upstream_readme_sha256 = "202cd438b665b0c4020b994ab94f064b5ba0dbd918e4abf85b022f1a82b2dbc1",
    attribution_inventory_sha256 = "4ccea3560bd42b2bb8ceb07d192c4a73aa8dde0dfe61eb7702913f57050d4e22")
const FILENAMES = Dict("polynomial" => "original-polynomial.jsonl", "variable_order" => "original-variable-order.json",
    "lp" => "source.lp", "audit" => "audit.json", "environment" => "environment.json",
    "case_manifest" => "case.json", "domain_transformations" => "domain-transformations.json",
    "source_order" => "lp-to-toqubo-source-order.json")
const ARTIFACTS = ("polynomial", "variable_order", "lp", "audit", "environment",
    "case_manifest", "domain_transformations", "source_order")
include("released_qoblib_authority.jl")
include("released_qoblib_public_evidence.jl")

const PUBLIC_CASE_KEYS = ("case_id", "auxiliary_row", "family", "source_formulation",
    "source_lp_git_blob_sha1", "source_lp_path", "source_snapshot_commit", "source_lp_sha256",
    "source_lp_decompressed_sha256", "source_continuous_to_integer_required")

require(ok, message) = ok || throw(ArgumentError(message))
sha(path) = open(io -> bytes2hex(SHA.sha256(io)), path, "r")
digest(value) = bytes2hex(SHA.sha256(codeunits(JSON.json(value))))

function new_json(path, value)
    require(!ispath(path) && !islink(path), "output exists: $path")
    open(path, "w") do io
        println(io, JSON.json(value, 2))
    end
end

function relative_path(root, value)
    require(value isa AbstractString && !isempty(value), "missing relative path")
    parts = split(replace(String(value), '\\' => '/'), '/')
    require(!isabspath(value) && all(p -> !(p in ("", ".", "..")), parts),
        "unsafe relative path: $value")
    path = root
    for part in parts
        path = joinpath(path, part)
        require(!islink(path), "symbolic links are not accepted: $value")
    end
    return path
end

function descriptor_path(root, descriptor)
    require(descriptor isa AbstractDict, "missing artifact descriptor")
    path = relative_path(root, descriptor["path"])
    require(isfile(path), "missing saved artifact: $(descriptor["path"])")
    require(descriptor["bytes"] isa Integer && descriptor["bytes"] >= 0 &&
        filesize(path) == descriptor["bytes"], "artifact size differs: $path")
    require(occursin(r"\A[0-9a-f]{64}\z", descriptor["sha256"]) &&
        sha(path) == descriptor["sha256"], "artifact hash differs: $path")
    return path
end

function exact(value)
    require(value isa AbstractString && sizeof(value) <= 4096 &&
        occursin(r"\A(0|-?[1-9][0-9]*)//[1-9][0-9]*\z", value),
        "coefficient must be an exact rational string")
    a, b = split(value, "//")
    q = parse(BigInt, a) // parse(BigInt, b)
    require(string(numerator(q), "//", denominator(q)) == value,
        "rational must be normalized: $value")
    return q
end

exact_text(x) = let q = Rational{BigInt}(x)
    string(numerator(q), "//", denominator(q))
end

function exact_float(value)
    q = exact(value)
    x = try
        Float64(q)
    catch
        throw(ArgumentError("coefficient is outside Float64: $value"))
    end
    require(isfinite(x) && Rational{BigInt}(x) == q,
        "coefficient is not exactly representable as Float64: $value")
    return x
end

function header(row; max_variables = 200_000)
    require(Set(keys(row)) == Set(("kind", "schema", "n", "domain", "sense",
        "scale_exact", "offset_exact", "variable_order")), "unexpected polynomial header fields")
    require(row["kind"] == "header" && row["schema"] == POLYNOMIAL_SCHEMA,
        "unsupported saved polynomial")
    n = row["n"]
    require(n isa Integer && !(n isa Bool) && 0 <= n <= max_variables, "invalid variable count")
    require(row["domain"] == "bool" && row["sense"] in ("min", "max") &&
        row["variable_order"] == "one_based_internal", "unsupported domain, sense or order")
    scale = exact_float(row["scale_exact"])
    require(scale != 0, "zero model scale is not supported")
    offset = exact_float(row["offset_exact"])
    return Int(n), scale, offset
end

function fingerprint_context(row)
    ctx = SHA.SHA2_256_CTX()
    add(parts...) = SHA.update!(ctx, codeunits(string(parts..., '\n')))
    add(FINGERPRINT_SCHEMA)
    for key in ("n", "domain", "sense", "scale_exact", "offset_exact", "variable_order")
        add(key, " ", row[key])
    end
    return ctx
end

"""Visit strict sorted JSONL terms without retaining them. A zero second index denotes a linear term."""
function scan_polynomial(visit, path; max_variables = 200_000, max_interactions = 60_000_000)
    l = m = 0
    h = nothing
    ctx = nothing
    last_l = 0
    last_q = (0, 0)
    quadratic_started = false
    n = 0; scale = 1.0; offset = 0.0
    for (line_number, line) in enumerate(eachline(path))
        require(!isempty(line) && sizeof(line) <= 16_384, "empty/oversized JSONL row")
        row = JSON.parse(line)
        require(row isa AbstractDict, "polynomial row must be an object")
        if line_number == 1
            n, scale, offset = header(row; max_variables)
            h = row; ctx = fingerprint_context(row)
            continue
        end
        kind = get(row, "kind", nothing)
        i = get(row, "i", nothing)
        require(i isa Integer && !(i isa Bool) && 1 <= i <= n, "invalid variable index")
        c = exact_float(get(row, "coefficient_exact", nothing))
        require(c != 0.0, "explicit zero terms are not canonical")
        if kind == "linear"
            require(Set(keys(row)) == Set(("kind", "i", "coefficient_exact")) &&
                !quadratic_started && i > last_l, "linear terms must be unique and sorted before quadratic terms")
            visit(Int(i), 0, c)
            l += 1; last_l = i
            SHA.update!(ctx, codeunits("linear $i $(row["coefficient_exact"])\n"))
        elseif kind == "quadratic"
            j = get(row, "j", nothing)
            require(j isa Integer && !(j isa Bool) && i < j <= n &&
                Set(keys(row)) == Set(("kind", "i", "j", "coefficient_exact")) &&
                (i, j) > last_q, "quadratic terms must be unique sorted strict upper triangle")
            require(m < max_interactions, "interaction limit exceeded")
            visit(Int(i), Int(j), c)
            m += 1; last_q = (i, j); quadratic_started = true
            SHA.update!(ctx, codeunits("quadratic $i $j $(row["coefficient_exact"])\n"))
        else
            throw(ArgumentError("unsupported polynomial row kind"))
        end
    end
    require(!isnothing(h), "empty saved polynomial")
    require(l > 0 && m > 0,
        "current QUBOLib statistics schema requires nonempty linear and quadratic coefficient groups")
    return (; h, n, l, m, scale, offset, fingerprint = bytes2hex(SHA.digest!(ctx)))
end

"""Read the exact sorted polynomial into the existing in-memory model representation."""
function read_polynomial(path; max_variables = 200_000, max_interactions = 60_000_000)
    L = Dict{Int,Float64}()
    Q = Dict{Tuple{Int,Int},Float64}()
    p = scan_polynomial(path; max_variables, max_interactions) do i, j, coefficient
        if j == 0
            L[i] = coefficient
        else
            Q[(i, j)] = coefficient
        end
    end
    model = QT.Model{Int,Float64,Int}(Set{Int}(1:p.n), L, Q;
        scale = p.scale, offset = p.offset, domain = :bool, sense = Symbol(p.h["sense"]))
    return model, p.h, p.fingerprint
end

function model_identity(model)
    h = Dict("n" => QT.dimension(model), "domain" => string(Symbol(QT.domain(model))),
        "sense" => string(Symbol(QT.sense(model))), "scale_exact" => exact_text(QT.scale(model)),
        "offset_exact" => exact_text(QT.offset(model)), "variable_order" => "one_based_internal")
    require(collect(QT.variables(model)) == collect(1:h["n"]), "stored variable order differs")
    ctx = fingerprint_context(h)
    L = sort!(collect(QT.linear_terms(model)); by = first)
    Q = sort!(collect(QT.quadratic_terms(model)); by = first)
    for (i, c) in L
        SHA.update!(ctx, codeunits("linear $i $(exact_text(c))\n"))
    end
    for ((i, j), c) in Q
        SHA.update!(ctx, codeunits("quadratic $i $j $(exact_text(c))\n"))
    end
    return Dict("schema" => FINGERPRINT_SCHEMA, "sha256" => bytes2hex(SHA.digest!(ctx)),
        "n" => h["n"], "l" => length(L), "m" => length(Q), "domain" => h["domain"],
        "sense" => h["sense"], "scale_exact" => h["scale_exact"], "offset_exact" => h["offset_exact"])
end

"""Stream the exact Study.persist_polynomial byte representation to a digest.

The fixed JSON key order and newline/text conventions reproduce the immutable
saved Original transport. This is separate from the formatting-independent
represented-polynomial fingerprint and does not retain another polynomial file.
"""
function saved_transport(emit_terms, h)
    ctx = SHA.SHA2_256_CTX()
    bytes = 0
    function emit(parts...)
        chunk = codeunits(string(parts...))
        SHA.update!(ctx, chunk)
        bytes += length(chunk)
        return nothing
    end
    emit("{\"kind\":\"header\",\"schema\":\"qoblib-generated-exact-polynomial-v1\",\"n\":", h["n"],
        ",\"domain\":\"bool\",\"sense\":", JSON.json(h["sense"]), ",\"scale_exact\":", JSON.json(h["scale_exact"]),
        ",\"offset_exact\":", JSON.json(h["offset_exact"]), ",\"variable_order\":\"one_based_internal\"}\n")
    emit_terms() do i, j, coefficient
        if j == 0
            emit("{\"kind\":\"linear\",\"i\":", i, ",\"coefficient_exact\":", JSON.json(coefficient), "}\n")
        else
            emit("{\"kind\":\"quadratic\",\"i\":", i, ",\"j\":", j,
                ",\"coefficient_exact\":", JSON.json(coefficient), "}\n")
        end
    end
    return Dict("sha256" => bytes2hex(SHA.digest!(ctx)), "bytes" => bytes)
end

function saved_polynomial_identity(model)
    require(Symbol(QT.domain(model)) == :bool, "saved Original must have binary domain")
    h = Dict("n" => QT.dimension(model), "sense" => string(Symbol(QT.sense(model))),
        "scale_exact" => exact_text(QT.scale(model)), "offset_exact" => exact_text(QT.offset(model)))
    return saved_transport(h) do emit
        for (i, value) in sort!(collect(QT.linear_terms(model)); by = first)
            emit(i, 0, exact_text(value))
        end
        for ((i, j), value) in sort!(collect(QT.quadratic_terms(model)); by = first)
            emit(i, j, exact_text(value))
        end
    end
end

function verify_saved_polynomial(entry, model)
    actual = saved_polynomial_identity(model)
    expected = entry["artifacts"]["polynomial"]
    require(actual["sha256"] == expected["sha256"] && actual["bytes"] == expected["bytes"],
        "stored model differs from immutable saved Original polynomial bytes")
    return actual
end

function validate_order(path, n)
    order = JSON.parsefile(path)["order"]
    require(order isa AbstractVector && length(order) == n, "variable-order length differs")
    indices = Int[]
    for (i, row) in enumerate(order)
        require(row["internal_index"] isa Integer && !(row["internal_index"] isa Bool) &&
            row["internal_index"] == i && row["moi_variable_index"] isa Integer &&
            !(row["moi_variable_index"] isa Bool) && row["moi_variable_index"] > 0,
            "invalid recorded variable order")
        push!(indices, row["moi_variable_index"])
    end
    require(length(Set(indices)) == n, "duplicate MOI variable labels")
    return nothing
end

function validate_manifest(path; authority = STUDY_AUTHORITY, released_authority_sha256 = nothing)
    m = JSON.parsefile(path)
    cfg = nothing
    expected_compiler = TOQUBO_COMMIT
    variant = "integer-domain"
    expected_restricted = get(authority, :restricted_count, RELEASED_RESTRICTED_COUNT)
    if m["schema"] == RELEASED_IMPORT_SCHEMA
        cfg = load_released_authority(dirname(abspath(path)), m, released_authority_sha256)
        variant = m["variant"]
        require(m["collection"] == released_collection(variant, m["size_class"]), "wrong released asset identity")
        compiler = cfg["packages"]["ToQUBO"]
        expected_compiler = compiler["commit"]
        require(m["toqubo_source_tree"] == compiler["source_tree"], "released compiler tree differs")
        authority = merge(authority, (report_sha256 = cfg["study_report_sha256"],
            source_plan_sha256 = cfg["source_plan_sha256"], original_count = authority.cohort_count))
    else
        require(m["schema"] == SCHEMA && m["collection"] == COLLECTION && isnothing(released_authority_sha256),
            "wrong generated collection schema/name")
    end
    require(m["model_role"] == "original" && m["source_decoding"] == "unavailable_no_validated_adapter" &&
        m["source_problem_equivalence"] == source_equivalence(variant) && m["solution_import"] === false,
        "Original-only import cannot transfer source decoding, equivalence or solutions")
    require(m["source_snapshot_commit"] == QOBLIB_COMMIT && m["toqubo_commit"] == expected_compiler,
        "unexpected source/compiler commit")
    require(get(m, "preparation_status", "materialized") == "materialized", "materialize saved input bytes before importing")
    require(m["study_report_sha256"] == authority.report_sha256 && m["study_cohort_count"] == authority.cohort_count &&
        m["study_audited_original_count"] == authority.original_count, "unsupported study projection")
    require(m["study_report"]["path"] == "STUDY-REPORT.jsonl" &&
        m["study_report"]["sha256"] == authority.report_sha256, "pinned study-report bytes required")
    report_path = descriptor_path(dirname(abspath(path)), m["study_report"])
    report = [JSON.parse(line) for line in eachline(report_path)]
    require(length(report) == authority.cohort_count && length(Set(r["case_id"] for r in report)) == authority.cohort_count,
        "invalid pinned source-outcome cohort")
    require(m["source_plan"]["path"] == "SOURCE-PLAN.json" &&
        m["source_plan"]["sha256"] == authority.source_plan_sha256, "pinned source plan required")
    source_plan_document = JSON.parsefile(descriptor_path(dirname(abspath(path)), m["source_plan"]))
    source_plan = source_plan_document["models"]
    redistribution = m["redistribution"]
    if cfg !== nothing
        checked = Dict(k => v for (k, v) in m if k != "redistribution")
        checked["redistribution"] = Dict(k => v for (k, v) in redistribution if k != "attributions")
        foreach(require_public_metadata, (checked, report, source_plan_document))
    end
    require(length(source_plan) == authority.cohort_count &&
        length(Set((p["family"], p["auxiliary_row"]) for p in source_plan)) == authority.cohort_count,
        "invalid pinned source-plan identity cohort")
    require(m["data_license"] == "CC-BY-4.0" && !isempty(m["attribution"]) &&
        !isempty(m["changes"]), "license, attribution and generated changes are required")
    for key in ("license", "upstream_readme", "attribution_inventory")
        require(redistribution[key]["sha256"] == getproperty(authority, Symbol(key * "_sha256")),
            "upstream redistribution evidence differs: $key")
        descriptor_path(dirname(abspath(path)), redistribution[key])
    end
    require(redistribution["license"]["path"] == "redistribution/LICENSE.data" &&
        redistribution["upstream_readme"]["path"] == "redistribution/README.upstream.md" &&
        redistribution["attribution_inventory"]["path"] == "redistribution/inventory.json",
        "unexpected public redistribution paths")
    inventory = JSON.parsefile(descriptor_path(dirname(abspath(path)), redistribution["attribution_inventory"]))
    require(length(inventory) == length(redistribution["attributions"]), "incomplete upstream attribution inventory")
    for (original, item) in zip(inventory, redistribution["attributions"])
        require(item["upstream_path"] == original["path"] &&
            item["artifact"]["path"] == "redistribution/upstream/" * original["path"] &&
            item["artifact"]["sha256"] == original["sha256"] && item["artifact"]["bytes"] == original["bytes"],
            "upstream attribution bytes differ")
        descriptor_path(dirname(abspath(path)), item["artifact"])
        cfg === nothing || require_public_attribution(item, original)
    end
    require(occursin(r"\A[A-Za-z0-9][A-Za-z0-9._+-]*\z", m["collection_version"]), "invalid collection version")
    cohort = m["cohort"]
    require(cohort isa AbstractVector && length(cohort) == authority.cohort_count, "complete source-outcome cohort required")
    ids = [x["case_id"] for x in cohort]
    require(length(Set(ids)) == length(ids), "duplicate source cohort identities")
    status_key = cfg === nothing ? "controller_status" : "p3_controller_status"
    accepted_attempt_key = cfg === nothing ? "audited_original" : "audited"
    expected_cohort = [Dict("case_id" => r["case_id"], "auxiliary_row" => r["auxiliary_row"],
        "family" => r["family"], "source_lp_path" => r["source_lp_path"],
        "source_lp_sha256" => r["source_lp_sha256"], "final_outcome" => r[status_key],
        "audited_original_available" => get(get(r, "reporting_gate", Dict()), "original_validated", false) === true)
        for r in report]
    require(cohort == expected_cohort, "source-outcome ledger differs from pinned study report")
    entries = m["models"]
    selected = [x["case_id"] for x in entries]
    require(!isempty(selected) && length(Set(selected)) == length(selected), "empty/duplicate model selection")
    eligible = Set(x["case_id"] for x in cohort if x["audited_original_available"] === true)
    require(length(eligible) == authority.original_count, "unexpected audited Original candidate count")
    plans = Dict((p["family"], p["auxiliary_row"]) => p for p in source_plan)
    if cfg === nothing
        require(m["selection_scope"] in ("pilot", "all_audited_originals"), "unknown selection scope")
        require(m["selection_scope"] != "all_audited_originals" || Set(selected) == eligible,
            "full selection omits an audited Original")
    else
        large = Set(cfg["large_case_ids"])
        require(issubset(large, eligible), "reviewed large cases are outside the pinned cohort")
        variants = Dict{String,String}()
        for row in report
            plan = plans[(row["family"], row["auxiliary_row"])]
            require(all(k -> row[k] == plan[k], ("source_lp_path", "source_lp_sha256")),
                "released report/source plan cohort differs")
            observed = released_domain_variant(plan["source_continuous_to_integer_required"])
            variants[row["case_id"]] = observed
        end
        require(count(==("continuous-to-integer"), values(variants)) == expected_restricted,
            "pinned released plan has an unexpected restricted-domain count")
        eligible = Set(id for id in eligible if variants[id] == variant &&
            ((id in large) == (m["size_class"] == "large")))
        require(m["selection_scope"] in ("released_pilot", "released_partition") &&
            (m["selection_scope"] != "released_partition" || Set(selected) == eligible),
            "released partition does not cover all pinned matching Originals")
    end
    require(all(id -> id in eligible, selected), "selected model lacks accepted Original in this asset")
    public_cases = Dict{String,Any}()
    for entry in entries
        row = only(r for r in report if r["case_id"] == entry["case_id"])
        plan = plans[(row["family"], row["auxiliary_row"])]
        require(row["reporting_gate"]["accepted"] === true &&
            row["reporting_gate"]["audit_sha256"] == entry["artifacts"]["audit"]["sha256"] &&
            row["reporting_gate"]["case_manifest_sha256"] == entry["artifacts"]["case_manifest"]["sha256"] &&
            all(row["original"][k] == entry["metrics"][k] for k in ("n", "l", "m")) &&
            row["original"]["polynomial_sha256"] == entry["artifacts"]["polynomial"]["sha256"],
            "selected Original differs from pinned study projection")
        require(entry["auxiliary_row"] == row["auxiliary_row"] && entry["family"] == row["family"] &&
            entry["source"]["path"] == row["source_lp_path"] == plan["source_lp_path"] &&
            entry["source"]["compressed_sha256"] == row["source_lp_sha256"] == plan["source_lp_sha256"] &&
            entry["artifacts"]["lp"]["sha256"] == row["source_lp_decompressed_sha256"] &&
            entry["source"]["git_blob_sha1"] == plan["source_lp_git_blob_sha1"] &&
            entry["source"]["formulation"] == plan["source_formulation"] &&
            released_domain_variant(plan["source_continuous_to_integer_required"]) == variant,
            "entry source identity differs from immutable report/source plan")
        public_cases[entry["case_id"]] = Dict{String,Any}(
            "case_id" => row["case_id"], "auxiliary_row" => row["auxiliary_row"], "family" => row["family"],
            "source_formulation" => plan["source_formulation"], "source_lp_git_blob_sha1" => plan["source_lp_git_blob_sha1"],
            "source_lp_path" => row["source_lp_path"], "source_snapshot_commit" => m["source_snapshot_commit"],
            "source_lp_sha256" => row["source_lp_sha256"], "source_lp_decompressed_sha256" => row["source_lp_decompressed_sha256"],
            "source_continuous_to_integer_required" => variant == "continuous-to-integer")
        history = [h for h in row["attempt_history"] if get(h, accepted_attempt_key, false) === true]
        require(length(history) == 1 && entry["generation"]["source_run_id"] == only(history)["source_run_id"],
            "generation origin differs from immutable accepted-attempt history")
        if cfg !== nothing
            attempt = only(history)
            gate = row["reporting_gate"]
            raw = entry["raw_reformulation_metadata"]
            require(row[status_key] in ("audited_ok", "audited_partial") && attempt["status"] == row[status_key] &&
                occursin(r"\A[A-Za-z0-9_-]+\z", attempt["attempt_tag"]) &&
                entry["generation"]["source_attempt_tag"] == attempt["attempt_tag"] &&
                gate["full_metadata_validated"] === true && sha256_text(gate["measurement_join_sha256"]) &&
                entry["generation"]["measurement_join_sha256"] == gate["measurement_join_sha256"] &&
                raw["sha256"] == gate["metadata_sha256"] && raw["bytes"] == gate["metadata_bytes"],
                "released attempt or complete metadata differs from pinned report")
            domain = entry["source_domain_transformation"]
            report_domain = row["domain_transformations"]
            require(row["reporting_gate"]["result_sha256"] == entry["native_result_sha256"] &&
                row["reporting_gate"]["environment_sha256"] == entry["artifacts"]["environment"]["sha256"] &&
                domain["variant"] == variant &&
                report_domain["sha256"] == entry["artifacts"]["domain_transformations"]["sha256"] &&
                all(k -> domain[k] == report_domain[k], ("changed_variable_count", "continuous_to_integer_count", "policy")) &&
                domain["source_domain_status"] == report_domain["source_problem_equivalence"],
                "released audit or source-domain classification differs from pinned report")
        end
        expected_attributions = [x["upstream_path"] for x in redistribution["attributions"]
            if startswith(entry["source"]["path"], dirname(x["upstream_path"]) * "/")]
        require(!isempty(expected_attributions) && entry["source"]["attribution_paths"] == expected_attributions,
            "model attribution/source-path join differs")
    end
    # Derived only from hash-pinned inputs; never trusted from manifest text or
    # serialized into the public manifest itself.
    m["_validated_public_cases"] = public_cases
    m["_released_study_authority"] = cfg
    return m
end

function validate_provenance(m, entry, a, c, e, d)
    id = entry["case_id"]
    cfg = m["_released_study_authority"]
    variant = cfg === nothing ? "integer-domain" : m["variant"]
    extra_entry_keys = cfg === nothing ? () : ("source_domain_transformation",)
    require(occursin(r"\A[a-z][a-z0-9-]*\z", id), "unsafe source identity")
    require(entry["model_role"] == "original" && entry["source_problem_equivalence"] == source_equivalence(variant),
        "derived/source-equivalence import is not supported")
    require(Set(keys(entry["artifacts"])) == Set(ARTIFACTS), "incomplete import artifact set")
    require(Set(keys(entry)) == Set(("case_id", "auxiliary_row", "family", "model_role", "source_problem_equivalence",
        "source", "generation", "native_result_sha256", "raw_reformulation_metadata", "artifacts",
        "audit_inventory_paths", "metrics", extra_entry_keys...)) && Set(keys(entry["metrics"])) == Set(("n", "l", "m")),
        "unexpected generated-entry fields")
    require(all(Set(keys(desc)) == Set(("path", "sha256", "bytes")) for desc in values(entry["artifacts"])),
        "unexpected artifact descriptor fields")
    require(all(c[k] == m["_validated_public_cases"][id][k] for k in PUBLIC_CASE_KEYS),
        "case source projection differs from immutable report/source plan")
    audit_schema = cfg === nothing ? "qoblib-missing-case-audit-v1" : "qoblib-missing-case-audit-v2"
    auditor_sha = cfg === nothing ? AUDITOR_SHA : cfg["auditor_sha256"]
    require(a["schema"] == audit_schema && a["passed"] === true &&
        a["accepted"] === true && a["original_validated"] === true && a["case_id"] == id &&
        a["auditor_sha256"] == auditor_sha, "Original audit not accepted")
    require(a["case_manifest_sha256"] == entry["artifacts"]["case_manifest"]["sha256"] &&
        a["environment_sha256"] == entry["artifacts"]["environment"]["sha256"] &&
        a["result_sha256"] == entry["native_result_sha256"], "audit/run binding differs")
    require(a["auxiliary_row"] == entry["auxiliary_row"] == c["auxiliary_row"] &&
        a["family"] == entry["family"] == c["family"] && c["case_id"] == id,
        "source row/family identity differs")
    cohort = only(x for x in m["cohort"] if x["case_id"] == id)
    require(cohort["auxiliary_row"] == entry["auxiliary_row"] && cohort["family"] == entry["family"] &&
        cohort["source_lp_path"] == c["source_lp_path"] && cohort["source_lp_sha256"] == c["source_lp_sha256"],
        "model/source-cohort join differs")
    s = entry["source"]
    require(Set(keys(s)) == Set(("repository", "path", "commit", "compressed_sha256", "git_blob_sha1",
        "formulation", "attribution_paths", "url")) && s["repository"] == "ZIB-AOPT/QOBLIB",
        "unexpected source identity fields")
    require(c["source_snapshot_commit"] == a["source_snapshot_commit"] == m["source_snapshot_commit"] &&
        c["source_lp_path"] == a["source_lp_path"] == s["path"] &&
        c["source_lp_sha256"] == a["source_lp_compressed_sha256"] == s["compressed_sha256"] &&
        c["source_lp_decompressed_sha256"] == a["source_lp_decompressed_sha256"] ==
            entry["artifacts"]["lp"]["sha256"], "source LP binding differs")
    require(s["commit"] == m["source_snapshot_commit"] &&
        s["git_blob_sha1"] == c["source_lp_git_blob_sha1"] && s["formulation"] == c["source_formulation"] &&
        s["url"] == "https://github.com/ZIB-AOPT/QOBLIB/blob/$(m["source_snapshot_commit"])/$(s["path"])",
        "source provenance URL/formulation/blob differs")
    require(e["toqubo_commit"] == m["toqubo_commit"] &&
        e["packages"]["ToQUBO"]["source_tree"] == m["toqubo_source_tree"], "compiler bytes differ")
    generation = entry["generation"]
    extra_generation_keys = cfg === nothing ? () : ("packages", "release_identity_sha256", "measurement_join_sha256", "source_attempt_tag")
    require(Set(keys(generation)) == Set(("toqubo_commit", "toqubo_source_tree", "julia_version", "source_run_id",
        "numeric_semantics", "source_decoding", extra_generation_keys...)) && generation["toqubo_commit"] == e["toqubo_commit"] &&
        generation["toqubo_source_tree"] == e["packages"]["ToQUBO"]["source_tree"] &&
        generation["julia_version"] == e["julia_version"] &&
        generation["numeric_semantics"] == "exact represented polynomial of Float64 LP parse; not exact source-decimal arithmetic" &&
        generation["source_decoding"] == m["source_decoding"], "generation provenance differs")
    if cfg === nothing
        require(d["changed_variable_count"] == 0 && d["source_problem_equivalence"] == "integer_domain_preserved" &&
            isempty(d["changed_variables"]) && c["source_continuous_to_integer_required"] === false,
            "domain-restricted sources are not frozen v1 release candidates")
    else
        validate_released_environment(e, cfg)
        native_statuses = cohort["final_outcome"] == "audited_ok" ? ("ok",) : ("ok", "partial_failure", "failed")
        require(a["native_status"] in native_statuses && a["full_metadata_validated"] === true &&
            generation["packages"] == cfg["packages"] &&
            generation["release_identity_sha256"] == cfg["release_identity_sha256"],
            "released package provenance or complete metadata differs")
        require(released_domain_projection(d, variant) == entry["source_domain_transformation"],
            "released source-domain metadata differs from audited bytes")
    end
    for key in ("polynomial", "variable_order", "domain_transformations", "source_order")
        desc = entry["artifacts"][key]
        matches = [x for x in a["inventory"] if x["sha256"] == desc["sha256"] && x["bytes"] == desc["bytes"] &&
            x["path"] == entry["audit_inventory_paths"][key] == "$id/$(FILENAMES[key])"]
        require(length(matches) == 1, "saved artifact not uniquely bound by audit: $key")
    end
    require(a["original"]["polynomial_sha256"] == entry["artifacts"]["polynomial"]["sha256"],
        "Original polynomial identity differs")
    require(all(a["original"][k] == entry["metrics"][k] for k in ("n", "l", "m")), "audit Original counts differ")
    raw_metadata = only(x for x in a["inventory"] if x["path"] == "$id/reformulation-metadata.json")
    require(entry["raw_reformulation_metadata"] == raw_metadata, "raw metadata descriptor differs from independent audit")
    if cfg !== nothing
        document = a["metadata_document_audit"]
        require(sha256_text(raw_metadata["sha256"]) && raw_metadata["bytes"] isa Integer &&
            !(raw_metadata["bytes"] isa Bool) && raw_metadata["bytes"] > 0 &&
            document["full_EOF_parsed"] === true && document["target_dimension_matches"] === true &&
            document["bytes_parsed"] == raw_metadata["bytes"],
            "released full metadata inventory binding missing")
    end
    return nothing
end

function validate_entry(root, m, entry)
    paths = Dict(key => descriptor_path(root, entry["artifacts"][key]) for key in ARTIFACTS)
    a = JSON.parsefile(paths["audit"])
    validate_provenance(m, entry, a, JSON.parsefile(paths["case_manifest"]),
        JSON.parsefile(paths["environment"]), JSON.parsefile(paths["domain_transformations"]))
    validate_order(paths["variable_order"], a["original"]["n"])
    return paths, a
end

function verify_model(entry, a, model, saved_fingerprint)
    verify_saved_polynomial(entry, model)
    actual = model_identity(model)
    require(actual["sha256"] == saved_fingerprint, "represented polynomial changed")
    require(all(actual[key] == a["original"][key] == entry["metrics"][key] for key in ("n", "l", "m")),
        "Original counts differ from independent audit")
    require(isempty(QT.solution(model)), "unexpected inherited solutions")
    return actual
end

include("stream_generated_qubin.jl")

function collection_data(m, manifest_sha256)
    metadata = Dict{String,Any}("version" => m["collection_version"], "manifest_sha256" => manifest_sha256,
        "model_role" => "original", "canonical_qoblib" => false,
        "source_problem_equivalence" => m["source_problem_equivalence"])
    name = "QOBLIB / ToQUBO generated Originals"
    if m["schema"] == RELEASED_IMPORT_SCHEMA
        name *= m["variant"] == "continuous-to-integer" ? " (continuous-to-integer variants)" : " (integer domains)"
        m["size_class"] == "large" && (name *= " (large opt-in)")
        merge!(metadata, Dict("variant" => m["variant"], "size_class" => m["size_class"],
            "release_authority_sha256" => m["release_authority"]["sha256"]))
    end
    return Dict{String,Any}("name" => name, "author" => [m["attribution"]],
        "url" => "https://github.com/ZIB-AOPT/QOBLIB", "data_license" => m["data_license"],
        "description" => m["changes"], "metadata" => metadata)
end

function instance_metadata(m, entry, identity)
    schema = m["schema"] == RELEASED_IMPORT_SCHEMA ?
        "qubolib-generated-original-lineage-v2" : "qubolib-generated-original-lineage-v1"
    return Dict{String,Any}("schema" => schema,
        "generated_import" => entry, "collection_version" => m["collection_version"],
        "model_identity" => identity, "source_decoding" => m["source_decoding"],
        "source_problem_equivalence" => entry["source_problem_equivalence"], "historical_optimum_status" => "not_audited",
        "incumbent_witness_status" => "not_audited", "source_feasibility_status" => "unknown",
        "source_optimality_status" => "unknown", "proven_optimal" => false,
        "attribution" => m["attribution"], "changes" => m["changes"])
end

function retained_provenance(destination, m, entry, public_evidence)
    prefix = joinpath("qubolib", "generated-provenance", entry["case_id"])
    paths = Dict{String,String}()
    for key in ARTIFACTS
        key in ("polynomial", "case_manifest") && continue
        public_evidence !== nothing && key in RELEASED_PRIVATE_KEYS && continue
        path = relative_path(destination, joinpath(prefix, FILENAMES[key]))
        desc = entry["artifacts"][key]
        require(isfile(path) && filesize(path) == desc["bytes"] && sha(path) == desc["sha256"],
            "stored provenance differs: $key")
        paths[key] = path
    end
    projected_path = relative_path(destination, joinpath(prefix, "case-provenance.json"))
    require(isfile(projected_path), "missing public source identity projection")
    projected = JSON.parsefile(projected_path)
    require(Set(keys(projected)) == Set(("schema", "raw_case_manifest_sha256", "scope", "source")) &&
        projected["schema"] == "qubolib-generated-public-case-provenance-v1" &&
        projected["raw_case_manifest_sha256"] == entry["artifacts"]["case_manifest"]["sha256"] &&
        projected["scope"] == "source identity projection; private operational paths omitted" &&
        projected["source"] == m["_validated_public_cases"][entry["case_id"]],
        "public source identity projection differs")
    d = JSON.parsefile(paths["domain_transformations"])
    a, e = if public_evidence === nothing
        JSON.parsefile(paths["audit"]), JSON.parsefile(paths["environment"])
    else
        evidence = public_evidence[entry["case_id"]]
        require(evidence == released_public_projection(entry, evidence["audit"], evidence["environment"]),
            "public released provenance must retain only the allowlisted fields and original hashes")
        foreach(require_public_metadata, (projected, d, JSON.parsefile(paths["source_order"]),
            JSON.parsefile(paths["variable_order"])))
        evidence["audit"], evidence["environment"]
    end
    validate_provenance(m, entry, a, projected["source"], e, d)
    validate_order(paths["variable_order"], a["original"]["n"])
    return a
end

function precheck_installed(destination)
    require(isdir(destination) && !islink(destination), "candidate root must be an existing real directory")
    lib = relative_path(destination, "qubolib")
    require(isdir(lib), "missing candidate library; audit never installs a default artifact")
    for name in ("index.db", "archive.h5")
        require(isfile(relative_path(destination, joinpath("qubolib", name))),
            "missing candidate store; audit never installs a default artifact")
    end
    require(QUBOLib.is_installed(destination), "candidate is not installed; audit never downloads or installs")
    return nothing
end

function hdf5_keys(group, names; attributes = ())
    require(Set(keys(group)) == Set(names) && Set(keys(QUBOLib.HDF5.attrs(group))) == Set(attributes),
        "unexpected HDF5 group/dataset/attribute inventory")
    for name in names
        node = group[name]
        if node isa QUBOLib.HDF5.Dataset
            require(isempty(keys(QUBOLib.HDF5.attrs(node))), "unexpected HDF5 dataset attributes")
        end
    end
    return nothing
end

function hdf5_inventory(h5, ids; compact = false)
    hdf5_keys(h5, ("instances", "solutions"))
    hdf5_keys(h5["instances"], string.(ids))
    hdf5_keys(h5["solutions"], ())
    for id in ids
        group = h5["instances"][string(id)]
        hdf5_keys(group, ("model", "solution", "source"))
        hdf5_keys(group["model"], ("variables", "form", "metadata"))
        form = group["model"]["form"]
        hdf5_keys(form, ("dimension", "linear", "quadratic", "scale", "offset", "sense", "domain");
            attributes = compact ? (QUBOLib._COMPACT_QUBIN_ATTRIBUTE,) : ())
        hdf5_keys(form["linear"], ("i", "v"))
        hdf5_keys(form["quadratic"], ("i", "j", "v"))
        solution = group["solution"]
        hdf5_keys(solution, ("data", "sense", "domain", "metadata"))
        hdf5_keys(solution["data"], ("state", "value", "reads"))
        require(size(solution["data"]["state"]) == (0, 0) &&
            prod(size(solution["data"]["value"])) == prod(size(solution["data"]["reads"])) == 0,
            "unexpected inherited HDF5 solution payload")
    end
    return nothing
end

function build(manifest_path, destination; authority = STUDY_AUTHORITY,
        stream_terms = false, released_authority_sha256 = nothing)
    manifest_path = abspath(manifest_path)
    root = dirname(manifest_path)
    m = validate_manifest(manifest_path; authority, released_authority_sha256)
    collection = m["collection"]
    require(m["schema"] != RELEASED_IMPORT_SCHEMA || m["size_class"] != "large" || stream_terms,
        "large released assets require --stream-terms")
    require(!ispath(destination) && !islink(destination), "candidate destination must be fresh")
    mkdir(destination)
    # No cross-store rollback is claimed. A failure is retained without ACCEPTED.json.
    cp(manifest_path, joinpath(destination, "IMPORT-MANIFEST.json"))
    cp(joinpath(root, "STUDY-REPORT.jsonl"), joinpath(destination, "STUDY-REPORT.jsonl"))
    cp(joinpath(root, "SOURCE-PLAN.json"), joinpath(destination, "SOURCE-PLAN.json"))
    if m["schema"] == RELEASED_IMPORT_SCHEMA
        cp(joinpath(root, RELEASED_AUTHORITY_NAME), joinpath(destination, RELEASED_AUTHORITY_NAME))
        require(sha(joinpath(destination, RELEASED_AUTHORITY_NAME)) == released_authority_sha256,
            "copied released authority differs")
    end
    redistribution = m["redistribution"]
    for desc in vcat([redistribution[k] for k in ("license", "upstream_readme", "attribution_inventory")],
                     [item["artifact"] for item in redistribution["attributions"]])
        target = relative_path(destination, desc["path"])
        mkpath(dirname(target))
        cp(descriptor_path(root, desc), target)
    end
    records = Any[]
    public_evidence = m["schema"] == RELEASED_IMPORT_SCHEMA ? Dict{String,Any}() : nothing
    try
        QUBOLib.access(; path = destination, clear = true) do index
            # The ordinary fresh-library schema seeds two empty convenience
            # collections. This isolated artifact intentionally contains only
            # generated Originals; remove those defaults after proving emptiness.
            db = QUBOLib.database(index)
            defaults = QUBOLib.DBInterface.execute(db, "SELECT collection FROM Collections") |> QUBOLib.DataFrame
            instances = QUBOLib.DBInterface.execute(db, "SELECT count(*) AS n FROM Instances") |> QUBOLib.DataFrame
            require(Set(defaults.collection) == Set(["standalone", "qubolib"]) && only(instances.n) == 0,
                "fresh candidate schema/default inventory differs")
            for name in ("standalone", "qubolib")
                QUBOLib.remove_collection!(index, name)
            end
            QUBOLib.add_collection!(index, collection, collection_data(m, sha(manifest_path)))
        end
        for entry in m["models"]
            paths, a = validate_entry(root, m, entry)
            model, identity = if stream_terms
                (nothing, nothing)
            else
                loaded, _, fingerprint = read_polynomial(paths["polynomial"])
                (loaded, verify_model(entry, a, loaded, fingerprint))
            end
            id = entry["case_id"]
            evidence_dir = joinpath(destination, "qubolib", "generated-provenance", id)
            mkpath(evidence_dir)
            if public_evidence !== nothing
                public_evidence[id] = released_public_projection(entry, a, JSON.parsefile(paths["environment"]))
            end
            # Raw compiler metadata remains hash-only; it is not an affine decoder.
            for key in ARTIFACTS
                key in ("polynomial", "case_manifest") && continue
                public_evidence !== nothing && key in RELEASED_PRIVATE_KEYS && continue
                cp(paths[key], joinpath(evidence_dir, FILENAMES[key]))
            end
            c = JSON.parsefile(paths["case_manifest"])
            new_json(joinpath(evidence_dir, "case-provenance.json"), Dict(
                "schema" => "qubolib-generated-public-case-provenance-v1",
                "raw_case_manifest_sha256" => entry["artifacts"]["case_manifest"]["sha256"],
                "scope" => "source identity projection; private operational paths omitted",
                "source" => Dict(k => c[k] for k in PUBLIC_CASE_KEYS)))
            instance, identity = QUBOLib.access(; path = destination) do index
                sql = (name = id, source_name = "QOBLIB", problem_class = entry["family"],
                    formulation = "ToQUBO generated Original ($(m["collection_version"]))",
                    source_path = entry["source"]["path"], source_commit = m["source_snapshot_commit"],
                    original_filename = basename(entry["source"]["path"]), source_url = entry["source"]["url"])
                source = (source_format = "lp", source_text = filesize(paths["lp"]) <= 1_000_000 ?
                    read(paths["lp"], String) : nothing, source_metadata = Dict(
                        "source_sha256" => entry["artifacts"]["lp"]["sha256"],
                        "source_decoding" => m["source_decoding"], "source_encoding_available" => false,
                        "data_license" => m["data_license"], "attribution" => m["attribution"]))
                if stream_terms
                    instances = QUBOLib.archive(index)["instances"]
                    pending = HDF5.create_group(instances, "pending-streamed-original")
                    try
                        p = stream_qubin!(pending, paths["polynomial"], a["original"])
                        metadata = instance_metadata(m, entry, p.identity)
                        QUBOLib._write_instance_source!(pending; source...)
                        instance = QUBOLib._insert_instance!(index, collection, p.shape,
                            p.linear_extrema, p.quadratic_extrema; sql..., metadata)
                        HDF5.move_link(instances, "pending-streamed-original", instances, string(instance))
                        return instance, p.identity
                    finally
                        close(pending)
                    end
                end
                metadata = instance_metadata(m, entry, identity)
                return QUBOLib.add_instance!(index, model, collection; sql..., source..., metadata), identity
            end
            # Close/reopen HDF5 before accepting the transport roundtrip.
            roundtrip = QUBOLib.access(; path = destination) do index
                if stream_terms
                    group = QUBOLib.archive(index)["instances"][string(instance)]
                    verified = verify_streamed_model(entry, group)
                    require(verified == identity, "represented polynomial changed")
                    verified
                else
                    loaded = QUBOLib.load_instance(index, instance)
                    verify_model(entry, a, loaded, identity["sha256"])
                end
            end
            push!(records, Dict("case_id" => id, "instance" => instance, "identity" => roundtrip,
                "polynomial_file_sha256" => entry["artifacts"]["polynomial"]["sha256"],
                "variable_order_sha256" => entry["artifacts"]["variable_order"]["sha256"]))
            model = nothing
            GC.gc(false)
        end
        build_record = Dict("schema" => "qubolib-generated-build-v1",
            "manifest_sha256" => sha(manifest_path), "importer_sha256" => sha(@__FILE__),
            "julia_version" => string(VERSION), "qubolib_version" => string(Base.pkgversion(QUBOLib)),
            "qubotools_version" => string(Base.pkgversion(QT)), "records" => records)
        if stream_terms
            build_record["polynomial_storage"] = STREAMED_STORAGE
            build_record["streamed_importer_sha256"] = sha(joinpath(@__DIR__, "stream_generated_qubin.jl"))
        end
        new_json(joinpath(destination, "BUILD.json"), build_record)
        # Independent entry point reopens and rehashes all stored coefficients.
        released_public_evidence_sha256 = public_evidence === nothing ? nothing :
            write_released_public_evidence(destination, public_evidence)
        audit(destination; authority, released_authority_sha256, released_public_evidence_sha256)
    catch err
        new_json(joinpath(destination, "FAILED.json"), Dict("schema" => "qubolib-generated-build-failure-v1",
            "error" => sprint(showerror, err), "accepted" => false))
        rethrow()
    end
    return destination
end

function audit(destination; authority = STUDY_AUTHORITY, released_authority_sha256 = nothing,
        released_public_evidence_sha256 = nothing)
    precheck_installed(destination)
    record_root = isfile(joinpath(destination, "IMPORT-MANIFEST.json")) ? destination : joinpath(destination, "qubolib")
    manifest_path = joinpath(record_root, "IMPORT-MANIFEST.json")
    m = validate_manifest(manifest_path; authority, released_authority_sha256)
    collection = m["collection"]
    public_evidence = nothing
    if m["schema"] == RELEASED_IMPORT_SCHEMA
        public_evidence = read_released_public_evidence(record_root, m, released_public_evidence_sha256)
        library = relative_path(destination, "qubolib")
        check_public_tree(library, public_library_files(m; packed = record_root == library))
    else
        require(isnothing(released_public_evidence_sha256), "released public evidence is specific to released assets")
    end
    build_record = JSON.parsefile(joinpath(record_root, "BUILD.json"))
    public_evidence === nothing || require_public_metadata(build_record)
    require(build_record["manifest_sha256"] == sha(manifest_path), "build manifest changed")
    records = build_record["records"]
    storage = get(build_record, "polynomial_storage", nothing)
    require(isnothing(storage) || storage == STREAMED_STORAGE, "unsupported generated polynomial storage")
    require(get(m, "size_class", nothing) != "large" || storage == STREAMED_STORAGE,
        "large release requires compact streamed polynomial storage")
    if storage == STREAMED_STORAGE
        importer_sha = get(build_record, "streamed_importer_sha256", nothing)
        require(importer_sha isa AbstractString && occursin(r"\A[0-9a-f]{64}\z", importer_sha),
            "missing streamed importer identity")
    end
    require(length(records) == length(m["models"]), "incomplete build")
    QUBOLib.access(; path = destination) do index
        db = QUBOLib.database(index)
        rows = QUBOLib.DBInterface.execute(db, "SELECT * FROM Instances ORDER BY instance") |> QUBOLib.DataFrame
        require(length(rows.instance) == length(records) && all(==(collection), rows.collection),
            "candidate contains unexpected models/collections")
        objects = QUBOLib.DBInterface.execute(db, "SELECT type,name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'") |> QUBOLib.DataFrame
        expected_objects = Set([("table", t) for t in ("Collections", "Instances", "Solutions", "Solvers", "Submissions", "SolutionRecords")])
        push!(expected_objects, ("view", "BestSolutions"))
        require(Set((String(r.type), String(r.name)) for r in eachrow(objects)) == expected_objects,
            "unexpected SQLite schema objects")
        collections = QUBOLib.DBInterface.execute(db, "SELECT * FROM Collections") |> QUBOLib.DataFrame
        require(collections.collection == [collection], "candidate contains unexpected collection records")
        expected_collection = collection_data(m, sha(manifest_path))
        cr = only(eachrow(collections))
        require(all(cr[Symbol(k)] == expected_collection[k] for k in ("name", "url", "data_license", "description")) &&
            cr.author == join(expected_collection["author"], " and ") && JSON.parse(cr.metadata) == expected_collection["metadata"] &&
            all(ismissing(cr[Symbol(k)]) for k in ("year", "license", "citation")), "stored collection provenance differs")
        for table in ("Solutions", "SolutionRecords", "Solvers", "Submissions")
            solutions = QUBOLib.DBInterface.execute(db, "SELECT count(*) AS n FROM $table") |> QUBOLib.DataFrame
            require(only(solutions.n) == 0, "candidate must not inherit solution/reference claims")
        end
        hdf5_inventory(QUBOLib.archive(index), rows.instance; compact = storage == STREAMED_STORAGE)
        for (entry, record, row) in zip(m["models"], records, eachrow(rows))
            require(entry["case_id"] == record["case_id"] == row.name && record["instance"] == row.instance,
                "stored source identity/order differs")
            a = retained_provenance(destination, m, entry, public_evidence)
            # BUILD and SQL metadata are mutable candidate files. Bind the model
            # directly to the report-anchored saved Original before trusting them.
            actual = if storage == STREAMED_STORAGE
                verify_streamed_model(entry, QUBOLib.archive(index)["instances"][string(row.instance)])
            else
                loaded = QUBOLib.load_instance(index, row.instance)
                verify_saved_polynomial(entry, loaded)
                require(isempty(QT.solution(loaded)) && isempty(QT.metadata(loaded)) &&
                    isempty(QT.metadata(QT.solution(loaded))), "unexpected inherited HDF5 model/solution metadata or solutions")
                model_identity(loaded)
            end
            require(actual == record["identity"], "stored represented polynomial differs")
            require(all(actual[k] == a["original"][k] for k in ("n", "l", "m")), "stored counts differ from independent audit")
            meta = JSON.parse(row.metadata)
            require(meta == instance_metadata(m, entry, actual), "stored generated lineage differs")
            require(row.source_name == "QOBLIB" && row.problem_class == entry["family"] &&
                row.source_path == entry["source"]["path"] && row.source_commit == m["source_snapshot_commit"] &&
                row.source_url == entry["source"]["url"] && row.dimension == actual["n"] &&
                row.sense == actual["sense"] && row.domain == actual["domain"] &&
                row.original_filename == basename(entry["source"]["path"]) &&
                row.formulation == "ToQUBO generated Original ($(m["collection_version"]))",
                "stored source columns/domain/sense differ")
            source = QUBOLib.archive(index)["instances"][string(row.instance)]["source"]
            hdf5_keys(source, entry["artifacts"]["lp"]["bytes"] <= 1_000_000 ? ("content",) : ();
                attributes = ("source_format", "source_sha256", "source_decoding", "source_encoding_available", "data_license", "attribution"))
            attrs = QUBOLib.HDF5.attrs(source)
            require(attrs["source_format"] == "lp" && attrs["source_sha256"] == entry["artifacts"]["lp"]["sha256"] &&
                attrs["source_decoding"] == m["source_decoding"] && attrs["source_encoding_available"] == false &&
                attrs["data_license"] == m["data_license"] && attrs["attribution"] == m["attribution"],
                "stored LP source attributes differ")
            if entry["artifacts"]["lp"]["bytes"] <= 1_000_000
                require(haskey(source, "content") &&
                    bytes2hex(SHA.sha256(codeunits(read(source["content"])))) == entry["artifacts"]["lp"]["sha256"],
                    "embedded source LP bytes differ")
            else
                require(!haskey(source, "content"), "unexpected embedded source LP")
            end
        end
    end
    accepted = Dict("schema" => "qubolib-generated-candidate-audit-v1", "passed" => true,
        "collection" => collection, "collection_version" => m["collection_version"],
        "manifest_sha256" => sha(manifest_path), "build_sha256" => sha(joinpath(record_root, "BUILD.json")),
        "instance_count" => length(records), "cohort_outcome_count" => length(m["cohort"]),
        "selection_scope" => m["selection_scope"], "study_audited_original_count" => m["study_audited_original_count"],
        "scope" => "exact represented-polynomial and source-provenance transport; no LP equivalence or solution validation")
    if m["schema"] == RELEASED_IMPORT_SCHEMA
        merge!(accepted, Dict("variant" => m["variant"], "size_class" => m["size_class"],
            "release_authority_sha256" => released_authority_sha256,
            "public_provenance_sha256" => released_public_evidence_sha256))
    end
    accepted_path = joinpath(record_root, "ACCEPTED.json")
    if isfile(accepted_path)
        require(JSON.parsefile(accepted_path) == accepted, "acceptance receipt differs")
    else
        new_json(accepted_path, accepted)
    end
    return accepted
end

function redistribution_files(m)
    r = m["redistribution"]
    files = Set(String(r[k]["path"]) for k in ("license", "upstream_readme", "attribution_inventory"))
    union!(files, (String(item["artifact"]["path"]) for item in r["attributions"]))
    return files
end

function packaged_evidence(m)
    names = ("IMPORT-MANIFEST.json", "STUDY-REPORT.jsonl", "SOURCE-PLAN.json", "BUILD.json", "ACCEPTED.json")
    return m["schema"] == RELEASED_IMPORT_SCHEMA ? (names..., RELEASED_AUTHORITY_NAME, RELEASED_PUBLIC_EVIDENCE) : names
end

function public_library_files(m; packed = false)
    files = Set(["index.db", "archive.h5"])
    for entry in m["models"]
        prefix = joinpath("generated-provenance", entry["case_id"])
        for key in ARTIFACTS
            key in ("polynomial", "case_manifest") && continue
            m["schema"] == RELEASED_IMPORT_SCHEMA && key in RELEASED_PRIVATE_KEYS && continue
            push!(files, joinpath(prefix, FILENAMES[key]))
        end
        push!(files, joinpath(prefix, "case-provenance.json"))
    end
    if packed
        union!(files, packaged_evidence(m))
        union!(files, redistribution_files(m))
    end
    return files
end

"""Fail closed on every unexpected file, empty directory, link or special node."""
function check_public_tree(root, expected_files)
    require(isdir(root) && !islink(root), "public artifact root must be a real directory")
    expected_dirs = Set{String}()
    for file in expected_files
        parent = dirname(file)
        while !isempty(parent) && parent != "."
            push!(expected_dirs, parent)
            next_parent = dirname(parent)
            require(next_parent != parent, "public inventory paths must be relative")
            parent = next_parent
        end
    end
    found_files = Set{String}()
    found_dirs = Set{String}()
    for (directory, dirs, files) in walkdir(root; follow_symlinks = false)
        for name in dirs
            path = joinpath(directory, name)
            relative = relpath(path, root)
            require(!islink(path) && isdir(path) && relative in expected_dirs,
                "unexpected public artifact directory/link: $relative")
            push!(found_dirs, relative)
        end
        for name in files
            path = joinpath(directory, name)
            relative = relpath(path, root)
            require(!islink(path) && isfile(path) && relative in expected_files,
                "unexpected public artifact file/link: $relative")
            push!(found_files, relative)
        end
    end
    require(found_files == expected_files && found_dirs == expected_dirs,
        "public artifact inventory is incomplete")
    return nothing
end

function pack(destination, output; authority = STUDY_AUTHORITY, released_authority_sha256 = nothing,
        released_public_evidence_sha256 = nothing)
    require(isfile(relative_path(destination, "ACCEPTED.json")), "pack requires an already audited candidate")
    accepted = audit(destination; authority, released_authority_sha256, released_public_evidence_sha256)
    require(!ispath(output) && !islink(output), "release output must be fresh")
    # Tar output inside its own input tree could recursively grow the archive.
    for resolve in (abspath, QUBOLib._resolved_install_path)
        dst_parts = splitpath(resolve(destination))
        out_parts = splitpath(resolve(output))
        require(length(out_parts) < length(dst_parts) || out_parts[1:length(dst_parts)] != dst_parts,
            "release output must be outside the candidate, including resolved aliases")
    end
    lib = joinpath(destination, "qubolib")
    m = validate_manifest(joinpath(destination, "IMPORT-MANIFEST.json"); authority, released_authority_sha256)
    collection = m["collection"]
    check_public_tree(lib, public_library_files(m))
    redist = Set(relpath(file, "redistribution") for file in redistribution_files(m))
    check_public_tree(joinpath(destination, "redistribution"), redist)
    mkdir(output)
    tar_path = joinpath(output, collection * ".tar")
    archive = tar_path * ".gz"
    # Only a fresh staging copy receives artifact-root lineage files. A failed
    # pack or a second pack into another fresh output never alters the candidate.
    tree = mktempdir(output; prefix = ".artifact-stage-") do stage
        staged_lib = joinpath(stage, "qubolib")
        cp(lib, staged_lib)
        for name in packaged_evidence(m)
            cp(joinpath(destination, name), joinpath(staged_lib, name))
        end
        cp(joinpath(destination, "redistribution"), joinpath(staged_lib, "redistribution"))
        check_public_tree(staged_lib, public_library_files(m; packed = true))
        staged_tree = bytes2hex(Pkg.GitTools.tree_hash(staged_lib))
        Tar.create(staged_lib, tar_path)
        run(`gzip -n $tar_path`)
        staged_tree
    end
    new_json(joinpath(output, "RELEASE-CANDIDATE.json"), merge(accepted, Dict(
        "schema" => "qubolib-generated-release-candidate-v1", "git_tree_sha1" => tree,
        "archive_sha256" => sha(archive), "archive_bytes" => filesize(archive),
        "artifact_name" => collection, "default_artifact_changed" => false,
        "publication_status" => "candidate_not_published")))
    write(joinpath(output, "Artifacts.toml.example"), """
    [$collection]
    git-tree-sha1 = "$tree"
    lazy = true
        [[$collection.download]]
        url = "REPLACE_WITH_REVIEWED_IMMUTABLE_RELEASE_URL/$(basename(archive))"
        sha256 = "$(sha(archive))"
    """)
    return archive
end

function consume_sha_option!(args, option)
    sha_option = findall(==(option), args)
    require(length(sha_option) <= 1, "use $option once")
    isempty(sha_option) && return nothing
    at = only(sha_option)
    require(at < length(args) && sha256_text(args[at + 1]), "expected a SHA-256 after $option")
    value = args[at + 1]
    deleteat!(args, at:(at + 1))
    return value
end

function main(args = ARGS)
    args = collect(args)
    released_authority_sha256 = consume_sha_option!(args, "--released-authority-sha256")
    released_public_evidence_sha256 = consume_sha_option!(args, "--public-provenance-sha256")
    require(length(args) in (2, 3, 4),
        "usage: qoblib_toqubo.jl build MANIFEST DEST [--stream-terms] | audit DEST | pack DEST OUTPUT " *
        "[--released-authority-sha256 SHA256] [--public-provenance-sha256 SHA256]")
    if args[1] == "build" && (length(args) == 3 || (length(args) == 4 && args[4] == "--stream-terms"))
        require(isnothing(released_public_evidence_sha256), "build derives public provenance from private audits")
        build(args[2], args[3]; stream_terms = length(args) == 4, released_authority_sha256)
    elseif args[1] == "audit" && length(args) == 2
        println(JSON.json(audit(args[2]; released_authority_sha256, released_public_evidence_sha256)))
    elseif args[1] == "pack" && length(args) == 3
        println(pack(args[2], args[3]; released_authority_sha256, released_public_evidence_sha256))
    else
        throw(ArgumentError("invalid importer command"))
    end
end

end # module

if abspath(PROGRAM_FILE) == (@__FILE__)
    QOBLIBToQUBO.main()
end
