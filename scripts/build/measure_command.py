#!/usr/bin/env python3
"""Durably measure one command inside an already admitted Linux cgroup v2 scope.

This does not allocate resources or replace the caller's descendant supervisor.
An OOM preference helps the monitor survive a workload OOM; it is not immunity.
"""

import argparse
import datetime
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import time


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def identity(pid):
    root = Path("/proc") / str(pid)
    # A comm field may contain spaces and parentheses.
    fields = (root / "stat").read_text().rsplit(")", 1)[1].split()
    return {"pid": pid, "uid": root.stat().st_uid,
            "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
            "start_ticks": int(fields[19])}


def cgroup(pid):
    lines = (Path("/proc") / str(pid) / "cgroup").read_text().splitlines()
    unified = [line.split(":", 2)[2] for line in lines if line.startswith("0::")]
    if len(unified) != 1:
        raise RuntimeError("a unified cgroup v2 hierarchy is required")
    return Path("/sys/fs/cgroup") / unified[0].lstrip("/")


def counters(group):
    result = {}
    for name in ("memory.max", "memory.swap.max", "memory.oom.group",
                 "memory.current", "memory.peak"):
        result[name] = (group / name).read_text().strip()
    # cpuset may not be delegated to a user manager. The admitting supervisor
    # and the recorded sched_getaffinity verify actual CPU binding separately.
    cpuset = group / "cpuset.cpus.effective"
    result["cpuset.cpus.effective"] = cpuset.read_text().strip() if cpuset.is_file() else None
    result["memory.events"] = dict(
        (key, int(value)) for key, value in
        (line.split() for line in (group / "memory.events").read_text().splitlines()))
    return result


def controls(group, memory_mib):
    value = counters(group)
    if value["memory.max"] == "max" or int(value["memory.max"]) != memory_mib * 1024**2:
        raise RuntimeError("effective memory.max differs from the sealed limit")
    if value["memory.swap.max"] != "0" or value["memory.oom.group"] != "0":
        raise RuntimeError("zero swap and individual-process OOM killing are required")
    # A stricter ancestor can cause a different failure regime. Group killing at
    # an ancestor would also invalidate the monitor's survival assumption.
    ancestors = []
    current = group
    while current != Path("/sys/fs/cgroup"):
        entry = {"path": str(current)}
        for name in ("memory.max", "memory.swap.max", "memory.oom.group"):
            file = current / name
            if not file.is_file():
                raise RuntimeError("unverified ancestor control: " + str(file))
            entry[name] = file.read_text().strip()
        if entry["memory.max"] != "max" and int(entry["memory.max"]) < memory_mib * 1024**2:
            raise RuntimeError("ancestor memory limit is stricter than the sealed limit")
        if entry["memory.oom.group"] != "0":
            raise RuntimeError("ancestor group OOM killing is enabled")
        ancestors.append(entry)
        current = current.parent
    policy = subprocess.check_output(
        ["systemctl", "--user", "show", group.name, "--property=OOMPolicy", "--value"],
        text=True, timeout=5).strip()
    if policy != "continue":
        raise RuntimeError("the current scope must use OOMPolicy=continue")
    return {"effective": value, "ancestors": ancestors, "oom_policy": policy}


def disk_bytes(path, cancelled=lambda: False):
    """Regular-file logical bytes, without following links; races are counted."""
    total = 0
    errors = 0
    if cancelled():
        return {"bytes": 0, "errors": 0, "exists": None, "incomplete": True}
    if path.is_symlink():
        return {"bytes": 0, "errors": 1, "exists": True, "incomplete": True}
    if not path.exists():
        return {"bytes": 0, "errors": 0, "exists": False}
    if not path.is_dir():
        return {"bytes": 0, "errors": 1, "exists": True, "incomplete": True}
    deadline = time.monotonic() + 0.1
    incomplete = False

    def walk_error(_error):
        nonlocal errors
        errors += 1

    for root, directories, files in os.walk(path, followlinks=False, onerror=walk_error):
        if cancelled() or time.monotonic() >= deadline:
            incomplete = True
            break
        directories[:] = [d for d in directories if not (Path(root) / d).is_symlink()]
        for name in files:
            if cancelled() or time.monotonic() >= deadline:
                incomplete = True
                break
            try:
                info = (Path(root) / name).lstat()
                if stat.S_ISREG(info.st_mode):
                    total += info.st_size
            except OSError:
                errors += 1
    return {"bytes": total, "errors": errors, "exists": True, "incomplete": incomplete}


def child_setup():
    Path("/proc/self/oom_score_adj").write_text("1000\n")


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--journal", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--memory-mib", type=int, required=True)
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--stop-grace", type=float, default=1.0)
    parser.add_argument("--disk-path", action="append", default=[], metavar="LABEL=PATH")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.command[:1] == ["--"]:
        args.command = args.command[1:]
    if not args.command or args.memory_mib <= 0 or not 0.05 <= args.interval <= 60:
        parser.error("command, positive memory limit and interval in [0.05,60] are required")
    if not 0 < args.stop_grace <= 2:
        parser.error("stop grace must be in (0,2] seconds to fit supervisor shutdown")
    args.disks = {}
    for value in args.disk_path:
        label, separator, path = value.partition("=")
        if not separator or not label or not path or label in args.disks:
            parser.error("disk paths need unique LABEL=PATH values")
        args.disks[label] = Path(path)
    if args.journal.resolve() == args.receipt.resolve():
        parser.error("journal and receipt must differ")
    return args


