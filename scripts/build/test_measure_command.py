#!/usr/bin/env python3
"""Small Linux integration checks inside an already admitted bounded user scope.

Use OOMPolicy=continue, zero swap, one core/thread and the specified memory cap.
This test never allocates enough memory to trigger OOM. Validate OOM and supervisor
timeout/cancellation separately through the actual host admission mechanism.
"""

import argparse
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--memory-mib", type=int, default=128)
    parser.add_argument("--monitor", type=Path, default=Path(__file__).with_name("measure_command.py"))
    parser.add_argument("--only-parent", action="store_true")
    args = parser.parse_args()
    args.output.mkdir()  # new attempt only
    spec = importlib.util.spec_from_file_location("measured_command_under_test", args.monitor)
    monitor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(monitor)

    class MeasurementChecks(unittest.TestCase):
        def test_missing_receipt_parent_refuses_before_work(self):
            marker = args.output / "must-not-run"
            journal = args.output / "invalid-parent.jsonl"
            with self.assertRaisesRegex(RuntimeError, "receipt parent directory"):
                monitor.main([
                    "--journal", str(journal), "--receipt", str(args.output / "absent/receipt.json"),
                    "--memory-mib", str(args.memory_mib), "--", sys.executable, "-c",
                    "from pathlib import Path; Path(" + repr(str(marker)) + ").touch()"])
            self.assertFalse(marker.exists())
            self.assertFalse(journal.exists())

        def test_cancelled_scan_does_not_probe_filesystem(self):
            with patch.object(Path, "exists", side_effect=AssertionError("unexpected probe")):
                result = monitor.disk_bytes(args.output, lambda: True)
            self.assertTrue(result["incomplete"])
            self.assertEqual(result["bytes"], 0)

        def test_link_is_not_scanned(self):
            directory = args.output / "link-target"
            directory.mkdir()
            (directory / "payload").write_bytes(b"fixture")
            link = args.output / "link"
            link.symlink_to(directory, target_is_directory=True)
            result = monitor.disk_bytes(link)
            self.assertEqual(result["bytes"], 0)
            self.assertEqual(result["errors"], 1)
            self.assertTrue(result["incomplete"])

        def test_unlimited_leaf_refuses_explicitly(self):
            with patch.object(monitor, "counters", return_value={"memory.max": "max"}):
                with self.assertRaisesRegex(RuntimeError, "memory.max"):
                    monitor.controls(Path("/unused"), args.memory_mib)

        def test_real_command_and_disk_receipt(self):
            import json
            data = args.output / "workload-output"
            data.mkdir()
            journal, receipt = args.output / "normal.jsonl", args.output / "normal.json"
            command = ("from pathlib import Path; import time; Path(" +
                       repr(str(data / "blob")) + ").write_bytes(b'x' * (3*1024*1024)); time.sleep(.3)")
            rc = monitor.main([
                "--journal", str(journal), "--receipt", str(receipt),
                "--memory-mib", str(args.memory_mib), "--interval", ".05",
                "--disk-path", "output=" + str(data), "--", sys.executable, "-c", command])
            self.assertEqual(rc, 0)
            result = json.loads(receipt.read_text())
            entries = [json.loads(line) for line in journal.read_text().splitlines()]
            self.assertEqual(entries[-1], result)
            self.assertIsNone(result["monitor_error"])
            self.assertEqual(result["maximum_observed_disk_scan_bytes"]["output"], 3*1024*1024)
            self.assertGreater(result["largest_waited_child_rss_kib"], 0)
            self.assertEqual(result["memory_events_delta"]["oom_kill"], 0)
            original = receipt.read_bytes()
            with self.assertRaisesRegex(RuntimeError, "already exists"):
                monitor.main(["--journal", str(journal), "--receipt", str(receipt),
                              "--memory-mib", str(args.memory_mib), "--", sys.executable, "-c", "pass"])
            self.assertEqual(receipt.read_bytes(), original)

    suite = (unittest.TestSuite([MeasurementChecks("test_missing_receipt_parent_refuses_before_work")])
             if args.only_parent else unittest.defaultTestLoader.loadTestsFromTestCase(MeasurementChecks))
    return 0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
