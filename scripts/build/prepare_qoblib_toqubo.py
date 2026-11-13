#!/usr/bin/env python3
"""Metadata-only plan/materializer for the frozen 243-Original study export.

No LP parsing, compilation, preprocessing, solver or polynomial evaluation.
FETCH-PRIVATE.json is operational input and must not be published.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil

REPORT_SHA256 = "f539c7e04ee2ca959f328c461865a71a9a14c12bab137f46f84377698fa7baee"
SOURCE_PLAN_SHA256 = "a8acdd4db972f27d3b48cccf0fa729c496e43bac3d39adceff218f4f5be54113"
QOBLIB_COMMIT = "16a166ee67c24c112551c803aab5394743b815b5"
TOQUBO_COMMIT = "2d4b234fc40c7f9fa1a642a9ca3bf406c268b9f7"
AUDITOR_SHA = "9fa19ac9e0c2fdd46874388f31d064dae9bc845c31f92de7763bbf7ebf066469"
TOQUBO_TREE = "254322db6dd588ba427624b557fe0d35f0c3ff55"
REDISTRIBUTION_PINS = {
    "license": "b0795076b6787cb92063ffd73df82a6930705dca321b249e10a9ad5175428fff",
    "upstream_readme": "202cd438b665b0c4020b994ab94f064b5ba0dbd918e4abf85b022f1a82b2dbc1",
    "attribution_inventory": "4ccea3560bd42b2bb8ceb07d192c4a73aa8dde0dfe61eb7702913f57050d4e22",
}
NAMES = {
    "polynomial": "original-polynomial.jsonl",
    "variable_order": "original-variable-order.json",
    "domain_transformations": "domain-transformations.json",
    "source_order": "lp-to-toqubo-source-order.json",
}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as src:
        for chunk in iter(lambda: src.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text())


def descriptor(path):
    p = Path(path)
    require(p.is_file() and not p.is_symlink(), "missing/linked metadata: " + str(p))
    return {"sha256": sha(p), "bytes": p.stat().st_size}


def pinned_report(path):
    require(sha(path) == REPORT_SHA256, "only the approved final study projection is supported")
    rows = [json.loads(x) for x in Path(path).read_text().splitlines() if x]
    require(len(rows) == 347 and len({r["case_id"] for r in rows}) == 347,
            "expected all 347 unique source outcomes")
    available = [r for r in rows if r.get("reporting_gate", {}).get("original_validated") is True]
    require(len(available) == 243, "expected 243 audited Originals")
    for r in available:
        require(r["reporting_gate"]["accepted"] is True and r["original"] is not None,
                "Original availability gate disagrees")
        require(r["domain_transformations"]["changed_variable_count"] == 0 and
                r["domain_transformations"]["source_problem_equivalence"] == "integer_domain_preserved",
                "domain-restricted source is not a release candidate")
    return rows, available


def assignments(values):
    result = {}
    for value in values:
        key, sep, path = value.partition("=")
        require(sep and key and key not in result and path, "use unique RUN_ID=PATH mappings")
        require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", key), "unsafe RUN_ID")
        result[key] = Path(path)
    return result


def prepare(report, roots, remote_roots, destination, version, case_ids=(), materialize=False,
            max_bytes=8 * 1024**3, attribution_root=None, license_path=None, upstream_readme=None,
            source_plan=None):
    require(isinstance(version, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", version),
            "unsafe collection version")
    require(type(max_bytes) is int and max_bytes > 0, "positive materialization byte budget required")
    for run_id in set(roots) | set(remote_roots):
        require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", run_id), "unsafe RUN_ID")
    rows, available = pinned_report(report)
    require(source_plan is not None and descriptor(source_plan)["sha256"] == SOURCE_PLAN_SHA256,
            "pinned source identity plan required")
    plan_rows = read_json(source_plan)["models"]
    require(len(plan_rows) == 347 and len({r["auxiliary_row"] for r in plan_rows}) == 347,
            "source plan needs all unique cohort rows")
    plan_by_row = {int(r["auxiliary_row"]): r for r in plan_rows}
    selected = set(case_ids)
    require(not selected or selected <= {r["case_id"] for r in available}, "unknown/unavailable pilot source")
    models = []
    fetches = {}
    out = Path(destination)
    require(not out.exists() and not out.is_symlink(), "plan destination must be fresh")
    out.mkdir()
    require(attribution_root and license_path and upstream_readme, "pinned attribution/license inputs required")
    attribution_root = Path(attribution_root)
    inventory_path = attribution_root / "inventory.json"
    inventory = read_json(inventory_path)
    redistribution = {"attributions": []}
    for key, source, relative in (
        ("license", Path(license_path), "redistribution/LICENSE.data"),
        ("upstream_readme", Path(upstream_readme), "redistribution/README.upstream.md"),
        ("attribution_inventory", inventory_path, "redistribution/inventory.json"),
    ):
        desc = descriptor(source)
        require(desc["sha256"] == REDISTRIBUTION_PINS[key], "pinned upstream redistribution input differs: " + key)
        redistribution[key] = dict(desc, path=relative)
        target = out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    for original in inventory:
        source = attribution_root / original["path"]
        desc = descriptor(source)
        require(desc["sha256"] == original["sha256"] and desc["bytes"] == original["bytes"],
                "upstream attribution payload differs")
        relative = "redistribution/upstream/" + original["path"]
        target = out / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        redistribution["attributions"].append({"upstream_path": original["path"],
            "source_url": "https://github.com/ZIB-AOPT/QOBLIB/blob/" + QOBLIB_COMMIT + "/" + original["path"],
            "artifact": dict(desc, path=relative), "attribution_lines": original["attribution_lines"]})

    def add_artifact(key, desc, local, remote):
        suffix = ".jsonl" if key == "polynomial" else ".lp" if key == "lp" else ".json"
        relative = "inputs/" + desc["sha256"] + suffix
        result = dict(desc, path=relative)
        # All absolute/operator paths are confined to this private file.
        item = {"destination": relative, "sha256": desc["sha256"], "bytes": desc["bytes"],
                "local_source": str(local), "remote_source": str(remote)}
        if relative in fetches:
            previous = fetches[relative]
            require(previous["sha256"] == item["sha256"] and
                    (previous["bytes"] is None or item["bytes"] is None or
                     previous["bytes"] == item["bytes"]), "conflicting shared body")
            if previous["bytes"] is None:
                previous["bytes"] = item["bytes"]
            prior_path = Path(previous["local_source"])
            if not (prior_path.is_file() and not prior_path.is_symlink()) and local.is_file() and not local.is_symlink():
                previous["local_source"] = str(local)
                previous["remote_source"] = str(remote)
        else:
            fetches[relative] = item
        return result

    for r in available:
        case_id = r["case_id"]
        if selected and case_id not in selected:
            continue
        matches = []
        for run_id, root in roots.items():
            case_dir = root / "cases" / case_id
            path = case_dir / "audit.json"
            if path.is_file() and sha(path) == r["reporting_gate"]["audit_sha256"]:
                matches.append((run_id, case_dir, path))
        require(len(matches) == 1, "audit origin absent/ambiguous for " + case_id)
        run_id, case_dir, audit_path = matches[0]
        remote_case = remote_roots.get(run_id, roots[run_id]) / "cases" / case_id
        audit = read_json(audit_path)
        require(audit["passed"] is True and audit["accepted"] is True and
                audit["original_validated"] is True and audit["case_id"] == case_id and
                audit["auditor_sha256"] == AUDITOR_SHA, "unaccepted Original audit")
        require(audit["original"]["polynomial_sha256"] == r["original"]["polynomial_sha256"] and
                audit["result_sha256"] == r["reporting_gate"]["result_sha256"], "report/audit mismatch")
        artifacts = {}
        inventory_paths = {}
        for key, filename in NAMES.items():
            inventory_path = case_id + "/" + filename
            found = [x for x in audit["inventory"] if x["path"] == inventory_path]
            require(len(found) == 1, "missing unique inventory entry " + inventory_path)
            artifacts[key] = add_artifact(key, {k: found[0][k] for k in ("sha256", "bytes")},
                case_dir / "results" / inventory_path, remote_case / "results" / inventory_path)
            inventory_paths[key] = inventory_path
        for key, local, remote, expected in (
            ("audit", audit_path, remote_case / "audit.json", r["reporting_gate"]["audit_sha256"]),
            ("case_manifest", case_dir / "input/case.json", remote_case / "input/case.json",
             audit["case_manifest_sha256"]),
            ("environment", case_dir / "results/environment.json", remote_case / "results/environment.json",
             audit["environment_sha256"]),
        ):
            desc = descriptor(local)
            require(desc["sha256"] == expected, "metadata identity differs: " + key)
            artifacts[key] = add_artifact(key, desc, local, remote)
        case = read_json(case_dir / "input/case.json")
        env = read_json(case_dir / "results/environment.json")
        plan_row = plan_by_row[int(r["auxiliary_row"])]
        require(plan_row["family"] == r["family"] and
                plan_row["source_lp_path"] == r["source_lp_path"] and
                plan_row["source_lp_sha256"] == r["source_lp_sha256"] and
                all(case[k] == plan_row[k] for k in ("source_lp_git_blob_sha1", "source_formulation",
                                                     "source_continuous_to_integer_required")),
                "source identity differs from pinned plan")
        require(case["case_id"] == case_id and case["source_snapshot_commit"] == QOBLIB_COMMIT and
                case["source_lp_path"] == r["source_lp_path"] and
                case["source_continuous_to_integer_required"] is False and
                env["toqubo_commit"] == TOQUBO_COMMIT and
                env["packages"]["ToQUBO"]["source_tree"] == TOQUBO_TREE,
                "source/compiler provenance differs")
        # LP size is supplied by the controller's independently bound acquisition
        # receipt; if missing locally, the frozen source census/LP metrics are not
        # substitutes for byte size. The case input LP may be available remotely.
        lp = case_dir / "input/source.lp"
        lp_bytes = None
        if lp.exists() or lp.is_symlink():
            require(lp.is_file() and not lp.is_symlink() and
                    sha(lp) == r["source_lp_decompressed_sha256"], "retained source LP differs/linked")
            lp_bytes = lp.stat().st_size
        if lp_bytes is None:
            for acquisition_name in ("source-identity.json", "source-acquisition.json", "decompression.json"):
                acquisition_path = case_dir / acquisition_name
                if acquisition_path.is_file():
                    acquisition = read_json(acquisition_path)
                    lp_bytes = acquisition.get("decompressed_bytes", acquisition.get("source_lp_decompressed_bytes"))
                    if lp_bytes is not None:
                        break
        require(lp_bytes is None or (type(lp_bytes) is int and lp_bytes >= 0), "invalid source LP byte count")
        # The SHA is authoritative. A metadata-only plan can record an unknown
        # size; materialize fills it only after hashing the exact saved LP bytes.
        artifacts["lp"] = add_artifact("lp", {"sha256": r["source_lp_decompressed_sha256"], "bytes": lp_bytes},
            lp, remote_case / "input/source.lp")
        models.append({
            "case_id": case_id, "auxiliary_row": r["auxiliary_row"], "family": r["family"],
            "model_role": "original", "source_problem_equivalence": "not_established",
            "source": {"repository": "ZIB-AOPT/QOBLIB", "path": r["source_lp_path"],
                "commit": QOBLIB_COMMIT, "compressed_sha256": r["source_lp_sha256"],
                "git_blob_sha1": case["source_lp_git_blob_sha1"],
                "formulation": case["source_formulation"],
                "attribution_paths": [x["upstream_path"] for x in redistribution["attributions"]
                    if r["source_lp_path"].startswith(str(PurePosixPath(x["upstream_path"]).parent) + "/")],
                "url": "https://github.com/ZIB-AOPT/QOBLIB/blob/" + QOBLIB_COMMIT + "/" + r["source_lp_path"]},
            "generation": {"toqubo_commit": TOQUBO_COMMIT,
                "toqubo_source_tree": env["packages"]["ToQUBO"]["source_tree"],
                "julia_version": env["julia_version"], "source_run_id": run_id,
                "numeric_semantics": "exact represented polynomial of Float64 LP parse; not exact source-decimal arithmetic",
                "source_decoding": "unavailable_no_validated_adapter"},
            "native_result_sha256": audit["result_sha256"],
            "raw_reformulation_metadata": next(({k: x[k] for k in ("path", "sha256", "bytes")}
                for x in audit["inventory"] if x["path"] == case_id + "/reformulation-metadata.json"), None),
            "artifacts": artifacts, "audit_inventory_paths": inventory_paths,
            "metrics": {k: r["original"][k] for k in ("n", "l", "m")},
        })
    require(models, "empty import selection")
    manifest = {
        "schema": "qubolib-qoblib-toqubo-import-v1", "collection": "qoblib_toqubo",
        "collection_version": version, "model_role": "original",
        "selection_scope": "pilot" if selected else "all_audited_originals",
        "study_report_sha256": REPORT_SHA256, "study_cohort_count": 347,
        "study_report": dict(descriptor(report), path="STUDY-REPORT.jsonl"),
        "source_plan": dict(descriptor(source_plan), path="SOURCE-PLAN.json"),
        "study_audited_original_count": 243, "source_snapshot_commit": QOBLIB_COMMIT,
        "toqubo_commit": TOQUBO_COMMIT, "toqubo_source_tree": TOQUBO_TREE,
        "source_decoding": "unavailable_no_validated_adapter", "source_problem_equivalence": "not_established",
        "solution_import": False, "data_license": "CC-BY-4.0",
        "redistribution": redistribution,
        "license_url": "https://github.com/ZIB-AOPT/QOBLIB/blob/" + QOBLIB_COMMIT + "/LICENSE.data",
        "attribution": "QOBLIB contributors (ZIB-AOPT/QOBLIB); source attribution and citation retained per pinned source snapshot",
        "changes": "LP-to-QUBO reformulation by pinned ToQUBO; saved Original polynomial imported losslessly into QUBOLib; not an official QOBLIB QS artifact",
        "cohort": [{"case_id": r["case_id"], "auxiliary_row": r["auxiliary_row"], "family": r["family"],
            "source_lp_path": r["source_lp_path"], "source_lp_sha256": r["source_lp_sha256"],
            "final_outcome": r["controller_status"],
            "audited_original_available": r.get("reporting_gate", {}).get("original_validated") is True}
            for r in rows], "models": models,
    }
    if materialize:
        total_bytes = 0
        for item in fetches.values():
            src = Path(item["local_source"])
            require(src.is_file() and not src.is_symlink(), "materializer needs retained payload: " + str(src))
            observed_bytes = src.stat().st_size
            require(item["bytes"] is None or observed_bytes == item["bytes"], "retained payload size differs")
            total_bytes += observed_bytes
        require(total_bytes <= max_bytes, "materialization byte budget exceeded")
        for item in fetches.values():
            src = Path(item["local_source"])
            require(src.is_file() and not src.is_symlink(), "materializer needs retained payload: " + str(src))
            actual = descriptor(src)
            require(actual["sha256"] == item["sha256"] and
                    (item["bytes"] is None or actual["bytes"] == item["bytes"]), "retained payload differs")
            item["bytes"] = actual["bytes"]
        require(sum(x["bytes"] for x in fetches.values()) <= max_bytes, "materialization byte budget exceeded")
        for entry in models:
            for desc in entry["artifacts"].values():
                desc["bytes"] = fetches[desc["path"]]["bytes"]
        for item in fetches.values():
            dst = out / item["destination"]
            dst.parent.mkdir(exist_ok=True)
            shutil.copyfile(item["local_source"], dst)
            require(sha(dst) == item["sha256"], "copied payload differs")
    else:
        # A plan with unknown LP byte lengths is deliberately not import-ready.
        manifest["preparation_status"] = "metadata_plan_requires_materialization"
    for entry in models:
        for desc in entry["artifacts"].values():
            desc["bytes"] = fetches[desc["path"]]["bytes"]
    shutil.copyfile(report, out / "STUDY-REPORT.jsonl")
    shutil.copyfile(source_plan, out / "SOURCE-PLAN.json")
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    private = out / "FETCH-PRIVATE.json"
    fd = os.open(private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(json.dumps({"schema": "qubolib-private-artifact-fetch-v1", "publish": False,
            "items": list(fetches.values())}, indent=2, sort_keys=True) + "\n")
    return manifest


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--report", required=True)
    p.add_argument("--source-plan", required=True)
    p.add_argument("--phase-root", action="append", required=True, metavar="RUN_ID=PATH")
    p.add_argument("--remote-root", action="append", default=[], metavar="RUN_ID=PATH")
    p.add_argument("--out", required=True)
    p.add_argument("--collection-version", required=True)
    p.add_argument("--case-id", action="append", default=[])
    p.add_argument("--materialize", action="store_true")
    p.add_argument("--max-bytes", type=int, default=8 * 1024**3)
    p.add_argument("--attribution-root", required=True)
    p.add_argument("--license", required=True)
    p.add_argument("--upstream-readme", required=True)
    a = p.parse_args()
    result = prepare(a.report, assignments(a.phase_root), assignments(a.remote_root), a.out,
                     a.collection_version, a.case_id, a.materialize, a.max_bytes,
                     a.attribution_root, a.license, a.upstream_readme, a.source_plan)
    print(json.dumps({"models": len(result["models"]), "cohort": len(result["cohort"]),
                      "scope": result["selection_scope"]}))


if __name__ == "__main__":
    main()
