# Staging follow-up results

The internal script `scripts/import_followup_results.jl` prepares a **new private
copy** of a catalogue for review. It does not update the installed data artifact,
`Artifacts.toml`, the historical preprocessing fields, or the released builder's
preprocessing policy. It is intended for the follow-up to issue #106; it does not
complete that issue's release and full-census acceptance criteria.

The importer accepts completed output directories from the reviewed
`capture_library_witnesses.jl` runner. Each directory must contain
`run-plan.json`, `records.jsonl`, and `terminal.json`. The terminal record hash,
record count, and planned instance/mode inventory must agree. A completed run can
include explicitly recorded errors or capacity guards. Those rows remain failed
or skipped measurements, with no inferred result.

## Explicit source and verification pins

Run the real catalogue staging step on Dantzig, using an environment that resolves
this QUBOLib checkout, the capture runner's pinned QUBOPreprocessing version, and
the reviewed witness helper's dependencies. No package installation or environment
mutation is performed by the importer.

```sh
julia --project=/path/to/pinned/environment scripts/import_followup_results.jl \
  --source-database=/path/to/immutable/index.db \
  --source-archive=/path/to/immutable/archive.h5 \
  --database-sha256=EXPECTED_SOURCE_DATABASE_SHA256 \
  --archive-sha256=EXPECTED_SOURCE_ARCHIVE_SHA256 \
  --artifact-tree=SOURCE_ARTIFACT_GIT_TREE_SHA1 \
  --run-id=frozen-census-run-id \
  --expected-instance-count=9294 \
  --runs=/path/to/shard-01,/path/to/shard-02 \
  --output=/path/to/NEW-review-stage \
  --witness-tools=/path/to/reviewed/library_witnesses.jl \
  --witness-tools-sha256=REVIEWED_HELPER_SHA256
```

The source database must be a checkpointed, immutable SQLite snapshot, with no
nonempty WAL. The caller supplies both source-file SHA256 values and the source
artifact tree identifier. The importer hashes both files, copies them, checks
the copies, and binds every imported row to that snapshot. Per-model content
hashes are checked against freshly loaded catalogue models. A skipped input
without a model hash remains bound only to the snapshot and instance identity.
Source artifact identity is recorded as an explicit caller pin; the two SHA256
checks establish the exact files used in this import.

The global planned instance count is explicit, so omitting a shard cannot pass as
the full census. Use the frozen target count of a targeted validation batch when
staging that batch separately.

An input bundle's capture-helper hash and the import verifier's independently
pinned hash are retained separately. This permits a reviewed newer checker to
replay older evidence. The importer never treats the capture receipt as proof.
Every solution witness is rechecked against its freshly loaded original Boolean
or Spin QUBO. Native Spin coefficients and their source hash are preserved; the
importer does not obtain a source identity by casting coefficients to Boolean
floating point. The helper path must be supplied explicitly; there is no bundled or silently
selected proof decoder.

## Versioned preprocessing measurements

New rows are appended to `Instances.metadata.preprocessing_runs` under schema
`qubolib-preprocessing-run-v1`. Existing `metadata.preprocessing`, legacy
`n_strong`/`m_strong` metadata or columns, and unrelated metadata are retained.
Each entry contains:

- A key and SHA256 binding the model, runner/package revision and package tree,
  schedule, target preprocessing allowance, mode, integerization setting, and
  explicit run ID. Heuristic/seed/attempt identifiers distinguish candidate
  curation attempts when present.
- Original and reduced dimensions, edge counts and density; proof rule counts;
  named timing phases; scheduler report and stop reason; guards and errors.
- Input normalization, perturbation, materialization and rounding information.
  The accepted capture format uses `rounding=:nearest`; this records the runner's
  policy rather than claiming that the floating materialization is exact.
- Source catalogue/archive/instance identity, capture plan/result/terminal hashes,
  runner-file hashes, helper hashes, and any witness hash.
- Reported verification separately from independent replay. Missing proof or a
  nonzero residual never becomes a global certificate. A compact feasible-state
  witness verifies its original solution, not the reported reduction metrics.

The complete reported row is retained as diagnostic provenance. For example, a
backend's `optimal` status can remain in this diagnostic record while the
authoritative imported `global_optimal` field is false. A duplicate or conflicting
existing key is rejected; run IDs must not be silently reused to replace data.

The five-second target of the census is a **soft preprocessing target per mode**.
Workspace creation, scheduling, materialization, and accounting are included by
the capture runner. Loading, source hashing, certificate replay, witness storage,
and any solver execution are separately recorded. The importer preserves that
scope and does not relabel it an end-to-end solver deadline.

## Solution records and proofs

A retained witness uses an encoded binary vector. For a stored Boolean model,
those bits are the original state. For a stored Spin model, the original state is
`s = 2x - 1`. The importer checks the objective exactly using that native state
and the loaded source's stored IEEE coefficients, scale, offset, and objective
sense. Exact rational objectives are preserved in
solution metadata; finite `Float64` values populate the existing catalogue
columns. The existing catalogue's best-solution ordering still uses those
floating columns. When two exact values round to the same float, this utility
does not claim to repair that ordering policy.

