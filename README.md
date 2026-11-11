# QUBOLib.jl

<div align="center">
    <a href="/docs/src/assets/">
        <img src="/docs/src/assets/logo.svg" width=400px alt="QUBOLib.jl" />
    </a>
    <br>
</div>

## Getting Started

### Installation

```julia
julia> import Pkg; Pkg.add("QUBOLib")

julia> using QUBOLib
```

### Example

```julia
julia> using QUBOLib

julia> QUBOLib.access() do index
           println(index)
       end
```

## Retrieving instances

QUBOLib instances are distributed as a Julia artifact recorded in
[`Artifacts.toml`](Artifacts.toml), not as checked-in data files. The artifact is
downloaded from the package releases the first time `QUBOLib.access` needs it,
then copied into a local `qubolib` directory for use.

The database-query examples below use SQLite.jl and DataFrames.jl directly, so
add them to the active Julia project before running those examples:

```julia
julia> import Pkg; Pkg.add(["SQLite", "DataFrames"])
```

Use `QUBOLib.access` to open the local index, query the SQLite database for
instance identifiers, and load the selected models from the HDF5 archive:

```julia
julia> using QUBOLib

julia> using SQLite, DataFrames

julia> model = QUBOLib.access() do index
           df = DBInterface.execute(
               QUBOLib.database(index),
               "SELECT instance FROM Instances ORDER BY instance LIMIT 1;"
           ) |> DataFrame

           return QUBOLib.load_instance(index, only(df[!, :instance]))
       end
```

By default, `QUBOLib.access()` creates or reuses `joinpath(pwd(), "qubolib")`.
Pass `path = "/path/to/workdir"` to keep the local copy somewhere else. To
refresh the local copy from the packaged artifact, delete the local `qubolib`
directory and call `QUBOLib.access()` again without `clear = true`.

Choose a working directory outside the packaged artifact returned by
`QUBOLib.library_path()`. `access` and `install` reject local directories that
overlap that artifact, including paths through symlinks; `clear = true` does not
permit clearing the artifact.

If an older installation created a nested `qubolib/qubolib/…` tree inside the
artifact, stop using that copy. After checking the path and preserving any user
data, remove the corrupted artifact with Julia's artifact-management tools
(`Pkg.Artifacts.remove_artifact`) and let QUBOLib download it again. Removing only
an accidental nested `qubolib` directory is appropriate only after confirming
that it contains no wanted data. Run `QUBOLib.access` from a separate working
directory when reinstalling.

## Accessing the instance index database

> **Warning**
> This requires [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl) and [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) to be installed in the active Julia project.

```julia
julia> using QUBOLib

julia> using SQLite, DataFrames

julia> models = QUBOLib.access() do index
           df = DBInterface.execute(
               QUBOLib.database(index),
               "SELECT instance FROM Instances WHERE dimension BETWEEN 100 AND 200;"
           ) |> DataFrame

           return [QUBOLib.load_instance(index, i) for i in df[!, :instance]]
       end
```

## Listing Collections

```julia
julia> QUBOLib.access() do index
           DBInterface.execute(
               QUBOLib.database(index),
               "SELECT * FROM Collections;"
           ) |> DataFrame
       end
```

## Citation and dataset provenance

For general use, cite the
[QUBO.jl ecosystem article](https://doi.org/10.1080/10556788.2026.2702926).
Use [`CITATION.cff`](CITATION.cff) for QUBOLib software citation metadata and
identify the package version used.

For the benchmark data, cite the
[dataset concept DOI](https://doi.org/10.5281/zenodo.23027943) across versions.
QUBOLib 0.2.8 selects the uniform
[`v0.2.7-data+10` release](https://github.com/JuliaQUBO/QUBOLib.jl/releases/tag/v0.2.7-data%2B10),
version identifier [10.5281/zenodo.24142757](https://doi.org/10.5281/zenodo.24142757).
It contains 9,294 original QUBOs with 620 exact captures and 62 repair records
from the recorded QUBOPreprocessing.jl 0.2.1 pipeline. The historical layered
[data+9 version](https://doi.org/10.5281/zenodo.23972765) preserves additional study
histories, proofs, feasible points and annotations. See [`DATASET.md`](DATASET.md)
for the measured compatibility differences and
[Dataset Versions](https://juliaqubo.github.io/QUBOLib.jl/stable/manual/4-datasets/)
for separate working-copy access. Package upgrades preserve existing local data.
Also cite each source collection used. Older package tags retain their data pins.

The data artifact combines independently sourced collections; the repository's
MIT software license is not a blanket dataset license. Before redistributing or
publishing the corpus, consult [`DATASET.md`](DATASET.md) and its
machine-readable [`DATASET.toml`](DATASET.toml) inventory for the exact artifact
hashes, source citations, provenance status, and collection-specific terms.

## Project maintenance

- See [`CHANGELOG.md`](CHANGELOG.md) for package release notes.
- See [`RELEASE.md`](RELEASE.md) for the package and data-artifact release checklist.
- See [`DATASET.md`](DATASET.md) for dataset provenance and publication status.
