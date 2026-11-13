from contextlib import ExitStack
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("generated", Path(__file__).with_name("prepare_qoblib_toqubo.py"))
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True) + "\n")


class SavedByteFixture:
    """Synthetic metadata authority; payloads are opaque bytes, never models."""
    def __init__(self, root):
        self.root = root
        self.phase = root / "phase"
        self.report = root / "report.jsonl"
        self.plan = root / "source-plan.json"
        self.lp_body = b"opaque saved LP bytes; do not parse\n"
        self.lp_sha = hashlib.sha256(self.lp_body).hexdigest()
        self.rows = []
        self.plan_rows = []
        self.cases, self.envs, self.audits = {}, {}, {}
        for i in range(1, 348):
            valid = i <= 243
            identity = "case-%04d" % i
            source = "01-birkhoff/models/integer/lp_files/source-%04d.lp.xz" % i
            self.plan_rows.append({"auxiliary_row": i, "family": "birkhoff",
                "source_lp_path": source, "source_lp_sha256": "c" * 64,
                "source_lp_git_blob_sha1": "b" * 40, "source_formulation": "integer",
                "source_continuous_to_integer_required": False})
            self.rows.append({"case_id": identity, "auxiliary_row": i, "family": "birkhoff",
                "source_lp_path": source, "source_lp_sha256": "c" * 64,
                "source_lp_decompressed_sha256": self.lp_sha,
                "controller_status": "audited_ok" if valid else "worker_failed",
                "reporting_gate": {"original_validated": valid, "accepted": valid},
                "original": {"n": 3, "l": 2, "m": 1, "polynomial_sha256": "a" * 64} if valid else None,
                "domain_transformations": {"changed_variable_count": 0,
                    "source_problem_equivalence": "integer_domain_preserved"}})
        self.attributions = root / "attributions"
        attribution = self.attributions / "01-birkhoff/models/integer/README.md"
        attribution.parent.mkdir(parents=True)
        attribution.write_bytes(b"Synthetic attribution retained for fixture.\n")
        write_json(self.attributions / "inventory.json", [{"path": attribution.relative_to(self.attributions).as_posix(),
            **M.descriptor(attribution), "attribution_lines": ["Synthetic fixture author"]}])
        self.license = root / "LICENSE.data"
        self.license.write_bytes(b"Synthetic redistribution license fixture.\n")
        self.upstream_readme = root / "README.upstream.md"
        self.upstream_readme.write_bytes(b"Synthetic upstream description.\n")
        for i in (1, 2):
            self.add_saved_case(i)
        self.flush()

    def case_dir(self, i):
        return self.phase / "cases" / self.rows[i - 1]["case_id"]

    def add_saved_case(self, i):
        row, plan = self.rows[i - 1], self.plan_rows[i - 1]
        directory = self.case_dir(i)
        self.cases[i] = {**plan, "case_id": row["case_id"], "source_snapshot_commit": M.QOBLIB_COMMIT}
        self.envs[i] = {"toqubo_commit": M.TOQUBO_COMMIT, "julia_version": "1.10.12",
                        "packages": {"ToQUBO": {"source_tree": M.TOQUBO_TREE}}}
        inventory = []
        for key, filename in M.NAMES.items():
            path = directory / "results" / row["case_id"] / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("opaque saved %s %s\n" % (row["case_id"], key)).encode())
            inventory.append({"path": row["case_id"] + "/" + filename, **M.descriptor(path)})
            if key == "polynomial":
                row["original"]["polynomial_sha256"] = M.sha(path)
        lp = directory / "input/source.lp"
        lp.parent.mkdir(parents=True, exist_ok=True)
        lp.write_bytes(self.lp_body)
        self.audits[i] = {"passed": True, "accepted": True, "original_validated": True,
            "case_id": row["case_id"], "auditor_sha256": M.AUDITOR_SHA,
            "original": {"polynomial_sha256": row["original"]["polynomial_sha256"]},
            "result_sha256": hashlib.sha256(("opaque result %d" % i).encode()).hexdigest(),
            "inventory": inventory}

    def flush(self):
        for i, audit in self.audits.items():
            directory = self.case_dir(i)
            write_json(directory / "input/case.json", self.cases[i])
            write_json(directory / "results/environment.json", self.envs[i])
            audit["case_manifest_sha256"] = M.sha(directory / "input/case.json")
            audit["environment_sha256"] = M.sha(directory / "results/environment.json")
            write_json(directory / "audit.json", audit)
            self.rows[i - 1]["reporting_gate"].update(audit_sha256=M.sha(directory / "audit.json"),
                result_sha256=audit["result_sha256"])
        self.report.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in self.rows))
        write_json(self.plan, {"models": self.plan_rows})

    def prepare(self, destination, **kwargs):
        pins = {"license": M.sha(self.license), "upstream_readme": M.sha(self.upstream_readme),
                "attribution_inventory": M.sha(self.attributions / "inventory.json")}
        options = {"report": self.report, "roots": {"run-a": self.phase},
                   "remote_roots": {"run-a": Path("/retained/run-a")},
                   "destination": destination, "version": "fixture-v1",
                   "case_ids": ["case-0001"], "materialize": False,
                   "attribution_root": self.attributions, "license_path": self.license,
                   "upstream_readme": self.upstream_readme, "source_plan": self.plan}
        options.update(kwargs)
        # Only synthetic authority pins change inside this context. Production
        # CLI constants and all provenance/domain/materialization gates remain.
        with ExitStack() as stack:
            for name, value in (("REPORT_SHA256", M.sha(self.report)),
                                ("SOURCE_PLAN_SHA256", M.sha(self.plan)),
                                ("REDISTRIBUTION_PINS", pins)):
                stack.enter_context(mock.patch.object(M, name, value))
            return M.prepare(**options)


