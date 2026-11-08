# Measuring a bounded build command

`measure_command.py` measures one command inside an **already admitted** Linux
cgroup v2 scope. It uses Python 3.9+ standard library modules. Use the host's
existing allocation/supervision mechanism, one native thread per library, a finite
time limit, and the approved memory bound. This wrapper does not reserve resources
or establish descendant quiescence.

Configure the individual scope with `MemoryMax`, `MemorySwapMax=0`, and
`OOMPolicy=continue`. Require effective `memory.oom.group=0`; the wrapper verifies
the memory limit, zero swap, individual-process OOM behavior including ancestors, and
the current scope's OOM policy. It refuses before launching the workload when
these checks fail. It raises only the workload child's `oom_score_adj` to 1000
before execution, leaving its own adjustment and the supervisor unchanged. This
gives the workload a victim preference; it cannot guarantee monitor survival under
every failure. Never change shared host defaults to satisfy this preflight.

Pass new, distinct evidence paths whose parent directories already exist:

```sh
python3 scripts/build/measure_command.py \
  --journal EVIDENCE/measurement.jsonl --receipt EVIDENCE/measurement.json \
  --memory-mib APPROVED_MIB --interval 1 \
  --disk-path output=CANDIDATE_DIRECTORY \
  -- julia --startup-file=no --project=LOCKED_ENV COMMAND.jl
```

The journal exclusively claims this attempt; existing outputs are never resumed
or overwritten. Start, worker identity, periodic samples, and final observations
are flushed and fsynced. Keep each failed attempt. A host crash, hard kill, disk
failure, or monitor OOM may leave only a journal prefix, which is not a successful
measurement receipt.

On TERM/INT the wrapper forwards TERM to its workload process group, escalates to
KILL after a bounded grace (default one second), reaps its direct child, and writes
final counters while it still holds the cgroup alive. The caller's supervisor must
still clean up escaped descendants and retain admission until quiescence. A final
wrapper receipt alone cannot establish that cleanup or scientific acceptance.
Shutdown journal writes and filesystem calls can still fail or block; test the
actual supervisor's timeout/cancellation path before relying on this mechanism.

Interpret measurements precisely:

- `memory.peak` covers the whole scope, including the supervisor, monitor and
  charged file cache. It is not workload RSS. `memory.events` deltas report OOM
  activity independently of the command exit status.
- `largest_waited_child_rss_kib` comes from `wait4` for the direct workload. Linux
  includes waited descendants in this high-water mark; it is the largest child's
  RSS rather than the simultaneous process-tree total.
- Sampled worker RSS and regular-file logical disk bytes are lower bounds on
  peaks. Disk scans do not follow links, are limited to 0.1 seconds per path per
  sample, and report incomplete scans/errors. Disk observations do not enforce a
  quota or measure physical allocated blocks.
- `workload_returncode` preserves Python's negative signal result (for example
  `-9`). `shell_returncode` reports its shell equivalent (`137`). Cancellation,
  monitor errors, launcher terminal status, quiescence, and scientific acceptance
  remain distinct.

Before scientific use, validate normal completion, a small synthetic workload OOM,
and timeout/cancellation through the **same** admission/supervision mechanism.
Check the final journal/receipt, effective controls, process identities, OOM event
delta, child resource usage, and the supervisor's quiescence/released-allocation
receipt. A synthetic OOM test is not permission to retry a failed scientific job.
