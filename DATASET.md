# QUBOLib Dataset Provenance and Publication Status

QUBOLib distributes benchmark data separately from the Julia package source.
This document records the evidence needed to preserve and cite that data. The
machine-readable companion is [`DATASET.toml`](DATASET.toml).

## Selected artifact

This repository's [`Artifacts.toml`](Artifacts.toml) selects
[`v0.2.6-data+9`](https://github.com/JuliaQUBO/QUBOLib.jl/releases/tag/v0.2.6-data%2B9)
for package 0.2.7. Previously tagged packages retain their original pins.

| Property | Recorded value |
|:--|:--|
| Release target commit | `3c98d5f15e49e3e4c92b80280abda055d74e88eb` |
| Asset | `qubolib.tar.gz` |
| Compressed size | 743,873,521 bytes |
| SHA-256 | `5559c7fd070a61e6d17f9ef53393b9694f7c51b353ae0b191c30b78f90dec5bf` |
| Julia artifact tree hash | `5e791d1cff8d443e0ca8bfc5c7d9cf286e638df1` |
| Archive members | `archive.h5`, `index.db` |
| Populated collections | 7 |
| Instances | 9,294 |
| Inventory date | 2026-11-05 |

All six GitHub release downloads match the retained independent SHA256 inventory.
The archive contains only the database and HDF5 files. The five accompanying
files are `release-manifest.json`, `DERIVATION.json`, `DERIVED_RESULTS_NOTICE.txt`,
`provenance-assets.tar.gz`, and `publication-inventory-addendum.json`; their exact
sizes, hashes and URLs are recorded under `derivation` in `DATASET.toml`.
The portable supplement includes the reviewed checker, original metadata,
rights notices, and public input-location instructions. It verifies byte identity
and retained lineage; it does not rerun scientific experiments or proof replay.

This is a layered append to immutable `v0.2.4-data+8`. The first layer adds
19,052 preprocessing histories and 3,527 solution records, including 1,435
capture proof records covering 622 distinct stored QUBOs. The second adds six
separately feasible points and zero preprocessing/proof records. Its importer
commits are `af32a2885e4406bb4869cf1407a7241d933c6cc4` and
`971d449cb7d09a911d22ef22f1c44dc3e7a13bf4`, respectively. The exact source,
input/output, environment and audit bindings are retained in `DERIVATION.json`.
Native-source feasibility remains unknown where stated; these additions make
no literature-novelty claim and do not establish an integerization-only effect.

The original flat preprocessing fields, models, source attribution and earlier
records are preserved. The parent mixes historical uncommitted code states;
`build_commit_status = "not-reproducible"` therefore remains explicit. The
selected `build_commit` is the release target, not a claim that one clean commit
rebuilds the full corpus. `parent_artifact` retains the original target and full
explanation, and `preprocessing` describes only the parent's v0.1.5 flat fields.
The capture code and measurements precede the default-builder migration.

Dataset Zenodo preservation for these new bytes is **pending** under the existing
concept `10.5281/zenodo.23027943`. No new dataset record ID or version DOI is
assigned here. The older dataset DOI below identifies only the parent. Software
source archives have a separate concept and must not be used as dataset citations.
Until preservation is verified, cite the exact GitHub data release above.

`index.db` is the relational catalog; `archive.h5` holds model and solution
payloads. To check the selected public file identity on a machine with space:

```bash
audit_dir="$(mktemp -d)"
gh release download 'v0.2.6-data+9' --repo JuliaQUBO/QUBOLib.jl \
  --pattern qubolib.tar.gz --dir "$audit_dir"
sha256sum "$audit_dir/qubolib.tar.gz"
tar -tzf "$audit_dir/qubolib.tar.gz"
mkdir "$audit_dir/extracted"
tar -xzf "$audit_dir/qubolib.tar.gz" -C "$audit_dir/extracted"
julia --startup-file=no -e \
  'import Pkg; println(bytes2hex(Pkg.GitTools.tree_hash(ARGS[1])))' \
  "$audit_dir/extracted"
```

Compare against the selected SHA256/tree above. Full lineage validation uses the
instructions in the independently hash-verified portable supplement.

## Historical parent `v0.2.4-data+8`

The historical parent `v0.2.4-data+8` updates `v0.2.4-data+7` by expanding the `mqlib` collection from 210 to 3,002
benchmark instances across all 18 source families (`100%` of `data/standard.csv`
`231 / 231` including all `21` `Palubeckis` instances `p3000_1`–`p7000_3` plus
`2,771` Tier 2 instances, with `246` heuristic bitstring solutions and
`2,825` value-only heuristic benchmark records across `38` heuristic solver
submissions from [`MQLib/MQLib`](https://github.com/MQLib/MQLib) commit
`585496274af5abb0849d0d47e135496b4688680b`), enabling chunked HDF5 `deflate`
compression (`level = 3`), and enriching all 9,294 instances
with certified `QUBOPreprocessing.jl` v0.1.5 reduction metadata (`n_strong`,
`m_strong`, `n_weak`, `m_weak`) and coercive local-field diagnostics
(`coercive_fields`), 343 exact ground states on instances reduced to zero
residual variables (`333` on `mqlib`, `6` on `qoblib`, `3` on `minlplib`, and
`1` on `qplib`), and 51 repaired solution records (`32` on `qoblib`, `16` on
`mqlib` across `14` instances, and `3` on `minlplib`), and is preserved
unchanged in [Zenodo record 23839797](https://zenodo.org/records/23839797).

| Zenodo identifier | Use |
|:--|:--|
| [10.5281/zenodo.23027943](https://doi.org/10.5281/zenodo.23027943) | Concept DOI for the corpus across versions |
| [10.5281/zenodo.23839797](https://doi.org/10.5281/zenodo.23839797) | Version DOI for the exact `v0.2.4-data+8` archive |

Published on 2026-10-31 (UTC) under CC BY 4.0 and MIT per-collection terms, with collection-specific
attribution and conversion notices. Both the draft download and the public
download were compared byte-for-byte against an independent GitHub download;
their compressed size, SHA-256, and extracted Julia tree hash match the parent bindings in `DATASET.toml`.
The verification timestamp and registration
evidence are recorded in `DATASET.toml`.

## Historical September QOBLIB snapshot

The importer now uses QOBLIB
[`16a166ee67c24c112551c803aab5394743b815b5`](https://github.com/ZIB-AOPT/QOBLIB/tree/16a166ee67c24c112551c803aab5394743b815b5).
This includes Parallel ILS, merged through upstream PR #33 after replacing
PR #22, and the subsequent portfolio, LABS, market-split, and MIS updates.
The snapshot retains the
[CC-BY-4.0 data license](https://github.com/ZIB-AOPT/QOBLIB/blob/16a166ee67c24c112551c803aab5394743b815b5/LICENSE.data).

The full corpus was rebuilt on 2026-09-28 with Julia 1.10.11 at QUBOLib commit
`8735aa035a082401a01b5cb2540bd1ebaf00c675`. The three XORSAT sources and QPLIB
source were checked against the mirror hashes in `DATASET.toml`; their source
snapshots and instance counts are unchanged. The selected artifact contains
433 QOBLIB instances, with 392 reference solutions and 41 missing references.

The QOBLIB solution-record inventory is:

| Class | Instances | Validated | Unmapped | Unavailable | Missing reference |
|:--|--:|--:|--:|--:|--:|
| LABS | 99 | 605 | 0 | 99 | 0 |
| Market Split | 156 | 451 | 0 | 60 | 41 |
| Maximum Independent Set | 50 | 704 | 0 | 0 | 0 |
| Portfolio Optimization | 128 | 271 | 113 | 0 | 0 |
| Total | 433 | 2,031 | 113 | 159 | 41 |

These are record counts, not unique solutions or instances. `validated` means
the assignment was mapped and evaluated on the stored QUBO; it does not certify
source-model feasibility or optimality. `unavailable` submissions have no
usable solution file, and `missing` records identify absent reference solutions.
All 50 Parallel ILS assignments are included, including source objectives 96
for `frb100-40` and 53 for `frb53-24-1` (QUBO values -96 and -53).

Portfolio positions are converted to ordered copy slots and reconstructed
capital/budget slack bits, not the original solver bitstrings. All 128 curated
reference objectives match their evaluated QUBO values. The 113 unmapped
portfolio submissions have infeasible slack values and remain metadata-only;
no assignment is invented. Compact market-split bitstrings and MIS full bit
vectors are now supported alongside the existing formats.

These instructions describe the September snapshot, not a rebuild of the selected
layered artifact or its mixed-history parent. To reproduce that earlier build,
check out its recorded build commit, instantiate
`scripts/build`, and run `build_qubolib!(destination; clear_build = true)` from
`scripts/build/build.jl` in a fresh destination. It downloads the pinned sources;
`QUBOLIB_QOBLIB_SOURCE` can instead point to a clean checkout of the exact
QOBLIB commit. Before packaging, set `dist/build/last.tag` under the destination
to `v0.2.0-data+3` so the generated successor is `v0.2.4-data+4`. Package locally
with `QUBOLib.access(index -> deploy_qubolib!(index); path = destination)`;
the function writes local release files but does not upload them. Re-audit any rebuilt bytes: database
serialization and dependency resolution can change the artifact hashes.

For preservation, download the published archive rather than rebuilding it.
Future data releases must repeat the publication and verification steps in
[`RELEASE.md`](RELEASE.md#archive-the-selected-github-release).
[`Artifacts.toml`](Artifacts.toml) retains the GitHub download URL. Zenodo
preserves the historical parent; preservation of the selected successor is pending. Adding an
automatic artifact fallback is not required for preservation.

## Collection audit

| Collection | Instances | Provenance | Redistribution rights | Citation |
|:--|--:|:--|:--|:--|
| `arXiv-1903-10928-3r3x` | 3,200 | Verified by rights-holder statement | CC-BY-4.0 verified | [10.1103/PhysRevApplied.12.011003](https://doi.org/10.1103/PhysRevApplied.12.011003) |
| `arXiv-1903-10928-5r5x` | 307 | Verified by rights-holder statement | CC-BY-4.0 verified | [10.1103/PhysRevApplied.12.011003](https://doi.org/10.1103/PhysRevApplied.12.011003) |
| `arXiv-2103-08464-3r3x` | 2,300 | Verified by rights-holder statement | CC-BY-4.0 verified | [10.1088/2058-9565/ac4d1b](https://doi.org/10.1088/2058-9565/ac4d1b) |
| `qplib` | 23 | Verified at reconstructed source commit | CC-BY-4.0 verified | [10.1007/s12532-018-0147-4](https://doi.org/10.1007/s12532-018-0147-4) |
| `qoblib` | 433 | Verified at pinned commit | CC-BY-4.0 verified | [10.1038/s43588-026-00991-1](https://doi.org/10.1038/s43588-026-00991-1) |
| `minlplib` | 29 | Verified at pinned version | CC-BY-4.0 verified | [10.1287/ijoc.15.1.114.15159](https://doi.org/10.1287/ijoc.15.1.114.15159) |
| `mqlib` | 3,002 | Verified at pinned commit | MIT verified | [10.1287/ijoc.2017.0798](https://doi.org/10.1287/ijoc.2017.0798) |

The three XORSAT mirror ZIPs contain instance files but no embedded license
notice. Itay Hen subsequently supplied an
[explicit written grant](https://github.com/JuliaQUBO/QUBOLib.jl/issues/70#issuecomment-5132166520)
confirming that he owns or is authorized by all applicable rights holders to
license the three named archives under CC BY 4.0. The grant authorizes QUBOLib
to reproduce, host, redistribute, reformat, convert, and package them through
GitHub Releases and Zenodo. QUBOLib parses the Qubist source files and stores
the converted models in HDF5 and SQLite. The dataset record must retain the
source-paper attribution and CC BY 4.0 notice and identify this conversion.

[QPLIB states that the library is CC-BY-4.0](https://qplib.zib.de/). Its
maintainers confirmed that the website is the sole official distribution,
QPLIB has no numbered releases or historical archive, the underlying instance
definitions have not changed since inclusion, and attribution should cite the
QPLIB article and link to the official website. They also confirmed that
solution files and generated exports may be updated and identified the
[repository that feeds the website](https://gitlab.com/svigerske/qplib-web)
as the available change history.

The QUBOLib mirror was reconstructed against that repository. Its 46 `.lp` and
`.qplib` members were generated at 2018-09-23 11:23--11:24 UTC, after commit
[`4b681a2`](https://gitlab.com/svigerske/qplib-web/-/commit/4b681a263d9c2cb21e83f08e1b3232361dcedd5a)
at 11:12 UTC and before the next repository commit at 21:41 UTC. All 23
mirrored solution objective values match the metadata at `4b681a2`.

A comparison on 2026-07-29 against official repository commit
`f601bec47cbafd7afe03aad30d5135d6676568f1` and the corresponding website
files found:

- all 23 `.lp` files byte-identical;
- all 23 `.qplib` files byte-identical except for the problem-type line changed
  from `QBB` to `QBN` by QPLIB's 2025 classification correction;
- 19 of 23 `.sol` files byte-identical; QPLIB subsequently updated
  `QPLIB_3650.sol`, `QPLIB_3693.sol`, `QPLIB_3850.sol`, and
  `QPLIB_5721.sol`.

QUBOLib redistributes a processed subset of QPLIB. The build selects the 23
`QBB` instances, parses each `.qplib` model with the `.qplib` specification's
`0.5` quadratic objective scaling, uses the `.lp` variable names to map `.sol`
entries, cross-references upstream `MINLPLib` and `BiqMac` optimality bounds
(`11` proven optimal, `12` open), and stores the resulting models and solutions
in the artifact's HDF5 and SQLite files. The dataset record must identify these
changes, retain the QPLIB article and website attribution, and include the
CC-BY-4.0 notice.

[MINLPLib states that the library is CC-BY-4.0](https://www.minlplib.org/).
QUBOLib selects the 29 pure binary unconstrained QUBO instances in MINLPLib
version `9472b011` not already included in QPLIB (`2` `autocorr_bern`, `20`
`chimera_*`, and `7` `sporttournament06..20` instances; `sporttournament14` is
excluded because 70 of its 91 variables are continuous in MINLPLib), parses
POLIP (`.pip`) models and 42 `.p*.sol` solution records, factors exact `0.1`
scaling where applicable, and stores the resulting models and solutions in HDF5
and SQLite.

QOBLIB commit
[`16a166ee67c24c112551c803aab5394743b815b5`](https://github.com/ZIB-AOPT/QOBLIB/tree/16a166ee67c24c112551c803aab5394743b815b5)
contains a CC-BY-4.0 data license. The dataset record must retain the QOBLIB
attribution, source commit, and citation.

[MQLib commit `585496274af5abb0849d0d47e135496b4688680b`](https://github.com/MQLib/MQLib/tree/585496274af5abb0849d0d47e135496b4688680b)
is [MIT-licensed](https://github.com/MQLib/MQLib/blob/585496274af5abb0849d0d47e135496b4688680b/LICENSE). Preserve the full upstream copyright and permission notice;
the file is named `LICENSE`, not `LICENSE.md`. QUBOLib imports 3,002 benchmark instances across all 18 source
families (`100%` of `data/standard.csv` `231 / 231` including all `21`
`Palubeckis` instances `p3000_1`–`p7000_3` plus `2,771` Tier 2 instances),
converts Max-Cut and master-node QUBO edge lists to canonical `:bool`/`:max`
QUBO models with chunked HDF5 `deflate` compression (`level = 3`), attaches 246
heuristic bitstring solutions and 2,825 value-only benchmark records
across 38 heuristic solver submissions from `data/results.zip` and `data/results_imgseg.zip`, and records the
394 remaining ultra-dense Tier 2 instances in `deferred_synthetic_instances` (`deferred_total_instances = 394`).

The repository's MIT license covers QUBOLib software. It does not replace the
collection-specific data terms above. All seven included collections have
verified CC-BY-4.0 or MIT terms, so the Zenodo license field can identify CC BY 4.0
while retaining each collection's attribution and conversion notices. This
does not grant rights to other upstream material or to future collections.

## Citation guidance

- Cite the
  [QUBO.jl ecosystem article](https://doi.org/10.1080/10556788.2026.2702926)
  for the general JuliaQUBO methods and software ecosystem.
- Cite QUBOLib software using [`CITATION.cff`](CITATION.cff), and identify the
  package version used when reproducibility depends on it.
- Cite the [dataset concept DOI](https://doi.org/10.5281/zenodo.23027943) for
  the corpus across versions. Cite the selected `v0.2.6-data+9` GitHub release
  until its dataset version DOI is verified. The
  [older version DOI](https://doi.org/10.5281/zenodo.23839797) identifies only
  `v0.2.4-data+8`. Also cite each source
  collection used. A dataset DOI does not identify the Julia package version.

## Zenodo publication gate

`DATASET.toml` records the selected version's Zenodo status as `blocked` pending
new-version draft access, byte identity, related identifiers and public DOI
verification. The parent publication evidence is preserved separately under
`parent_zenodo`; it does not verify a successor draft. The designated-owner
exception remains in force.

Before publishing any successor, all of the following must be true:

1. Every populated collection has verified provenance and redistribution
   rights.
2. The exact release asset, SHA-256, and Julia tree hash are recorded.
3. The dataset description includes the schema, collection inventory,
   provenance, licenses, citations, and reproduction instructions.
4. David Bernal (`bernalde`) has verified owner/manager access under the
   [2026-08-01 stewardship decision](https://github.com/JuliaQUBO/QUBOLib.jl/issues/70#issuecomment-5153545937).
   This supersedes the two-manager completion gate; it does not verify access
   by itself. Use his personal account without sharing credentials, and revisit
   a backup manager annually or when maintainership changes.
5. Related identifiers connect the dataset, repository, package and data
   releases, upstream sources, and ecosystem article.
6. A downloaded Zenodo file is byte-identical to the selected GitHub asset.

Run the ordinary package release preflight with:

```bash
julia --project=. scripts/release_check.jl
```

Before a dataset publication, require the stronger gate:

```bash
julia --project=. scripts/release_check.jl --require-dataset-publishable
```

The stronger command must currently fail: the selected version remains
`blocked` until its required new-version preservation evidence is verified.