class PreparationTests(unittest.TestCase):
    def test_real_report_authority_and_domain_gate(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "report.jsonl"
            p.write_text('{}\n')
            with self.assertRaisesRegex(ValueError, "approved final"):
                M.pinned_report(p)

    def test_assignment_and_regular_file_gates(self):
        with self.assertRaisesRegex(ValueError, "unique"):
            M.assignments(["run=/one", "run=/two"])
        with self.assertRaises(ValueError):
            M.assignments(["not-a-mapping"])
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "payload"
            p.write_bytes(b"payload")
            link = Path(tmp) / "link"
            link.symlink_to(p)
            with self.assertRaisesRegex(ValueError, "linked"):
                M.descriptor(link)
            self.assertEqual(M.descriptor(p)["bytes"], 7)

    def test_full_cohort_validation_and_continuous_restriction(self):
        # A synthetic authority exercises the production gate without reading
        # any model body or silently weakening its fixed CLI authority.
        rows = []
        for i in range(347):
            valid = i < 243
            rows.append({"case_id": "case-%04d" % i,
                "reporting_gate": {"original_validated": valid, "accepted": valid},
                "original": {"n": 3} if valid else None,
                "domain_transformations": {"changed_variable_count": 0,
                    "source_problem_equivalence": "integer_domain_preserved"}})
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "report.jsonl"
            p.write_text("".join(json.dumps(x) + "\n" for x in rows))
            with mock.patch.object(M, "REPORT_SHA256", M.sha(p)):
                actual, available = M.pinned_report(p)
                self.assertEqual((len(actual), len(available)), (347, 243))
            rows[0]["domain_transformations"]["changed_variable_count"] = 1
            p.write_text("".join(json.dumps(x) + "\n" for x in rows))
            with mock.patch.object(M, "REPORT_SHA256", M.sha(p)):
                with self.assertRaisesRegex(ValueError, "domain-restricted"):
                    M.pinned_report(p)


class EndToEndPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="qoblib-prepare-bytes-")
        self.root = Path(self.temp.name)
        self.fixture = SavedByteFixture(self.root)

    def tearDown(self):
        self.temp.cleanup()

    def test_materializes_selected_saved_bytes_and_retains_full_cohort(self):
        out = self.root / "materialized"
        real_open = os.open
        previous_umask = os.umask(0)
        try:
            with mock.patch.object(M.os, "open", wraps=real_open) as opened:
                manifest = self.fixture.prepare(out, materialize=True)
        finally:
            os.umask(previous_umask)
        self.assertEqual((len(manifest["models"]), len(manifest["cohort"])), (1, 347))
        self.assertEqual(manifest["study_audited_original_count"], 243)
        self.assertEqual(manifest["selection_scope"], "pilot")
        self.assertEqual(sum(x["audited_original_available"] for x in manifest["cohort"]), 243)
        self.assertFalse(manifest["solution_import"])
        self.assertNotIn("preparation_status", manifest)
        self.assertEqual(manifest["models"][0]["source"]["attribution_paths"],
                         ["01-birkhoff/models/integer/README.md"])
        for artifact in manifest["models"][0]["artifacts"].values():
            self.assertEqual(M.descriptor(out / artifact["path"]),
                             {key: artifact[key] for key in ("sha256", "bytes")})
        self.assertEqual((out / "STUDY-REPORT.jsonl").read_bytes(), self.fixture.report.read_bytes())
        self.assertEqual((out / "SOURCE-PLAN.json").read_bytes(), self.fixture.plan.read_bytes())
        private = out / "FETCH-PRIVATE.json"
        self.assertEqual(stat.S_IMODE(private.stat().st_mode), 0o600)
        self.assertFalse(json.loads(private.read_text())["publish"])
        calls = [call for call in opened.call_args_list if Path(call.args[0]).name == "FETCH-PRIVATE.json"]
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[1] & (os.O_WRONLY | os.O_CREAT | os.O_EXCL),
                         os.O_WRONLY | os.O_CREAT | os.O_EXCL)
        self.assertEqual(calls[0].args[2], 0o600)
        self.assertNotIn(str(self.root), (out / "manifest.json").read_text())

    def test_plan_can_have_unknown_lp_size_but_is_not_materialized(self):
        (self.fixture.case_dir(1) / "input/source.lp").unlink()
        out = self.root / "plan"
        manifest = self.fixture.prepare(out)
        self.assertEqual(manifest["preparation_status"], "metadata_plan_requires_materialization")
        self.assertIsNone(manifest["models"][0]["artifacts"]["lp"]["bytes"])
        self.assertFalse((out / "inputs").exists())
        with self.assertRaisesRegex(ValueError, "needs retained payload"):
            self.fixture.prepare(self.root / "missing-materialization", materialize=True)
        self.assertFalse((self.root / "missing-materialization/manifest.json").exists())

    def test_shared_lp_prefers_second_present_body_with_unknown_or_known_first_size(self):
        (self.fixture.case_dir(1) / "input/source.lp").unlink()
        for known in (False, True):
            with self.subTest(first_size_known=known):
                if known:
                    write_json(self.fixture.case_dir(1) / "source-acquisition.json",
                               {"decompressed_bytes": len(self.fixture.lp_body)})
                out = self.root / ("shared-known" if known else "shared-unknown")
                manifest = self.fixture.prepare(out, case_ids=["case-0001", "case-0002"], materialize=True)
                descriptions = [x["artifacts"]["lp"] for x in manifest["models"]]
                self.assertEqual(descriptions[0], descriptions[1])
                self.assertEqual(descriptions[0]["bytes"], len(self.fixture.lp_body))
                self.assertEqual((out / descriptions[0]["path"]).read_bytes(), self.fixture.lp_body)
                fetch = json.loads((out / "FETCH-PRIVATE.json").read_text())["items"]
                lp_items = [x for x in fetch if x["destination"].endswith(".lp")]
                self.assertEqual(len(lp_items), 1)
                self.assertEqual(lp_items[0]["local_source"], str(self.fixture.case_dir(2) / "input/source.lp"))

    def test_budget_failure_copies_no_inputs_and_writes_no_manifest(self):
        out = self.root / "too-small"
        with self.assertRaisesRegex(ValueError, "byte budget exceeded"):
            self.fixture.prepare(out, materialize=True, max_bytes=1)
        self.assertFalse((out / "inputs").exists())
        self.assertFalse((out / "manifest.json").exists())
        self.assertFalse((out / "FETCH-PRIVATE.json").exists())

    def test_local_lp_hash_and_symlink_rejected_even_in_plan_mode(self):
        lp = self.fixture.case_dir(1) / "input/source.lp"
        lp.write_bytes(b"different opaque bytes")
        with self.assertRaisesRegex(ValueError, "source LP differs/linked"):
            self.fixture.prepare(self.root / "wrong-lp")
        lp.unlink()
        target = self.root / "same-lp-bytes"
        target.write_bytes(self.fixture.lp_body)
        lp.symlink_to(target)
        with self.assertRaisesRegex(ValueError, "source LP differs/linked"):
            self.fixture.prepare(self.root / "linked-lp")

    def test_identifier_validation_happens_before_any_input_read_or_output(self):
        for i, version in enumerate(("bad/version", "v1\n", "", "..")):
            out = self.root / ("version-%d" % i)
            with self.subTest(version=version):
                with self.assertRaisesRegex(ValueError, "unsafe collection version"):
                    M.prepare(self.root / "missing-report", {}, {}, out, version)
                self.assertFalse(out.exists())
        for i, identifier in enumerate(("run/owner", "run\\owner", "run\n", "")):
            out = self.root / ("run-%d" % i)
            with self.subTest(identifier=identifier):
                with self.assertRaisesRegex(ValueError, "unsafe RUN_ID"):
                    M.prepare(self.root / "missing-report", {identifier: self.fixture.phase}, {}, out, "v1")
                self.assertFalse(out.exists())

    def test_source_plan_is_mandatory_and_pinned_before_output(self):
        out = self.root / "no-source-plan"
        with self.assertRaisesRegex(ValueError, "pinned source identity plan"):
            self.fixture.prepare(out, source_plan=None)
        self.assertFalse(out.exists())
        other = self.root / "wrong-source-plan.json"
        write_json(other, {"models": []})
        with self.assertRaisesRegex(ValueError, "pinned source identity plan"):
            self.fixture.prepare(out, source_plan=other)
        self.assertFalse(out.exists())

    def test_rebound_environment_tree_and_case_domain_flag_mismatches_rejected(self):
        self.fixture.envs[1]["packages"]["ToQUBO"]["source_tree"] = "0" * 40
        self.fixture.flush()
        with self.assertRaisesRegex(ValueError, "source/compiler provenance differs"):
            self.fixture.prepare(self.root / "wrong-tree")
        self.fixture.envs[1]["packages"]["ToQUBO"]["source_tree"] = M.TOQUBO_TREE
        self.fixture.cases[1]["source_continuous_to_integer_required"] = True
        self.fixture.plan_rows[0]["source_continuous_to_integer_required"] = True
        self.fixture.flush()
        with self.assertRaisesRegex(ValueError, "source/compiler provenance differs"):
            self.fixture.prepare(self.root / "changed-domain")
        for name in ("wrong-tree", "changed-domain"):
            self.assertFalse((self.root / name / "inputs").exists())
            self.assertFalse((self.root / name / "manifest.json").exists())

    def test_pilot_selection_skips_other_cases_but_rejects_unavailable_sources(self):
        shutil.rmtree(self.fixture.case_dir(1))
        manifest = self.fixture.prepare(self.root / "only-second", case_ids=["case-0002"])
        self.assertEqual([x["case_id"] for x in manifest["models"]], ["case-0002"])
        self.assertEqual(manifest["selection_scope"], "pilot")
        with self.assertRaisesRegex(ValueError, "unknown/unavailable pilot source"):
            self.fixture.prepare(self.root / "not-audited", case_ids=["case-0244"])

    def test_same_audit_in_two_phase_roots_is_ambiguous(self):
        second = self.root / "other-phase"
        audit_copy = second / "cases/case-0001/audit.json"
        audit_copy.parent.mkdir(parents=True)
        shutil.copyfile(self.fixture.case_dir(1) / "audit.json", audit_copy)
        out = self.root / "ambiguous"
        with self.assertRaisesRegex(ValueError, "audit origin absent/ambiguous"):
            self.fixture.prepare(out, roots={"run-a": self.fixture.phase, "run-b": second})
        self.assertFalse((out / "inputs").exists())
        self.assertFalse((out / "manifest.json").exists())

    def test_private_fetch_file_exclusive_creation_does_not_overwrite_racing_file(self):
        out = self.root / "exclusive"
        real_open = os.open
        def race(path, flags, mode=0o777):
            if Path(path).name == "FETCH-PRIVATE.json":
                Path(path).write_bytes(b"preexisting private marker")
            return real_open(path, flags, mode)
        with mock.patch.object(M.os, "open", side_effect=race):
            with self.assertRaises(FileExistsError):
                self.fixture.prepare(out)
        self.assertEqual((out / "FETCH-PRIVATE.json").read_bytes(), b"preexisting private marker")


if __name__ == "__main__":
    unittest.main()