Validated states are written through `QUBOLib.add_solution!` with a proper
`QUBOTools.SampleSet`, producing both HDF5 `Solutions` data and a linked
`SolutionRecords` row. HDF5 states retain the stored domain: Boolean states use
`0/1`, while Spin states use `-1/+1`. The linked SQL bitstring and metadata retain
the encoded `0/1` vector and its explicit mapping. The exact-derived objective is
passed explicitly, avoiding an implicit floating domain conversion. New submissions retain the capture run identity. Declared
predecessor record/submission references are checked against the same instance.

`proven_optimal=true` is passed explicitly only when independent exact replay
establishes an unconditioned, unperturbed original-QUBO proof with zero remaining
variables. Native solver status, result JSON flags, and a feasible point do not
establish this conclusion. Nonzero results and compact feasible witnesses have
`proven_optimal=false`.

Feasibility in the stored Boolean or Spin QUBO is recorded separately from
feasibility in an upstream source QOBLIB model. The latter remains unknown
(`source_feasible=NULL`); this script
does not contain a native-source checker or authorize an upstream submission.

## Review, failure, and release boundary

### Feasible points outside preprocessing capture runs

`scripts/import_validated_points.jl` imports separately retained feasible points
into another **new private copy**. This route is useful for a solver endpoint
that has a validated original state but no preprocessing capture record. It
does not synthesize a preprocessing measurement or append anything to
`Instances.metadata.preprocessing_runs`. Every original `Instances` value and
existing solution/submission row remains intact.

The input is an explicitly SHA-256-pinned JSON bundle with schema
`qubolib-validated-points-v1`. It identifies the exact parent database/archive,
the ancestral artifact snapshot, an import ID and provenance, and one point per
instance. Each point contains the catalogue identity, native model hash, encoded
state hash, relative state-file path/hash, canonical exact objective `p/q`, and
provenance. State files are exactly the binary vector followed by one LF. Files
must remain inside the bundle directory. The ancestral snapshot fields preserve
declared lineage; the exact parent file hashes and freshly checked native model
hash bind the files actually consumed by this import.

```sh
julia --project=/path/to/pinned/environment scripts/import_validated_points.jl \
  --source-database=/path/to/immutable-parent/index.db \
  --source-archive=/path/to/immutable-parent/archive.h5 \
  --database-sha256=EXPECTED_PARENT_DATABASE_SHA256 \
  --archive-sha256=EXPECTED_PARENT_ARCHIVE_SHA256 \
  --bundle=/path/to/point-bundle/points.json \
  --bundle-sha256=EXPECTED_BUNDLE_SHA256 \
  --output=/path/to/NEW-point-stage \
  --witness-tools=/path/to/reviewed/library_witnesses.jl \
  --witness-tools-sha256=REVIEWED_HELPER_SHA256
```

The CLI is restricted to Dantzig. It loads each original model through the
explicitly pinned native canonicalizer, checks its hash and domain, validates the
binary vector and recomputes its objective using exact rational arithmetic.
An earlier audit receipt or numerical solver status is retained as provenance,
not accepted as verification. A changed state, objective, source, domain or hash
is rejected. The existing finite floating objective columns remain in use;
the exact rational objective is also retained in the solution metadata.

This route always inserts **feasible-only** solution records with
`proven_optimal=false`, including when an upstream solver reported optimality.
It records upstream native-source feasibility as unknown and leaves SQL
`source_feasible`, `source_value` and `source_objective` null. It provides no
new reduction proof or global certificate. All inserts use one transaction;
on failure, the new copy is marked unpublishable and its inserted SQL/HDF5
solution entries are rolled back. The source files are rehashed after staging.
Neither script publishes a dataset or changes an installed artifact.

The synthetic test `test/validated_points_import.jl` exercises native Bool/Spin
states, both objective senses, exact decimal binary64 coefficients, source and
state tampering, preservation of every pre-existing SQL row, and rollback. It
uses the same explicit `FOLLOWUP_WITNESS_TOOLS`/`FOLLOWUP_WITNESS_SHA256` pins as
the capture-import fixture tests. Real catalogue points must be checked on
Dantzig rather than evaluated by these local fixtures.

Successful output contains `index.db`, `archive.h5`, and `diff-report.json` with
source and staged hashes, inserted record IDs, counts, and proof classifications.
Review those artifacts and the exact witnesses before proposing a new dataset.
This utility neither publishes an asset nor changes an artifact pin.

All imported database changes use one transaction. A malformed later row rolls
back earlier inserts and metadata updates; newly created HDF5 solution groups
are removed from this private copy. A failed stage remains on disk with
`failed-import.json` and must not be published. Existing output directories are
always rejected; there is no overwrite, retry, or resume mode.

The standalone synthetic test file `test/followup_import.jl` exercises actual
SQLite and QUBOLib HDF5 APIs, exact replay, a typed verifier adapter, forged global
claims, identity mismatches, native Spin state roundtrips, cancellation-sensitive
exact Spin objectives, and rollback after HDF5 insertion. Supply the exact
reviewed helper via `FOLLOWUP_WITNESS_TOOLS` and `FOLLOWUP_WITNESS_SHA256`; run only
tiny fixtures locally under the project's memory/thread limits. These tests do
not run the library census or a native solver.
