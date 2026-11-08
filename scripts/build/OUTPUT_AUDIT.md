# Audit a closed uniform candidate

`audit_uniform_candidate.jl` checks the complete output of the canonical
`uniform_candidate.jl PLAN.toml CANDIDATE` producer. Run it on Dantzig in the same
clean source and locked environment: Julia 1.10.12, registered QUBOPreprocessing 0.2.1
and QUBOTools 0.16.4 with the documented trees. Use the same recorded GC heap-hint
policy; its effective byte value is included in each input's provenance. Preserve one core/thread, zero swap,
the approved memory bound, common admission and a finite deadline. The auditor
requires the producer's completed, quiescent supervisor receipt and binds that
receipt to the exact producer command, plan and destination.

Supported invocations use the current Julia executable, `--startup-file=no`, and
the current explicit `--project=ENV_DIRECTORY`. An optional `env` prefix must use
`JULIA_PKG_OFFLINE=true` and the current `JULIA_DEPOT_PATH`. The optional monitor
wrapper uses `/usr/bin/python3`, this checkout's `measure_command.py`, explicit
journal/receipt/memory options and `--` before that Julia invocation. Unknown
prefixes, extra Julia options and ambiguous wrapper options are rejected.
The optional `julia_heap_size_hint` plan field admits only its exact frozen
`--heap-size-hint=SIZE` argument, expressed in M/G units below the supervisor's
memory reservation. It is a GC hint, separate from the enforced cgroup cap.

```sh
julia --startup-file=no --project=LOCKED_ENV \
  scripts/build/audit_uniform_candidate.jl PLAN.toml CANDIDATE \
  PRODUCER_RUN/terminal.json NEW_AUDIT_DIRECTORY
```

The evidence directory must have an existing parent and lie outside the candidate.
Every attempt uses a new directory. A failed audit retains its partial JSONL/error
receipt and is never resumed or represented as a full accepted candidate.

The auditor checks all 9,294 originals, collection/name identity and uniqueness,
native model fingerprints including scale/offset, SQL/HDF5 membership, complete
ordered journal coverage, both mode reports and immutable source/runtime/lock
provenance. It requires exactly one shared submission pair and compares each
producer count with actual stored records. It reevaluates native derived states
and objectives, certificate/perturbation/optimality flags, SQL/HDF5 metadata,
exact-capture bounds/offsets, repair parents, strict improvement and Hamming
distance. Missing source feasibility remains missing; unavailable source evaluation
is explicitly unverified.

Only one native model and its stored records are audited at a time. The original
HDF5 archive opens read-only; SQLite queries use a private temporary copy with
`query_only` enabled. The auditor does not invoke writable library access,
migrations or preprocessing. It verifies unchanged original store bytes, archive
members and their bytes, artifact Git tree, and producer/source/input/environment
identities. The private SQLite copy is removed after use rather than returned as
evidence.

`accepted.json` exists only after complete success and binds the producer receipts,
original inventory, journal, scientific audit JSONL, library members and final
archive by their hashes. Keep its supervising audit-job receipt and resource
measurements separately; scientific acceptance does not establish resource
headroom, publication rights or release approval.

The output stores preparation diagnostics rather than reconstruction traces or
certificate witnesses. This audit checks stored-report consistency and actual
native derived objectives; it does not independently replay the algebraic
certificate. Unsuccessful repair candidates are not retained, so the auditor also
cannot prove exhaustive reconstruction-opportunity coverage. Original model
fingerprints protect polynomials; this tool does not claim an independent
pre-enrichment snapshot of every imported solution or unrelated metadata byte.

The native fixture and corruption checks use the same locked environment:

```sh
julia --startup-file=no --project=LOCKED_ENV scripts/build/test_audit_uniform_candidate.jl
```

These exercise Bool/min and Spin/max outputs, identity/journal/provenance guards,
native objectives, consistent-but-invalid repair metadata, outside-candidate
evidence paths and stale/extra archive members. Fixture success does not replace
the required real full-output audit.
