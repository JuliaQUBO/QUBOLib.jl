# QUBOLib Dataset Provenance and Publication Status

QUBOLib distributes benchmark data separately from the Julia package source.
This document records the evidence needed to preserve and cite that data. The
machine-readable companion is [`DATASET.toml`](DATASET.toml).

## Selected artifact

The package currently selects
[`v0.1.0-data+2`](https://github.com/JuliaQUBO/QUBOLib.jl/releases/tag/v0.1.0-data%2B2)
through [`Artifacts.toml`](Artifacts.toml).

| Property | Recorded value |
|:--|:--|
| Release tag commit | `bc3d61098865ee0e44dc839f4a8cc62801fc7202` |
| Asset | `qubolib.tar.gz` |
| Compressed size | 101,268,540 bytes |
| SHA-256 | `e3826af0c2b7bed712b787304a28c57ff8fbb93543ef8c38fca1d8391a777387` |
| Julia artifact tree hash | `e27d0d1526f3491102ff447293b4be3725314db8` |
| Archive members | `archive.h5`, `index.db` |
| Populated collections | 5 |
| Instances | 6,263 |
| Inventory date | 2026-07-28 |

The SHA-256 was recomputed from the GitHub release asset. The inventory was
queried from the asset's SQLite index. A Zenodo upload must use these exact
bytes; rebuilding the database is not an equivalent archive.

`index.db` is the relational catalog of collections, instances, and solutions.
`archive.h5` stores the corresponding models and solution payloads. Reproduce
the recorded file identity and populated-collection counts with:

```bash
audit_dir="$(mktemp -d)"
gh release download 'v0.1.0-data+2' \
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

## Collection audit

| Collection | Instances | Provenance | Redistribution rights | Citation |
|:--|--:|:--|:--|:--|
| `arXiv-1903-10928-3r3x` | 3,200 | Partial | Pending written grant | [10.1103/PhysRevApplied.12.011003](https://doi.org/10.1103/PhysRevApplied.12.011003) |
| `arXiv-1903-10928-5r5x` | 307 | Partial | Pending written grant | [10.1103/PhysRevApplied.12.011003](https://doi.org/10.1103/PhysRevApplied.12.011003) |
| `arXiv-2103-08464-3r3x` | 2,300 | Partial | Pending written grant | [10.1088/2058-9565/ac4d1b](https://doi.org/10.1088/2058-9565/ac4d1b) |
| `qplib` | 23 | Partial | CC-BY-4.0 verified | [10.1007/s12532-018-0147-4](https://doi.org/10.1007/s12532-018-0147-4) |
| `qoblib` | 433 | Verified at pinned commit | CC-BY-4.0 verified | [10.1038/s43588-026-00991-1](https://doi.org/10.1038/s43588-026-00991-1) |

The three XORSAT mirror ZIPs contain instance files but no license, notice, or
redistribution grant. Their arXiv records use the
[arXiv non-exclusive distribution license](https://arxiv.org/licenses/nonexclusive-distrib/1.0/license.html),
which records permission for arXiv to distribute the articles. It is not
evidence that QUBOLib may redistribute the associated instance archives.
Publication therefore remains blocked until a data rights holder supplies a
grant that covers QUBOLib and the intended Zenodo deposit.

[QPLIB states that the library is CC-BY-4.0](https://qplib.zib.de/). The exact
QUBOLib mirror is pinned by SHA-256, but the upstream QPLIB snapshot used to
create it was not recorded. That source version must be documented before a
dataset deposit is finalized.

QOBLIB commit
[`80e45c176fc6281e5316451f02296482934785fa`](https://github.com/ZIB-AOPT/QOBLIB/tree/80e45c176fc6281e5316451f02296482934785fa)
contains a CC-BY-4.0 data license. The dataset record must retain the QOBLIB
attribution, source commit, and citation.

The repository's MIT license covers QUBOLib software. It does not replace the
collection-specific data terms above, so the corpus does not currently have a
blanket dataset license.

## Citation guidance

- Cite the
  [QUBO.jl ecosystem article](https://doi.org/10.1080/10556788.2026.2702926)
  for the general JuliaQUBO methods and software ecosystem.
- Cite QUBOLib software using [`CITATION.cff`](CITATION.cff), and identify the
  package version used when reproducibility depends on it.
- Identify the exact QUBOLib data release and cite each source collection used.
  After the dataset concept DOI exists, cite that DOI as well; use its version
  DOI when exact archived bytes matter.

## Zenodo publication gate

`DATASET.toml` deliberately records the dataset as `blocked`. Do not upload the
corpus or claim a QUBOLib dataset DOI until all of the following are true:

1. Every populated collection has verified provenance and redistribution
   rights.
2. The exact release asset, SHA-256, and Julia tree hash are recorded.
3. The dataset description includes the schema, collection inventory,
   provenance, licenses, citations, and reproduction instructions.
4. At least two active maintainers have `Can manage` access to the record.
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

The stronger command is expected to fail while the status is `blocked`.
