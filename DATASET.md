# QUBOLib Dataset Provenance and Publication Status

QUBOLib distributes benchmark data separately from the Julia package source.
This document records the evidence needed to preserve and cite that data. The
machine-readable companion is [`DATASET.toml`](DATASET.toml).

## Selected artifact

This repository's [`Artifacts.toml`](Artifacts.toml) selects
[`v0.2.4-data+4`](https://github.com/JuliaQUBO/QUBOLib.jl/releases/tag/v0.2.4-data%2B4)
for the package. Previously tagged package versions retain their original
artifact pins; publishing a data release does not modify them.

| Property | Recorded value |
|:--|:--|
| Release tag commit | `6fb487e1982857253afd7b20fc30868452b4d001` |
| Asset | `qubolib.tar.gz` |
| Compressed size | 102,890,681 bytes |
| SHA-256 | `276eb06a66cec325cd3ec895cded7ba28f848aeb3998f4944466acbb33bcd001` |
| Julia artifact tree hash | `90da567266bc93ffb76cc0435691409557d500fc` |
| Archive members | `archive.h5`, `index.db` |
| Populated collections | 5 |
| Instances | 6,263 |
| Inventory date | 2026-09-28 |

The SHA-256 was recomputed from the GitHub release asset. The inventory was
queried from the asset's SQLite index. A Zenodo upload must use these exact
bytes; rebuilding the database is not an equivalent archive. This release is
the selected first Zenodo version. It was published to GitHub unchanged from
the candidate audited in PR #77 and preserved unchanged in
[Zenodo record 23027944](https://zenodo.org/records/23027944).

| Zenodo identifier | Use |
|:--|:--|
| [10.5281/zenodo.23027943](https://doi.org/10.5281/zenodo.23027943) | Concept DOI for the corpus across versions |
| [10.5281/zenodo.23027944](https://doi.org/10.5281/zenodo.23027944) | Version DOI for the exact `v0.2.4-data+4` archive |

Published on 2026-09-29 (UTC) under CC BY 4.0, with collection-specific
attribution and conversion notices. Both the draft download and the public
download were compared byte-for-byte against an independent GitHub download;
their compressed size, SHA-256, and extracted Julia tree hash match the table.
Both DOI.org links were verified on 2026-09-29 to resolve to the published
record. DataCite reports both identifiers as findable under the title
"QUBOLib benchmark corpus". The verification timestamp and registration
evidence are recorded in `DATASET.toml`.

`index.db` is the relational catalog of collections, instances, and solutions.
`archive.h5` stores the corresponding models and solution payloads. Reproduce
the recorded file identity and populated-collection counts with:

```bash
audit_dir="$(mktemp -d)"
gh release download 'v0.2.4-data+4' \
  --repo JuliaQUBO/QUBOLib.jl \
  --pattern qubolib.tar.gz \
  --dir "$audit_dir"
sha256sum "$audit_dir/qubolib.tar.gz"
tar -tzf "$audit_dir/qubolib.tar.gz"
mkdir "$audit_dir/extracted"
tar -xzf "$audit_dir/qubolib.tar.gz" -C "$audit_dir/extracted"
julia --startup-file=no -e \
  'import Pkg; println(bytes2hex(Pkg.GitTools.tree_hash(ARGS[1])))' \
  "$audit_dir/extracted"
sqlite3 "$audit_dir/extracted/index.db" \
  'SELECT collection, COUNT(*) FROM Instances GROUP BY collection ORDER BY collection;'
```

The expected SHA-256 and tree hash are the values in the table above. The SQL
query must return the same five collection counts recorded below.

## September QOBLIB snapshot

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

To reproduce the build, check out the recorded build commit, instantiate
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
provides an independently verified preservation copy; adding it as an
automatic artifact fallback is not required for preservation.

## Collection audit

| Collection | Instances | Provenance | Redistribution rights | Citation |
|:--|--:|:--|:--|:--|
| `arXiv-1903-10928-3r3x` | 3,200 | Verified by rights-holder statement | CC-BY-4.0 verified | [10.1103/PhysRevApplied.12.011003](https://doi.org/10.1103/PhysRevApplied.12.011003) |
| `arXiv-1903-10928-5r5x` | 307 | Verified by rights-holder statement | CC-BY-4.0 verified | [10.1103/PhysRevApplied.12.011003](https://doi.org/10.1103/PhysRevApplied.12.011003) |
| `arXiv-2103-08464-3r3x` | 2,300 | Verified by rights-holder statement | CC-BY-4.0 verified | [10.1088/2058-9565/ac4d1b](https://doi.org/10.1088/2058-9565/ac4d1b) |
| `qplib` | 23 | Verified at reconstructed source commit | CC-BY-4.0 verified | [10.1007/s12532-018-0147-4](https://doi.org/10.1007/s12532-018-0147-4) |
| `qoblib` | 433 | Verified at pinned commit | CC-BY-4.0 verified | [10.1038/s43588-026-00991-1](https://doi.org/10.1038/s43588-026-00991-1) |

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
`QBB` instances, parses each `.qplib` model, uses the `.lp` variable names to
map `.sol` entries, and stores the resulting models and solutions in the
artifact's HDF5 and SQLite files. The dataset record must identify these
changes, retain the QPLIB article and website attribution, and include the
CC-BY-4.0 notice.

QOBLIB commit
[`16a166ee67c24c112551c803aab5394743b815b5`](https://github.com/ZIB-AOPT/QOBLIB/tree/16a166ee67c24c112551c803aab5394743b815b5)
contains a CC-BY-4.0 data license. The dataset record must retain the QOBLIB
attribution, source commit, and citation.

The repository's MIT license covers QUBOLib software. It does not replace the
collection-specific data terms above. All five included collections have
verified CC-BY-4.0 terms, so the Zenodo license field can identify CC BY 4.0
while retaining each collection's attribution and conversion notices. This
does not grant rights to other upstream material or to future collections.

## Citation guidance

- Cite the
  [QUBO.jl ecosystem article](https://doi.org/10.1080/10556788.2026.2702926)
  for the general JuliaQUBO methods and software ecosystem.
- Cite QUBOLib software using [`CITATION.cff`](CITATION.cff), and identify the
  package version used when reproducibility depends on it.
- Cite the [dataset concept DOI](https://doi.org/10.5281/zenodo.23027943) for
  the corpus across versions. For the exact `v0.2.4-data+4` bytes, cite the
  [version DOI](https://doi.org/10.5281/zenodo.23027944). Also cite each source
  collection used. A dataset DOI does not identify the Julia package version.

## Zenodo publication gate

`DATASET.toml` records this version as `published`. The public
[record metadata](https://zenodo.org/api/records/23027944) identifies owner
1784890 and the 15 verified related identifiers. Authenticated creation,
upload, and publication verified the designated owner's access. This record
uses the single-owner exception, not a claim of two active managers.

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

The stronger command passes for the published version and must fail for a
successor whose status is `blocked` or whose required evidence is unverified.
