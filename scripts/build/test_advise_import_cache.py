"""Tiny filesystem fixtures; no models, source mirrors or system-wide reclaim."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import advise_import_cache as cache


@unittest.skipUnless(sys.platform.startswith("linux"), "Linux cache advice")
class ImportCacheAdviceTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.candidate = self.root / "fresh candidate"
        self.candidate.mkdir()
        for relative in cache.ROOTS:
            (self.candidate / relative).mkdir(parents=True)
        self.files = [self.candidate / "dist/cache/mirror.zip",
                      self.candidate / "sources/model.txt"]
        for number, path in enumerate(self.files):
            path.write_bytes(b"private fixture " + bytes([number]) * 8192)
        # Neither native storage nor an external mirror may be hinted/changed.
        self.native = self.candidate / "qubolib/archive.h5"
        self.native.parent.mkdir()
        self.native.write_bytes(b"native storage fixture")
        self.external = self.root / "shared.zip"
        self.external.write_bytes(b"external source fixture")
        self.plan = self.candidate / "run-plan.json"
        self.plan.write_text(json.dumps({"state": "prepared", "plan": {
            "schema": "qubolib-uniform-candidate-v1", "advise_import_cache": True},
            "import_cache_backend": cache.backend()}), encoding="utf-8")
        self.originals = self.candidate / "original-models.json"
        self.originals.write_text('[{"fixture_only": true}]', encoding="utf-8")
        self.plan_sha = hashlib.sha256(self.plan.read_bytes()).hexdigest()
        self.originals_sha = hashlib.sha256(self.originals.read_bytes()).hexdigest()

    def advise(self, candidate=None):
        return cache.advise(candidate or self.candidate, self.plan_sha, self.originals_sha)

    def cli(self, *args, optimized=False):
        if "--check" not in args and "--verify" not in args:
            args += ("--run-plan-sha256", self.plan_sha,
                     "--original-models-sha256", self.originals_sha)
        return subprocess.run([sys.executable, "-B"] + (["-O"] if optimized else []) +
                              [cache.__file__, *map(str, args)],
                              capture_output=True, text=True)

    def test_only_private_readonly_descriptors_receive_hints(self):
        import fcntl
        allowed = {(p.stat().st_dev, p.stat().st_ino) for p in self.files}
        seen = []
        untouched = {p: p.read_bytes() for p in self.files + [self.native, self.external]}

        def record(fd, offset, length, advice):
            value = os.fstat(fd)
            self.assertIn((value.st_dev, value.st_ino), allowed)
            self.assertEqual(fcntl.fcntl(fd, fcntl.F_GETFL) & os.O_ACCMODE, os.O_RDONLY)
            self.assertEqual((offset, length, advice), (0, 0, os.POSIX_FADV_DONTNEED))
            seen.append(value.st_ino)

        with patch.object(cache.os, "posix_fadvise", side_effect=record):
            receipt = self.advise()
        self.assertEqual(len(seen), 2)
        self.assertEqual(receipt["file_count"], 2)
        self.assertTrue(receipt["advice_is_nonbinding"])
        self.assertIsNone(receipt["actual_resident_bytes_released"])
        self.assertEqual(receipt["bytes"], sum(p.stat().st_size for p in self.files))
        self.assertEqual(receipt["roots"], ["dist/cache", "sources"])
        for path, original in untouched.items():
            self.assertEqual(path.read_bytes(), original)
        for row in receipt["files"]:
            self.assertEqual(row["sha256"], hashlib.sha256(
                (self.candidate / row["path"]).read_bytes()).hexdigest())
            self.assertEqual(row["advisory_return"], 0)
        self.assertEqual(cache.verify(self.candidate)["state"], "verified")

    def test_actual_cli_backend_advice_and_closed_verification(self):
        check = self.cli("--check")
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertEqual(json.loads(check.stdout), cache.backend())
        advised = self.cli(self.candidate)
        self.assertEqual(advised.returncode, 0, advised.stderr)
        summary = json.loads(advised.stdout)
        self.assertEqual(summary["file_count"], 2)
        self.assertNotIn("files", summary)
        raw = (self.candidate / cache.RECEIPT).read_bytes()
        self.assertEqual(summary["receipt_bytes"], len(raw))
        self.assertEqual(summary["receipt_sha256"], hashlib.sha256(raw).hexdigest())
        verified = self.cli("--verify", self.candidate)
        self.assertEqual(verified.returncode, 0, verified.stderr)
        self.files[0].write_bytes(b"changed after hint")
        refused = self.cli("--verify", self.candidate)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("content/identity changed", refused.stderr)

    def test_existing_receipt_is_never_overwritten_or_rehinted(self):
        path = self.candidate / cache.RECEIPT
        path.write_text("retained attempt", encoding="utf-8")
        with patch.object(cache.os, "posix_fadvise") as hint:
            with self.assertRaises(FileExistsError):
                self.advise()
            hint.assert_not_called()
        self.assertEqual(path.read_text(encoding="utf-8"), "retained attempt")

    def test_linked_candidate_is_refused_before_receipt_creation(self):
        linked = self.root / "linked"
        linked.symlink_to(self.candidate, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "without symlinks"):
            self.advise(linked)
        self.assertFalse((self.candidate / cache.RECEIPT).exists())
        with self.assertRaisesRegex(ValueError, "absolute path"):
            self.advise(Path("relative-candidate"))

    def test_symlink_hardlink_fifo_and_linked_scope_are_refused(self):
        entry = self.candidate / "sources/unsafe"
        for kind in ("symlink", "hardlink", "fifo", "directory-symlink"):
            with self.subTest(kind=kind):
                if kind == "symlink":
                    entry.symlink_to(self.external)
                elif kind == "hardlink":
                    os.link(self.external, entry)
                elif kind == "fifo":
                    os.mkfifo(entry)
                else:
                    entry.symlink_to(self.root, target_is_directory=True)
                with patch.object(cache.os, "posix_fadvise"):
                    with self.assertRaises((ValueError, OSError)):
                        cache.collect(self.candidate, True)
                entry.unlink()
        (self.candidate / "sources/model.txt").unlink()
        (self.candidate / "sources").rmdir()
        (self.candidate / "sources").symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(OSError):
            cache.collect(self.candidate, True)

    def test_python_optimization_cannot_disable_path_guards(self):
        (self.candidate / "sources/unsafe").symlink_to(self.external)
        result = self.cli(self.candidate, optimized=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nonregular import-copy entry", result.stderr)

    def test_hint_error_fails_without_completed_receipt(self):
        with patch.object(cache.os, "posix_fadvise", side_effect=OSError("backend refusal")):
            with self.assertRaisesRegex(OSError, "backend refusal"):
                self.advise()
        path = self.candidate / cache.RECEIPT
        self.assertTrue(path.exists()) # failed attempt retained, no implicit retry
        self.assertEqual(path.read_bytes(), b"")

    def test_file_content_race_is_rejected_before_hint(self):
        original_read = os.read
        changed = False

        def changing_read(fd, size):
            nonlocal changed
            block = original_read(fd, size)
            if block and not changed:
                changed = True
                self.files[0].write_bytes(b"changed during hashing")
            return block

        with patch.object(cache.os, "read", side_effect=changing_read), \
                patch.object(cache.os, "posix_fadvise") as hint:
            with self.assertRaisesRegex(ValueError, "import copy changed"):
                cache.collect(self.candidate, True)
            hint.assert_not_called()

    def test_path_replacement_during_hint_is_rejected(self):
        def replacing_hint(*args):
            self.files[0].unlink()
            self.files[0].write_bytes(b"replacement inode")

        with patch.object(cache.os, "posix_fadvise", side_effect=replacing_hint):
            with self.assertRaisesRegex(ValueError, "import copy changed|path changed"):
                cache.collect(self.candidate, True)

    def test_fixed_ancestor_replacement_during_hint_is_rejected(self):
        changed = False

        def replace_dist(*args):
            nonlocal changed
            if not changed:
                changed = True
                (self.candidate / "dist").rename(self.candidate / "held-dist")
                (self.candidate / "dist/cache").mkdir(parents=True)
                (self.candidate / "dist/cache/mirror.zip").write_bytes(b"replacement tree")

        with patch.object(cache.os, "posix_fadvise", side_effect=replace_dist):
            with self.assertRaisesRegex(ValueError, "changed"):
                self.advise()

    def test_candidate_replacement_during_hint_is_rejected(self):
        changed = False

        def replace_candidate(*args):
            nonlocal changed
            if not changed:
                changed = True
                self.candidate.rename(self.root / "held-candidate")
                self.candidate.mkdir()

        with patch.object(cache.os, "posix_fadvise", side_effect=replace_candidate):
            with self.assertRaisesRegex(ValueError, "changed"):
                self.advise()

    def test_pre_enrichment_context_and_metadata_digests_are_required(self):
        with patch.object(cache.os, "posix_fadvise") as hint:
            with self.assertRaisesRegex(ValueError, "metadata SHA256"):
                cache.advise(self.candidate, None, self.originals_sha)
            with self.assertRaisesRegex(ValueError, "checksum differs"):
                cache.advise(self.candidate, "0" * 64, self.originals_sha)
            for name in ("enrichment.jsonl", "terminal.json", "failure.json"):
                path = self.candidate / name
                path.write_text("prior attempt", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "already exists"):
                    self.advise()
                path.unlink()
            value = json.loads(self.plan.read_text(encoding="utf-8"))
            value["plan"]["advise_import_cache"] = False
            self.plan.write_text(json.dumps(value), encoding="utf-8")
            self.plan_sha = hashlib.sha256(self.plan.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValueError, "enabled prepared"):
                self.advise()
            hint.assert_not_called()
        self.assertFalse((self.candidate / cache.RECEIPT).exists())

    def test_verification_binds_prepared_metadata_and_producer_receipt(self):
        summary = json.loads(self.cli(self.candidate).stdout)
        self.assertEqual(summary["run_plan_sha256"], self.plan_sha)
        self.assertEqual(summary["original_models_sha256"], self.originals_sha)
        self.assertFalse(cache.verify(self.candidate)["producer_terminal_bound"])
        terminal = self.candidate / "terminal.json"
        # Minimal metadata anchor fixture, never a complete-corpus candidate.
        terminal.write_text(json.dumps({"state": "complete", "import_cache_advice": summary}),
                            encoding="utf-8")
        self.assertTrue(cache.verify(self.candidate)["producer_terminal_bound"])
        changed = dict(summary, receipt_sha256="0" * 64)
        terminal.write_text(json.dumps({"state": "complete", "import_cache_advice": changed}),
                            encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "different advice receipt"):
            cache.verify(self.candidate)
        terminal.unlink()
        self.originals.write_text("changed fixture inventory", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "metadata checksum differs"):
            cache.verify(self.candidate)


if __name__ == "__main__":
    unittest.main()
