"""Nonbinding Linux cache advice for a fresh builder's private import copies.

Never opens the native library or the shared source mirrors. A successful
receipt records accepted hints, not the number of resident bytes evicted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

SCHEMA = "qubolib-import-cache-advice-v1"
RECEIPT = "import-cache-advice.json"
ROOTS = ("dist/cache", "sources")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def backend():
    require(sys.platform.startswith("linux"), "import-cache advice requires Linux")
    require(all(hasattr(os, name) for name in (
        "posix_fadvise", "POSIX_FADV_DONTNEED", "O_DIRECTORY", "O_NOFOLLOW")),
        "POSIX_FADV_DONTNEED backend is unavailable")
    return {"schema": SCHEMA, "backend": "POSIX_FADV_DONTNEED",
            "helper_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "python_executable": os.path.realpath(sys.executable),
            "python_version": sys.version.split()[0]}


def identity(value):
    return [value.st_dev, value.st_ino, value.st_uid, value.st_nlink,
            value.st_mode, value.st_size, value.st_mtime_ns, value.st_ctime_ns]


def candidate_path(candidate):
    candidate = Path(candidate)
    require(candidate.is_absolute() and candidate.resolve() == candidate,
            "candidate must be an absolute path without symlinks")
    require(candidate.is_dir() and candidate.stat().st_uid == os.getuid(),
            "candidate directory is not owned by this user")
    return candidate


def collect(candidate, advise):
    """Hash and guard each private inode before hinting through that same FD."""
    backend()
    candidate = candidate_path(candidate)
    directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    file_flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
    uid, seen, rows = os.getuid(), set(), []

    def checked_directory(fd):
        value = os.fstat(fd)
        require(stat.S_ISDIR(value.st_mode) and value.st_uid == uid,
                "import-copy directory is not owned by this user")
        return value

    def unchanged(fd, original, parent=None, name=None):
        require(identity(os.fstat(fd)) == identity(original), "import copy changed")
        if parent is not None:
            require(identity(os.stat(name, dir_fd=parent, follow_symlinks=False)) ==
                    identity(original), "import-copy path changed")

    def visit(fd, components):
        original = checked_directory(fd)
        entries = sorted(os.listdir(fd))
        for name in entries:
            before = os.stat(name, dir_fd=fd, follow_symlinks=False)
            relative = "/".join(components + [name])
            if stat.S_ISDIR(before.st_mode):
                child = os.open(name, directory_flags, dir_fd=fd)
                try:
                    unchanged(child, before, fd, name)
                    visit(child, components + [name])
                    unchanged(child, before, fd, name)
                finally:
                    os.close(child)
                continue
            require(stat.S_ISREG(before.st_mode), "nonregular import-copy entry")
            child = os.open(name, file_flags, dir_fd=fd)
            try:
                opened = os.fstat(child)
                unchanged(child, before, fd, name)
                require(opened.st_uid == uid and opened.st_nlink == 1,
                        "import copy is unowned or hard-linked")
                inode = (opened.st_dev, opened.st_ino)
                require(inode not in seen, "duplicate import-copy inode")
                seen.add(inode)
                digest = hashlib.sha256()
                for block in iter(lambda: os.read(child, 4 * 1024**2), b""):
                    digest.update(block)
                unchanged(child, opened, fd, name)
                if advise:
                    os.posix_fadvise(child, 0, 0, os.POSIX_FADV_DONTNEED)
                unchanged(child, opened, fd, name)
                rows.append({"path": relative, "identity": identity(opened),
                             "bytes": opened.st_size, "sha256": digest.hexdigest(),
                             "advisory_return": 0 if advise else None})
            finally:
                os.close(child)
        require(sorted(os.listdir(fd)) == entries, "import-copy entries changed")
        unchanged(fd, original)

    root = os.open(candidate, directory_flags)
    try:
        root_before = checked_directory(root)
        for relative in ROOTS:
            current, opened = root, []
            try:
                for name in relative.split("/"):
                    before = os.stat(name, dir_fd=current, follow_symlinks=False)
                    child = os.open(name, directory_flags, dir_fd=current)
                    try:
                        checked_directory(child)
                        unchanged(child, before, current, name)
                    except Exception:
                        os.close(child)
                        raise
                    # Retain every ancestor descriptor/name binding until the
                    # walk ends; an unchanged cache FD alone misses dist swaps.
                    opened.append((current, name, child, before))
                    current = child
                visit(current, relative.split("/"))
                for parent, name, child, before in reversed(opened):
                    unchanged(child, before, parent, name)
            finally:
                for _, _, child, _ in reversed(opened):
                    os.close(child)
        unchanged(root, root_before)
        require(identity(os.stat(candidate, follow_symlinks=False)) == identity(root_before),
                "candidate path changed")
    finally:
        os.close(root)
    require(bool(rows), "no private import copies found")
    return sorted(rows, key=lambda row: row["path"])


def context(candidate, info, plan_sha256, originals_sha256):
    """Bind the ordered builder context without loading model arrays."""
    bindings = {"run_plan_sha256": ("run-plan.json", plan_sha256),
                "original_models_sha256": ("original-models.json", originals_sha256)}
    plan_bytes = None
    for key, (name, expected) in bindings.items():
        require(isinstance(expected, str) and len(expected) == 64 and
                all(c in "0123456789abcdef" for c in expected), "missing metadata SHA256: " + key)
        path = candidate / name
        before = path.lstat()
        require(stat.S_ISREG(before.st_mode) and before.st_uid == os.getuid() and
                before.st_nlink == 1, "unowned/linked builder metadata")
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            require(identity(os.fstat(fd)) == identity(before), "builder metadata changed")
            digest, blocks = hashlib.sha256(), []
            for block in iter(lambda: os.read(fd, 4 * 1024**2), b""):
                digest.update(block)
                if name == "run-plan.json":
                    blocks.append(block)
            require(identity(os.fstat(fd)) == identity(before) == identity(path.lstat()),
                    "builder metadata changed")
            require(digest.hexdigest() == expected, "builder metadata checksum differs: " + name)
            if name == "run-plan.json":
                plan_bytes = b"".join(blocks)
        finally:
            os.close(fd)
    plan = json.loads(plan_bytes)
    require(plan["state"] == "prepared" and plan["plan"]["advise_import_cache"] is True and
            plan["plan"]["schema"] == "qubolib-uniform-candidate-v1" and
            plan["import_cache_backend"] == info, "not an enabled prepared builder context")
    return {key: value[1] for key, value in bindings.items()}


def advise(candidate, plan_sha256, originals_sha256):
    info = backend()
    candidate = candidate_path(candidate)
    binding = context(candidate, info, plan_sha256, originals_sha256)
    for name in ("enrichment.jsonl", "terminal.json", "failure.json"):
        path = candidate / name
        require(not path.exists() and not path.is_symlink(), "enrichment/terminal already exists")
    # Reserve the receipt before the first hint, refuse an existing result.
    # A failed helper can leave an empty/partial receipt. The builder records
    # failure.json and never emits a verified candidate for that attempt.
    receipt = candidate / RECEIPT
    with receipt.open("x", encoding="utf-8") as stream:
        rows = collect(candidate, True)
        require(context(candidate, info, plan_sha256, originals_sha256) == binding,
                "builder context changed during advice")
        result = dict(info, **binding, state="complete", candidate=str(candidate),
                      roots=list(ROOTS), files=rows, file_count=len(rows),
                      bytes=sum(row["bytes"] for row in rows),
                      advice_is_nonbinding=True, actual_resident_bytes_released=None)
        json.dump(result, stream, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    return result


def verify(candidate):
    """Optional closed-producer check; re-reading copies can refill file cache."""
    candidate = candidate_path(candidate)
    path = candidate / RECEIPT
    require(path.is_file() and not path.is_symlink(), "missing/linked advice receipt")
    result = json.loads(path.read_text(encoding="utf-8"))
    require(result["schema"] == SCHEMA and result["state"] == "complete" and
            result["candidate"] == str(candidate), "wrong advice receipt")
    info = backend()
    require(all(result[key] == value for key, value in info.items()) and
            result["roots"] == list(ROOTS) and result["advice_is_nonbinding"] is True and
            result["actual_resident_bytes_released"] is None,
            "wrong advice provenance")
    context(candidate, info, result["run_plan_sha256"], result["original_models_sha256"])
    require(result["file_count"] == len(result["files"]) and
            result["bytes"] == sum(row["bytes"] for row in result["files"]) and
            all(row["advisory_return"] == 0 for row in result["files"]),
            "incomplete advice receipt")
    rows = collect(candidate, False)
    expected = [{key: value for key, value in row.items() if key != "advisory_return"}
                for row in result["files"]]
    actual = [{key: value for key, value in row.items() if key != "advisory_return"}
              for row in rows]
    require(actual == expected, "import-copy content/identity changed after advice")
    terminal = candidate / "terminal.json"
    bound = False
    if terminal.exists() or terminal.is_symlink():
        require(terminal.is_file() and not terminal.is_symlink(), "linked producer terminal")
        producer = json.loads(terminal.read_text(encoding="utf-8"))
        anchor = producer["import_cache_advice"]
        require(producer["state"] == "complete" and anchor["receipt_bytes"] == path.stat().st_size and
                anchor["receipt_sha256"] == hashlib.sha256(path.read_bytes()).hexdigest(),
                "producer terminal binds a different advice receipt")
        bound = True
    return {"schema": SCHEMA, "state": "verified", "file_count": len(rows),
            "producer_terminal_bound": bound}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", nargs="?", type=Path)
    parser.add_argument("--run-plan-sha256")
    parser.add_argument("--original-models-sha256")
    choice = parser.add_mutually_exclusive_group()
    choice.add_argument("--check", action="store_true")
    choice.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.check:
        require(args.candidate is None, "--check does not accept a candidate")
        result = backend()
    else:
        require(args.candidate is not None, "candidate is required")
        result = verify(args.candidate) if args.verify else advise(
            args.candidate, args.run_plan_sha256, args.original_models_sha256)
    # Keep the per-file array out of the long-lived numerical process's heap.
    summary = {key: value for key, value in result.items() if key != "files"}
    if not args.check and not args.verify:
        receipt = args.candidate / RECEIPT
        summary["receipt_bytes"] = receipt.stat().st_size
        summary["receipt_sha256"] = hashlib.sha256(receipt.read_bytes()).hexdigest()
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
