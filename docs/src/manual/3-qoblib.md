# QOBLIB Provenance

QUBOLib's canonical `qoblib` collection imports only authoritative QOBLIB
QUBO/QS artifacts. Source LP/MIP models, incumbent solutions, and solver
submissions are provenance inputs, but they are not converted into canonical
QUBO instances inside QUBOLib.

The current QUBOLib artifact source is QOBLIB commit
`80e45c176fc6281e5316451f02296482934785fa`. The constrained-class inventory
below was checked against that commit and against upstream QOBLIB `main` at
`a686aaa09fe14651294f744f34d453d5dce9cf57` on 2026-06-18. QOBLIB did not list
GitHub releases at that time. For every listed class, the repository tree scan
found zero blobs ending in `.qs` or `.qs.xz`. Files named `metrics_qs_files.csv`
are preserved as metric metadata, not as retrievable QS artifacts.

## Constrained Class Inventory

| Class                       | Upstream path | Official QS/QUBO artifact  | Available source and provenance                                                                                 | Canonical status                    |
|:--------------------------- |:------------- |:-------------------------- |:--------------------------------------------------------------------------------------------------------------- |:----------------------------------- |
| Birkhoff Polytope           | `03-birkhoff` | No `.qs` or `.qs.xz` files | LP source models, source instance data, metrics CSVs, solution artifacts, and submission provenance              | Unavailable for canonical ingestion |
| Steiner Tree                | `04-steiner`  | No `.qs` or `.qs.xz` files | LP source models, source instance data, metrics CSVs, and solution artifacts                                    | Unavailable for canonical ingestion |
| Sports Timetabling          | `05-sports`   | No `.qs` or `.qs.xz` files | LP source models, XML source instances, metrics CSVs, solution artifacts, and limited submission provenance     | Unavailable for canonical ingestion |
| Network Design              | `08-network`  | No `.qs` or `.qs.xz` files | LP source models, source data, metrics CSVs, solution artifacts, and submission provenance                      | Unavailable for canonical ingestion |
| Capacitated Vehicle Routing | `09-routing`  | No `.qs` or `.qs.xz` files | LP source models, VRP source instances, metrics CSVs, and solution artifacts                                    | Unavailable for canonical ingestion |
| Graph Topology Design       | `10-topology` | No `.qs` or `.qs.xz` files | LP source models across flow, Seidel linear, and Seidel quadratic formulations, bounds/metrics CSVs, and provenance | Unavailable for canonical ingestion |

Because none of these constrained classes currently provides authoritative
QOBLIB QS/QUBO files, the canonical `qoblib` collection does not import them.
If QOBLIB later publishes official QS/QUBO artifacts for any class, QUBOLib can
add that class to the canonical importer and validate it against upstream
metrics. LP/MIP-to-QUBO reformulation variants belong in a separate generated
collection with explicit naming and provenance.

## Source Formulation Storage

When a canonical QOBLIB QS/QUBO artifact has a matching authoritative source
model, QUBOLib stores source provenance under `/instances/{id}/source` in the
HDF5 archive. The source group records `source_format`, upstream repository,
commit, path, URL, hash algorithm, SHA-256 content hash, byte size, and the
source-text storage decision. If the source encoding is known and trustworthy,
the group also stores the encoding JSON used by `QUBOLib.project_solution` and
`QUBOLib.evaluate_source`.

Source LP text is stored only when the blob is at most 1,000,000 bytes. Larger
source files keep URL, path, size, and SHA-256 provenance in the artifact while
omitting the `content` dataset. This keeps the data artifact bounded without
losing enough provenance to retrieve and verify the upstream source manually.
