# Build Process

Building QUBOLib from scratch

## Distribution Folder structure

```
dist
├── build
│   ├── Artifact.toml
│   ├── git-tree.hash
│   ├── tar-ball.hash
│   ├── last.tag
│   └── next.tag
└── cache
    └── collection...
        └── data
qubolib
├── archive.h5
└── index.db
```


## Future preprocessing builds

The build environment requires QUBOPreprocessing.jl **0.2.1**. Publish/merge this
builder migration only after that release is registered and a default General
installation has been verified. A development checkout can be used in a separate
stacked environment for review; it is not evidence of registry availability.
The library runtime does not depend on QUBOPreprocessing.jl.

`enrich_preprocessing!` uses the same explicit **5 second soft preparation target**
for each Strong and Weak run. It constructs `Workspace` with `rules=:mixed`,
`integerize_scale=true`, `max_decimals=9` and `atol=0.0`, then calls the public
`QUBOPreprocessing.schedule_budgeted!` once with the preparation time remaining
after policy setup and construction. Exact integerization factors representable dyadic denominators
into the model scale without rounding. Both the native Bool/Spin domain and the
objective sense are retained. Strong sets `allow_weak=false`; Weak sets it to true,
which preserves at least one optimum and can additionally resolve weak ties.

The builder passes every package scheduler option explicitly: probing enabled,
`max_block_size=12`, `probe_rounds=8`, `guaranteed_relation_work=75_000`, and
`tie_break=:low`. The package owns family order, allocation, cheap cascades and
termination. Its mandatory cheap fixpoint floor runs even with no time remaining.
Policy setup, construction, the floor, exact materialization and accounting may overrun the
soft target. There is no hard time cap and no downstream solver dispatch.
Certificate verification and reconstruction are separate work; an exact
certificate need not be available within five seconds.

Each newly generated `metadata.preprocessing` includes:

- `strong_run` and `weak_run`: the full policy, remaining scheduler allowance,
  stop reason, passes, per-family calls/time/variables removed/last stop reason,
  preparation phases, actual overrun, and separate certificate-verification time;
- `normalization` and `materialization` within each run: exact settings, input and
  export scales, workspace/export perturbation diagnostics, actual coefficient
  type and any exact-rational fallback reason (Float64 export never opts into rounding);
- `input`: an exact stored-model fingerprint, native domain/sense/dimensions and
  catalogue identity, with model-loading and fingerprint costs recorded separately;
- `provenance`: the builder source SHA-256, QUBOLib commit/tree/dirty state,
  package version/tree/source revision/dirty state, Julia version/thread count,
  environment Project/Manifest hashes and any supplied TSV hashes.

The summary `strong_time_s` and `weak_time_s` now mean complete preparation,
excluding certificate verification. Unrounded phase clocks give their scope.
Per-family `variables_removed` is a deduction count; it does not count proof
steps, reductions that retain a variable, or extra unique solved instances.
Coercive-field summaries keep their existing native-model semantics.

The legacy 38-column summary TSV has no policy or version columns. Its imported
results are marked `legacy_summary_tsv`, with unknown producer version/settings;
the current enrichment provenance describes the import, not the original
measurement. Keep the original producer's source/settings receipt with that TSV.
If an existing instance already has flat preprocessing metadata/counts, enrichment
preserves those fields and appends the new result under `preprocessing_runs`
with schema `qubolib-builder-preprocessing-v1`. New solution records carry their
actual producing `preparation_run` and separately scoped reconstruction,
stored-objective/source-evaluation and capture-before-storage clocks. These
capture clocks exclude SampleSet creation and persistence. Historical flat
metadata and the accepted artifact are not reclassified as new measurements. The prior caller policy remains reproducible from the pinned code
at `dca18c059d10f3334cfbaf98b7a8c29fbd276859`; no duplicate caller gates are maintained.

The already accepted census is separate evidence: benchmark producer
`4e115b48150edce0235bbe574a240901a72c3a35`, package revision
`29681afd472c5d66860efca1df145d75fb315587`, implementation tree
`5fffe1ae24186b1752fca6a6d875afd398fab822`. It completed both modes on all 9,294
inputs (18,588 rows), with 622 distinct stored-QUBO global proofs, including 281
previously unmarked cases (277 MQLib and four planted). It jointly changed
scheduling, budget, normalization and completed work relative to the historical
caller policy; those counts do not isolate an integerization-only effect. This
builder change does not rerun that census, replace its attribution, publish an
artifact/data release, or merge the separate append-only candidate derivation.
See [issue 106](https://github.com/JuliaQUBO/QUBOLib.jl/issues/106#issuecomment-6646131234)
for the accepted receipts and remaining data-integration scope. Package-level
legacy-scheduler consolidation remains separate future work under
[QUBOPreprocessing issue 95](https://github.com/JuliaQUBO/QUBOPreprocessing.jl/issues/95).
