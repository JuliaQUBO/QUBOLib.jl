"""Explicit released-cohort authority and asset selection for the QOBLIB importer."""
import hashlib
import json
from pathlib import Path
import re

AUTHORITY_NAME = "RELEASED-STUDY-AUTHORITY.json"
AUTHORITY_SCHEMA = "qubolib-released-study-authority-v1"
IMPORT_SCHEMA = "qubolib-qoblib-toqubo-import-v2"
OWNER_PACKAGES = {"ToQUBO", "QUBOPreprocessing", "PseudoBooleanOptimization"}
COHORT_COUNT = 347
RESTRICTED_COUNT = 22
VARIANTS = {"integer-domain", "continuous-to-integer"}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def is_sha(value, count=64):
    return isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{count}}}", value) is not None


def read_authority(path, sha256):
    path = Path(path)
    require(is_sha(sha256) and path.is_file() and not path.is_symlink()
            and path.stat().st_size <= 65536, "expected a separately pinned released study authority")
    body = path.read_bytes()
    require(hashlib.sha256(body).hexdigest() == sha256, "released study authority SHA-256 differs")
    value = json.loads(body)
    hash_keys = ("study_report_sha256", "source_plan_sha256", "auditor_sha256", "release_identity_sha256",
                 "project_sha256", "manifest_sha256")
    require(set(value) == {"schema", "packages", "julia_version", "large_case_ids", *hash_keys}
            and value["schema"] == AUTHORITY_SCHEMA and all(is_sha(value[k]) for k in hash_keys)
            and re.fullmatch(r"1\.13\.[0-9]+", value["julia_version"]),
            "unsupported released study authority")
    packages = value["packages"]
    require(set(packages) == OWNER_PACKAGES and packages["ToQUBO"]["version"] == "0.8.2"
            and packages["QUBOPreprocessing"]["version"] == "0.2.2"
            and all(set(p) == {"version", "source_tree", "commit"} and
                    re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", p["version"])
                    and is_sha(p["source_tree"], 40) and is_sha(p["commit"], 40)
                    for p in packages.values()), "invalid released generator packages")
    ids = value["large_case_ids"]
    require(isinstance(ids, list) and len(ids) == len(set(ids)) and
            all(re.fullmatch(r"[a-z][a-z0-9-]*", case_id) for case_id in ids),
            "invalid reviewed large-case selection")
    return value


def collection(variant, size_class):
    require(variant in VARIANTS and size_class in {"regular", "large"},
            "select the source-domain variant and asset size explicitly")
    result = "qoblib_toqubo_domain_restricted" if variant == "continuous-to-integer" else "qoblib_toqubo"
    return result + "_large" if size_class == "large" else result


def domain_variant(restricted):
    require(type(restricted) is bool, "source plan lacks explicit continuous-to-integer flag")
    return "continuous-to-integer" if restricted else "integer-domain"


def domain_projection(transform, variant):
    require(variant in VARIANTS, "unsupported released source-domain variant")
    changes = transform["changed_variables"]
    require(type(transform["changed_variable_count"]) is int and isinstance(changes, list) and
            transform["changed_variable_count"] == len(changes)
            and transform["bounded_continuous_approximation_used"] is False and
            transform["policy"] in ("reject", "integerize"), "invalid audited source domain transformation")
    seen = set()
    integerized = 0
    for row in changes:
        index = row["moi_variable_index"]
        change = (row["old_domain"], row["new_domain"])
        require(type(index) is int and index > 0 and index not in seen and
                change in {("continuous", "integer"), ("binary", "fixed_integer")},
                "unexpected or duplicate source variable domain change")
        seen.add(index)
        integerized += change == ("continuous", "integer")
    restricted = variant == "continuous-to-integer"
    expected = "not_established_domain_restriction" if restricted else "integer_domain_preserved"
    # The enabled policy can be integerize even when no continuous variables change.
    require((integerized > 0) == restricted and (not restricted or transform["policy"] == "integerize")
            and transform["source_problem_equivalence"] == expected,
            "audited source domain does not match the pinned variant")
    return {"variant": variant, "policy": transform["policy"], "changed_variable_count": len(changes),
            "continuous_to_integer_count": integerized, "source_domain_status": expected}


def validate_environment(environment, authority):
    compiler = authority["packages"]["ToQUBO"]
    require(environment["julia_version"] == authority["julia_version"] and
            environment["toqubo_commit"] == compiler["commit"] and
            environment.get("registered_stack_verified") is True and
            environment.get("package_source_is_official_release") is True and
            environment.get("candidate_scope") == "private_metadata_exporter" and
            environment.get("candidate_released") is False and
            all(environment.get(k) == authority[k] for k in
                ("release_identity_sha256", "project_sha256", "manifest_sha256")),
            "case does not bind the pinned registered Julia/compiler identity")
    for name, package in authority["packages"].items():
        actual = environment["packages"][name]
        require(actual["version"] == package["version"] and actual["source_tree"] == package["source_tree"]
                and actual["commit"] == package["commit"], "case package differs: " + name)
