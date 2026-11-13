# Generated QOBLIB / ToQUBO collection

`qoblib_toqubo` is a separate, opt-in generated collection. Its first version
imports **saved Original QUBOs**, without loading ToQUBO, compiling an LP, running
preprocessing, or solving a model. The canonical `qoblib` collection and selected
`v0.2.7-data+10` default artifact remain unchanged.

This follows the separation described in [QUBOLib issue #47](https://github.com/JuliaQUBO/QUBOLib.jl/issues/47)
and [ToQUBO issue #145](https://github.com/JuliaQUBO/ToQUBO.jl/issues/145).
The frozen manuscript study records all 347 source outcomes, including 243
independently audited Original polynomials. Those 243 are **import candidates**;
a release must additionally pass the import and HDF5 roundtrip gates below.
An audited Original can be included when its Strong/Weak runs failed. Residuals
are outside this first release and would require separate parent/policy/trace
lineage; they are not additional source problems.

The normal QUBOLib density columns retain QUBOTools definitions: overall
`(2m+l)/n²`, linear `l/n`, and quadratic graph density `2m/[n(n-1)]` where
defined. They are distinct from the manuscript's QS upper-triangle density
`2(m+l)/[n(n+1)]`. The import does not overwrite these definitions.

## Scientific and numeric scope

The saved JSONL schema, `qoblib-generated-exact-polynomial-v1`, defines

```math
E(x)=\alpha\left(\beta+\sum_i l_i x_i+\sum_{i<j}q_{ij}x_ix_j\right),\quad x_i\in\{0,1\}.
```

The header records `n`, `domain`, `sense`, `scale_exact`, `offset_exact` and
`one_based_internal` variable order. Coefficients use normalized exact rational
strings. The importer requires sorted, unique nonzero linear terms followed by
sorted strict-upper-triangle quadratic terms. It rejects duplicate merging,
diagonal folding and every coefficient, scale or offset that Float64 cannot
represent **exactly**, including `1//3` and `9007199254740993//1`. There is no
rounding fallback. Isolated variables are preserved. The current statistics
schema requires both a nonempty linear group and a nonempty quadratic group;
this importer explicitly rejects empty groups before storage. All 243 current
audited Original candidates have both groups. Nullable statistics for linear-only,
quadratic-only or constant models need a separate schema/migration change and
are outside this collection release.

Exactness here means the represented saved polynomial. Generation used a
Float64 LP parser; this does not establish exact arithmetic on the original
decimal LP coefficients. The importer separately retains the saved JSONL byte
SHA256 and a canonical represented-polynomial fingerprint. The latter covers
dimension, binary domain, sense, scale, offset, variable order and every term.
It is compared before storage and after closing/reopening the HDF5 model;
different harmless JSON whitespace changes the byte hash but not this fingerprint.
The audit also streams the pinned Study writer's deterministic exact JSONL
representation from every reopened model into SHA256 and a byte counter. Both
must match the saved Original descriptor anchored by the immutable study report.
Thus coordinated edits to HDF5, SQL metadata and `BUILD.json` cannot redefine
the accepted model, even if the local acceptance receipt is removed. This check
does not retain a second copy of the Original JSONL in the release.

The domain gate requires zero recorded continuous-to-integer changes. All 243
current candidates pass that gate; none of the 22 continuous-source Sports
models has an accepted Original. Preserving an integer domain is only one
necessary condition. **LP-to-QUBO/source-problem equivalence is not established**
by this import, and source feasibility/optimality remain unknown.

Raw ToQUBO reformulation metadata is retained as a provenance descriptor, not
passed as `source_encoding`. QUBOLib's current affine decoding schema differs.
Until a validated adapter exists, `source_decoding` is
`unavailable_no_validated_adapter`; `project_solution` cannot decode these
models. Source LP text is embedded only when at most 1,000,000 bytes; the exact
LP bytes and hash remain in the candidate's generated-provenance directory.

No solutions are imported. Raw reference objective/optimality annotations,
reconstruction probes and preprocessing certificates are not inherited as
generated-model optima, incumbents or source witnesses. This release path adds
no `SolutionRecords`.

## Prepare saved inputs

Use a resource-bounded execution environment for actual saved-model import.
The Python preparation helper only checks metadata and copies/hashes existing
files. It never generates or evaluates a QUBO. The fixed production authority
is the final report SHA256
`f539c7e04ee2ca959f328c461865a71a9a14c12bab137f46f84377698fa7baee`.
All 347 outcomes and each selected audit/polynomial identity must match those
actual report bytes; a declared hash alone is insufficient.
The source identity plan is also required, pinned at
`a8acdd4db972f27d3b48cccf0fa729c496e43bac3d39adceff218f4f5be54113`.
It independently anchors source blob IDs, formulations and recorded domain
requirements that cannot be recovered from a redacted private case receipt.

```sh
python3 -B scripts/build/prepare_qoblib_toqubo.py \
  --report /inputs/approved-final/results.jsonl \
  --source-plan /inputs/qoblib_missing_expansion.json \
  --phase-root RUN_ID=/retained/actual-run \
  --attribution-root /inputs/upstream-attribution \
  --license /inputs/qoblib-LICENSE.data \
  --upstream-readme /inputs/qoblib-README.md \
  --collection-version 2026-11-13-originals-1 \
  --case-id birkhoff-0001 --materialize --max-bytes 268435456 \
  --out /fresh/pilot-inputs
```

Supply one `--phase-root RUN_ID=PATH` for each actual producing phase needed by
the selection. Each must contain `cases/CASE_ID/audit.json`, `input/case.json`,
`input/source.lp`, and `results/` with the audit-bound polynomial/order/domain
files and `environment.json`. No Julia Serialization/native proof is opened.
For the full candidate, omit `--case-id`; all 243 audit-backed Originals must
then be selected, while the outcome ledger still includes all 347. Set an
explicit byte allowance appropriate to that export before materializing it.
The current saved inputs exceed the helper's default 8 GiB allowance; a bounded
full export uses `--max-bytes 17179869184` (16 GiB), with the same source-plan,
attribution and four producing-phase inputs, and no `--case-id` option. This
is a saved-file materialization allowance, separate from the execution job's
memory, scratch and wall limits. It does not authorize regeneration or retries.

Without `--materialize`, the helper writes a deliberately non-import-ready
metadata plan. `FETCH-PRIVATE.json` contains operational source paths and is
mode 0600; it must not be published. `--remote-root RUN_ID=PATH` can give that
private plan the actual retained remote origin while reading audit receipts
from a returned local metadata snapshot. Public manifests use only logical
run IDs, repository paths and content-addressed input names.

The release retains the pinned CC-BY-4.0 license, upstream README and all 23
retrieved family/formulation attribution README files. Each source model joins
its ancestor attribution paths. The manifest records source/provider URLs,
the modification notice, and the source/compiler snapshots. Private operational
paths from the raw case manifest are replaced by a public source-identity
projection, with the raw-case SHA256 retained.

## Import, audit and build an opt-in release candidate

The importer uses the existing QUBOLib environment plus SHA/Tar standard
libraries. It has no ToQUBO or QUBOPreprocessing dependency.

```sh
julia --project=. scripts/build/test_qoblib_toqubo.jl
julia --project=. scripts/build/qoblib_toqubo.jl build \
  /fresh/pilot-inputs/manifest.json /fresh/pilot-candidate
julia --project=. scripts/build/qoblib_toqubo.jl audit /fresh/pilot-candidate
julia --project=. scripts/build/qoblib_toqubo.jl pack \
  /fresh/pilot-candidate /fresh/pilot-release
```

The destination must not exist. A failed candidate is retained with no accepted
receipt; SQLite/HDF5 cross-store crash atomicity or resuming failed builds is
not claimed. Models are processed one at a time. The accepted candidate has
only `qoblib_toqubo`, its complete source-outcome ledger, source/order/audit
provenance, and no solution records. `audit` reopens every model and checks the
represented fingerprint, source identity and retained provenance.
It first refuses missing, linked or misplaced store files; it never installs
the default artifact. Retained audit/environment/domain/order bytes are rebound
to the immutable report and source plan. Public case projections require their
exact field set and source values. Model/solution metadata, solution payloads,
solver/submission rows, extra SQL objects and extra HDF5 groups are rejected.

`pack` requires an already audited candidate and builds a fresh temporary copy;
it leaves the candidate unchanged and can be repeated into a new output.
It writes `qoblib_toqubo.tar.gz`, `RELEASE-CANDIDATE.json` and a **separate**
`Artifacts.toml.example`. It records both archive SHA256 and Julia artifact
tree SHA1; it does not upload, tag, alter `Artifacts.toml` or change the default
artifact. Packaging requires the exact recursively allowed public inventory,
including redistribution files; unexpected files, empty directories, symbolic
links and special nodes are rejected. The output must remain outside the
candidate after resolving existing symbolic-link components, including when
the remaining output path does not exist. Before publication, independently extract this candidate and repeat
the audit/collection count, tree hash and archive hash checks. Complete the
small existing-model pilot before the bounded full saved-body export. A pilot
receipt explicitly records `selection_scope=pilot` and the eligible Original
count; it never establishes that all 243 imported.

The optional artifact has `index.db` and `archive.h5` at its root. Extract it
under a writable `WORK/qubolib/` directory, then use `QUBOLib.access(; path=WORK)`.
Its manifest/build/acceptance files and redistribution directory travel with
the artifact. `qoblib_toqubo.jl audit WORK` also recognizes that extracted layout.