def main(argv=None):
    args = arguments(argv)
    if args.receipt.exists() or args.receipt.is_symlink():
        raise RuntimeError("receipt already exists; reuse is unsupported")
    if not args.receipt.parent.is_dir():
        raise RuntimeError("receipt parent directory does not exist")
    # Exclusive journal creation is the attempt claim, including failed preflight.
    with args.journal.open("x") as journal:
        started = time.monotonic()
        stop = {"signal": None}
        previous = {}

        def emit(kind, **values):
            entry = {"schema": "qubolib-command-measurement-v1", "kind": kind,
                     "utc": utc(), "wall_s": time.monotonic() - started, **values}
            journal.write(json.dumps(entry, sort_keys=True, allow_nan=False) + "\n")
            journal.flush()
            os.fsync(journal.fileno())
            return entry

        def stopped(signum, _frame):
            stop["signal"] = signum

        for sig in (signal.SIGTERM, signal.SIGINT):
            previous[sig] = signal.signal(sig, stopped)
        process = None
        status = usage = None
        group = None
        initial = None
        sample_peak_rss = 0
        sample_peak_disk = {name: 0 for name in args.disks}
        termination_at = None
        failure = None
        try:
            group = cgroup(os.getpid())
            initial = controls(group, args.memory_mib)
            monitor_score = int(Path("/proc/self/oom_score_adj").read_text())
            if monitor_score >= 1000:
                raise RuntimeError("monitor must have a lower OOM score adjustment than its child")
            emit("start", command=args.command, monitor=identity(os.getpid()),
                 monitor_oom_score_adj=monitor_score, cgroup=str(group), controls=initial,
                 affinity=sorted(os.sched_getaffinity(0)),
                 disk_paths={key: str(path) for key, path in args.disks.items()})
            if stop["signal"] is not None:
                raise RuntimeError("cancelled before workload start")
            process = subprocess.Popen(args.command, start_new_session=True, preexec_fn=child_setup)
            # Even a fast exit remains our unreaped zombie until wait4 below.
            worker = identity(process.pid)
            if cgroup(process.pid) != group:
                raise RuntimeError("workload escaped the measured cgroup")
            child_score = int((Path("/proc") / str(process.pid) / "oom_score_adj").read_text())
            if child_score != 1000:
                raise RuntimeError("workload OOM preference was not applied")
            emit("worker", process=worker, oom_score_adj=child_score)
            while status is None:
                now = time.monotonic()
                if stop["signal"] is not None and termination_at is None:
                    termination_at = now
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                elif termination_at is not None and now - termination_at >= args.stop_grace:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                info = (Path("/proc") / str(process.pid) / "status").read_text()
                rss = next((int(line.split()[1]) for line in info.splitlines()
                            if line.startswith("VmRSS:")), 0)
                sample_peak_rss = max(sample_peak_rss, rss)
                disks = {key: disk_bytes(path, lambda: stop["signal"] is not None)
                         for key, path in args.disks.items()}
                for key, value in disks.items():
                    sample_peak_disk[key] = max(sample_peak_disk[key], value["bytes"])
                emit("sample", counters=counters(group), worker_rss_kib=rss, disks=disks)
                waited, raw, measured = os.wait4(process.pid, os.WNOHANG)
                if waited:
                    status, usage = raw, measured
                    process.returncode = os.waitstatus_to_exitcode(status)
                else:
                    # The signal handler records cancellation; a short sleep lets
                    # finalization fit inside the common supervisor's grace.
                    if termination_at is not None:
                        time.sleep(0.05)
                    else:
                        deadline = time.monotonic() + args.interval
                        while time.monotonic() < deadline and stop["signal"] is None:
                            time.sleep(min(0.1, max(0, deadline - time.monotonic())))
        except BaseException as error:
            failure = type(error).__name__ + ": " + str(error)
            if process is not None and status is None:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                _, status, usage = os.wait4(process.pid, 0)
                process.returncode = os.waitstatus_to_exitcode(status)
        finally:
            # Keep the group alive until its final counters have been persisted.
            try:
                final = counters(group) if group is not None else None
            except OSError as error:
                final = {"unavailable": str(error)}
                failure = failure or "final cgroup counters unavailable"
            rc = process.returncode if process is not None else None
            shell_rc = 128 - rc if rc is not None and rc < 0 else rc
            events = None
            if initial is not None and final is not None and "memory.events" in final:
                events = {key: value - initial["effective"]["memory.events"].get(key, 0)
                          for key, value in final["memory.events"].items()}
            receipt = emit("final", workload_returncode=rc, shell_returncode=shell_rc,
                           stop_signal=stop["signal"], monitor_error=failure,
                           final_counters=final, memory_events_delta=events,
                           largest_waited_child_rss_kib=None if usage is None else usage.ru_maxrss,
                           child_user_s=None if usage is None else usage.ru_utime,
                           child_system_s=None if usage is None else usage.ru_stime,
                           sampled_worker_rss_lower_bound_kib=sample_peak_rss,
                           maximum_observed_disk_scan_bytes=sample_peak_disk,
                           descendant_quiescence="requires supervising launcher receipt",
                           scientific_acceptance="not assessed")
            with args.receipt.open("x") as output:
                json.dump(receipt, output, indent=2, sort_keys=True, allow_nan=False)
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            for sig, handler in previous.items():
                signal.signal(sig, handler)
        if failure is not None:
            return 125
        if stop["signal"] is not None:
            return 128 + stop["signal"]
        return shell_rc


if __name__ == "__main__":
    sys.exit(main())
