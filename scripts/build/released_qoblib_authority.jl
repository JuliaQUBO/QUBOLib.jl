const RELEASED_AUTHORITY_NAME = "RELEASED-STUDY-AUTHORITY.json"
const RELEASED_AUTHORITY_SCHEMA = "qubolib-released-study-authority-v1"
const RELEASED_IMPORT_SCHEMA = "qubolib-qoblib-toqubo-import-v2"
const RELEASED_OWNER_PACKAGES = Set(["ToQUBO", "QUBOPreprocessing", "PseudoBooleanOptimization"])
const RELEASED_RESTRICTED_COUNT = 22

sha256_text(s) = s isa AbstractString && occursin(r"\A[0-9a-f]{64}\z", s)
git_hash_text(s) = s isa AbstractString && occursin(r"\A[0-9a-f]{40}\z", s)

function load_released_authority(root, manifest, expected_sha)
    authority = manifest["release_authority"]
    require(sha256_text(expected_sha) && authority["path"] == RELEASED_AUTHORITY_NAME &&
        authority["sha256"] == expected_sha && authority["bytes"] isa Integer &&
        0 < authority["bytes"] <= 65_536, "expected independently pinned released study authority")
    path = descriptor_path(root, authority)
    cfg = JSON.parsefile(path)
    hash_keys = ("study_report_sha256", "source_plan_sha256", "auditor_sha256", "release_identity_sha256",
                 "project_sha256", "manifest_sha256")
    require(Set(keys(cfg)) == Set(("schema", "packages", "julia_version", "large_case_ids", hash_keys...)) &&
        cfg["schema"] == RELEASED_AUTHORITY_SCHEMA && all(k -> sha256_text(cfg[k]), hash_keys) &&
        occursin(r"\A1\.13\.[0-9]+\z", cfg["julia_version"]), "unsupported released study authority")
    packages = cfg["packages"]
    require(Set(keys(packages)) == RELEASED_OWNER_PACKAGES && packages["ToQUBO"]["version"] == "0.8.2" &&
        packages["QUBOPreprocessing"]["version"] == "0.2.2" &&
        all(p -> Set(keys(p)) == Set(("version", "source_tree", "commit")) &&
            occursin(r"\A[0-9]+\.[0-9]+\.[0-9]+\z", p["version"]) &&
            git_hash_text(p["source_tree"]) && git_hash_text(p["commit"]), values(packages)),
        "unsupported released generator packages")
    ids = cfg["large_case_ids"]
    require(ids isa AbstractVector && length(Set(ids)) == length(ids) &&
        all(id -> id isa AbstractString && occursin(r"\A[a-z][a-z0-9-]*\z", id), ids),
        "invalid reviewed large-case selection")
    return cfg
end

function released_collection(variant, size_class)
    require(variant in ("integer-domain", "continuous-to-integer") && size_class in ("regular", "large"),
        "select the source-domain variant and asset size explicitly")
    name = variant == "continuous-to-integer" ? "qoblib_toqubo_domain_restricted" : COLLECTION
    return size_class == "large" ? name * "_large" : name
end

function released_domain_variant(restricted)
    require(restricted isa Bool, "source plan lacks explicit continuous-to-integer flag")
    return restricted ? "continuous-to-integer" : "integer-domain"
end

source_equivalence(variant) = variant == "continuous-to-integer" ?
    "not_established_domain_restriction" : "not_established"

function released_domain_projection(transform, variant)
    require(variant in ("integer-domain", "continuous-to-integer"), "unsupported released source-domain variant")
    changes = transform["changed_variables"]
    require(changes isa AbstractVector && transform["changed_variable_count"] isa Integer &&
        !(transform["changed_variable_count"] isa Bool) && transform["changed_variable_count"] == length(changes) &&
        transform["bounded_continuous_approximation_used"] === false &&
        transform["policy"] in ("reject", "integerize"), "invalid audited source domain transformation")
    seen = Set{Int}()
    integerized = 0
    for row in changes
        index = row["moi_variable_index"]
        change = (row["old_domain"], row["new_domain"])
        require(index isa Integer && !(index isa Bool) && index > 0 && index ∉ seen &&
            change in (("continuous", "integer"), ("binary", "fixed_integer")),
            "unexpected or duplicate source variable domain change")
        push!(seen, index)
        integerized += change == ("continuous", "integer")
    end
    restricted = variant == "continuous-to-integer"
    status = restricted ? "not_established_domain_restriction" : "integer_domain_preserved"
    # The enabled policy can be integerize even when no continuous variables change.
    require((integerized > 0) == restricted && (!restricted || transform["policy"] == "integerize") &&
        transform["source_problem_equivalence"] == status, "audited source domain does not match the pinned variant")
    return Dict("variant" => variant, "policy" => transform["policy"], "changed_variable_count" => length(changes),
        "continuous_to_integer_count" => integerized, "source_domain_status" => status)
end

function validate_released_environment(environment, cfg)
    compiler = cfg["packages"]["ToQUBO"]
    require(environment["julia_version"] == cfg["julia_version"] && environment["toqubo_commit"] == compiler["commit"] &&
        get(environment, "registered_stack_verified", nothing) === true &&
        get(environment, "package_source_is_official_release", nothing) === true &&
        get(environment, "candidate_scope", nothing) == "private_metadata_exporter" &&
        get(environment, "candidate_released", nothing) === false &&
        all(k -> get(environment, k, nothing) == cfg[k],
            ("release_identity_sha256", "project_sha256", "manifest_sha256")),
        "case does not bind the pinned registered Julia/compiler identity")
    for (name, package) in cfg["packages"]
        observed = environment["packages"][name]
        require(observed["version"] == package["version"] && observed["source_tree"] == package["source_tree"] &&
            observed["commit"] == package["commit"], "case package differs: $name")
    end
    return nothing
end
