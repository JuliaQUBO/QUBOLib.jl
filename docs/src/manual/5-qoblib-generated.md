# Generated QOBLIB / ToQUBO collection

QUBOLib 0.2.9 offers 347 audited saved Original QUBOs in three opt-in artifacts.
You can load these binary objectives directly from their SQLite and HDF5 stores.
Fresh default installations select the canonical `v0.2.7-data+10` artifact.

This follows the separation described in [QUBOLib issue #47](https://github.com/JuliaQUBO/QUBOLib.jl/issues/47)
and [ToQUBO issue #145](https://github.com/JuliaQUBO/ToQUBO.jl/issues/145).
The earlier frozen manuscript study identified 243 import candidates. The
released-package study supplied 347 independently audited Originals, all of
which passed the import and HDF5 roundtrip audits for this release. The study
also audited both residual modes for all 347 cases. The archives contain the
Original objectives.

The normal QUBOLib density columns retain QUBOTools definitions: overall
`(2m+l)/n²`, linear `l/n`, and quadratic graph density `2m/[n(n-1)]` where
defined. They are distinct from the manuscript's QS upper-triangle density
`2(m+l)/[n(n+1)]`. The import does not overwrite these definitions.

## Install and open a generated artifact

| Artifact binding | Models | Source-domain variant |
| --- | ---: | --- |
| `qoblib_toqubo` | 305 | Integer-domain |
| `qoblib_toqubo_large` | 20 | Integer-domain, large Birkhoff models |
| `qoblib_toqubo_domain_restricted` | 22 | Explicit continuous-to-integer restriction |

```julia
using Pkg.Artifacts
using QUBOLib

binding = "qoblib_toqubo"
artifacts = joinpath(pkgdir(QUBOLib), "Artifacts.toml")
package_id = Base.PkgId(QUBOLib).uuid
ensure_artifact_installed(binding, artifacts; pkg_uuid = package_id)
tree = artifact_hash(binding, artifacts; pkg_uuid = package_id)
@assert verify_artifact(tree)

work = mktempdir()
library = joinpath(work, "qubolib")
cp(artifact_path(tree), library)
for store in ("index.db", "archive.h5")
    chmod(joinpath(library, store), 0o644)
end
model = QUBOLib.access(; path = work) do index
    QUBOLib.load_instance(index, 1)
end
```

Use a fresh work directory for each artifact. QUBOLib can write to both stores
in the working copy. Loading a large model materializes its polynomial in memory.
Both hosts provide the same archives and release manifest. Each archive
contains the upstream CC BY 4.0 data license and attribution, including
attribution for individual models.
[GitHub data release](https://github.com/JuliaQUBO/QUBOLib.jl/releases/tag/v0.2.9-data%2B12-qoblib-toqubo) ·
[Zenodo dataset DOI](https://doi.org/10.5281/zenodo.24417375)

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
this importer explicitly rejects empty groups before storage. All 347 released
Originals have both groups. Nullable statistics for linear-only,
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

The integer-domain variants require zero recorded continuous-to-integer
changes. The separate 22-model collection applies an explicit integer
restriction. Source-problem equivalence, feasibility and optimality remain
unverified for all three artifacts.

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

## Prepare saved inputs from the historical study

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

## Import, audit and pack a historical candidate

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

Pass `--stream-terms` after the build destination to prepare large opt-in
collections. The importer streams sorted quadratic terms into the standard QUBin
coordinate datasets in blocks of at most 65,536 terms and uses 32-bit
integer coordinates, dimensions and labels. It records the storage layout
explicitly and reopens the archive in
bounded blocks to verify both the represented fingerprint and the canonical
Original bytes against the pinned study. QUBOLib's ordinary model loader can
load the resulting archive. Loading a full instance still materializes its
polynomial in memory.

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

## Released 347-case cohort

The version 2 importer takes the final P3 report and source plan. It requires
an independently reviewed `RELEASED-STUDY-AUTHORITY.json` with schema
`qubolib-released-study-authority-v1`. Pin the exact authority SHA-256 through
a separate trusted channel. The document contains:

- `study_report_sha256`, `source_plan_sha256` and `auditor_sha256` from the
  independently accepted report, source plan and auditor.
- `release_identity_sha256` from the staged producer identity. Use the
  report summary's `release_identity.staged_identity_sha256`.
- `julia_version`, `project_sha256` and `manifest_sha256` from the clean,
  registered-package environment.
- `packages` with exactly `ToQUBO`, `QUBOPreprocessing` and
  `PseudoBooleanOptimization`. Each object contains its exact `version`,
  `commit` and `source_tree` (the report's `git_tree`). Use ToQUBO 0.8.2 and
  QUBOPreprocessing 0.2.2.
- `large_case_ids` with the independently reviewed large-model selection.

An eligible cohort has 347 accepted Original endpoints, each joined to a
complete metadata document and the registered producing stack. Audited partial
outcomes can contribute their Original while retaining their original status.
Generated metadata records the staged private exporter identity and the raw
metadata descriptor. The full metadata payload is held in the producing run.

Select `--variant integer-domain` for the 325 integer-domain inputs or
`--variant continuous-to-integer` for the 22 domain-restricted input variants.
The second group uses the explicit integerization policy and carries
`not_established_domain_restriction` as its source equivalence status. Both
variants retain unknown source feasibility and optimality. Also select
`--size-class regular` or `--size-class large`. The released restricted variant
has only a regular partition.

Each full partition contains all matching cases and carries the complete outcome
ledger. A pilot selects explicit case IDs inside one partition. Choose the
large membership in the authority before preparing any of the assets. All
bindings are opt-in. The default artifact continues to use `qoblib`.

Add `--released-authority PATH --released-authority-sha256 "$AUTHORITY_SHA256"`
and the variant and size class options to the Python prepare invocation above.
Map each logical producing run with `--phase-root RUN_ID=PATH`. Its selected
attempt contains `cases/CASE/a-ATTEMPT/work/audit.json`,
`work/input/{case.json,source.lp}` and `work/results/`. Keep this input tree
private.

```sh
julia --project=. scripts/build/qoblib_toqubo.jl build \
  /fresh/released-inputs/manifest.json /fresh/released-candidate \
  --stream-terms --released-authority-sha256 "$AUTHORITY_SHA256"
julia --project=. scripts/build/qoblib_toqubo.jl audit /fresh/released-candidate \
  --released-authority-sha256 "$AUTHORITY_SHA256" \
  --public-provenance-sha256 "$PUBLIC_PROVENANCE_SHA256"
julia --project=. scripts/build/qoblib_toqubo.jl pack \
  /fresh/released-candidate /fresh/released-package \
  --released-authority-sha256 "$AUTHORITY_SHA256" \
  --public-provenance-sha256 "$PUBLIC_PROVENANCE_SHA256"
```

Build all released partitions with `--stream-terms`. Compact records support up to 250,000
variables and 60 million quadratic interactions, including the audited
220,388-variable `steiner-1459` Original. Review the generated
`PUBLIC-PROVENANCE.json` from the private-input build and pin its SHA-256
outside the candidate before independent audit and packing. The file contains
an allowlisted projection of each Original audit and producing environment
plus the exact raw hashes. The build derives it after checking the raw
archives. Public audit checks the pinned projection, retained sidecars and
stored polynomial again. Complete the final content inspection on the actual
packed tree and independently audit the extracted archive with both pins
before publishing or adding its artifact binding.

## Export an audited Original as QOBLIB QS

Use the saved polynomial, independent audit receipt, and producing environment
selected from the accepted study report. The destination directory must be new.

```sh
julia --project=. scripts/build/export_qoblib_qs.jl \
  /inputs/original-polynomial.jsonl /inputs/audit.json \
  /inputs/environment.json /fresh/contribution
```

The directory contains the case's `.qs` file and `provenance.json`, with the
input and output hashes, source LP identity, generator package versions, audited
counts, and signed scale transformation. The converter folds the saved scale
into every coefficient and the objective offset, negates maximization
objectives for QS minimization, and writes one upper-triangle entry at half
weight per cross term for the symmetric matrix convention. The saved variable
order and isolated variables are preserved. Each emitted decimal and each
coefficient reconstructed by the QS reader must represent the exact converted
value. An unrepresentable value leaves the destination absent.
