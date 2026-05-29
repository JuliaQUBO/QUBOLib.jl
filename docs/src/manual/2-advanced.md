# Advanced Usage

## Adding a new collection

QUBOLib collection updates can happen at two levels:

- Local users can create or modify a private library under a chosen `path`.
- Maintainers can add a source builder so the collection becomes part of the
  packaged artifact distributed by QUBOLib.

In both cases, the same index APIs register collection metadata in SQLite and
store each QUBO model in the HDF5 archive.

### Local collection workflow

Use [`QUBOLib.access`](@ref) with a dedicated working directory. Passing
`clear = true` creates an empty local `qubolib` directory instead of copying the
packaged artifact:

!!! warning
    `clear = true` deletes any existing local QUBOLib data under that working
    directory before creating the empty index. Use it only when starting a new
    private library or intentionally replacing the existing local library.

The example below imports QUBOTools.jl directly to read a model file, so add it
to the active Julia project before running the import workflow:

```julia
import Pkg

Pkg.add("QUBOTools")
```

```julia
using QUBOLib
import QUBOTools

root = mkpath("donated-qubos")

QUBOLib.access(path = root, clear = true) do index
    metadata = Dict{String,Any}(
        "name" => "Donated Hard QUBOs",
        "author" => ["A. Researcher", "B. Contributor"],
        "description" => "Challenging benchmark instances donated to QUBOLib.",
        "year" => 2026,
        "url" => "https://example.org/donated-hard-qubos",
    )

    QUBOLib.add_collection!(index, "donated-hard", metadata)

    model = QUBOTools.read_model("/path/to/instance.qubo", QUBOTools.Qubist())

    instance = QUBOLib.add_instance!(
        index,
        model,
        "donated-hard";
        name = "instance.qubo",
    )
end
```

The collection code, here `"donated-hard"`, is the stable identifier stored in
the `Collections.collection` column. Each call to [`QUBOLib.add_instance!`](@ref)
returns the integer instance identifier inserted into the `Instances` table.

### Collection metadata

[`QUBOLib.add_collection!`](@ref) validates the metadata dictionary against the
packaged collection schema before inserting it into the database. The collection
code is passed separately, and the metadata fields are:

| Field | Required | Description |
| :---- | :------: | :---------- |
| `name` | yes | Human-readable collection name. |
| `author` | yes | Array of author or contributor names. |
| `description` | no | Short statement of what the collection contains. |
| `year` | no | Integer publication, creation, or release year. |
| `url` | no | Source, paper, project, or dataset URL. |

The `author` array is stored in the SQLite index as names joined by `" and "`.
Use the `url` and `description` fields to preserve provenance and make the
benchmark purpose clear to users.

### Packaged artifact workflow

Local edits are useful for experiments, but they do not update the artifact that
other users download through [`QUBOLib.access`](@ref). To include a collection in
the packaged library, add a builder under `scripts/build/sources/` and call it
from `scripts/build/build.jl`.

Existing builders follow this pattern:

1. Download or generate the source data into `QUBOLib.cache_data_path(index, code)`.
2. Register the metadata once with [`QUBOLib.add_collection!`](@ref).
3. Convert every source instance into a `QUBOTools.Model{Int,Float64,Int}`.
4. Store each model with [`QUBOLib.add_instance!`](@ref), passing the collection
   code and a stable `name`.
5. Add solutions with [`QUBOLib.add_solution!`](@ref) when trusted reference
   solutions are available.

Use this route for collections that should be built, mirrored, released, and
tracked through `Artifacts.toml`.

### Donating challenging QUBOs

QUBOLib is intended to grow through contributed benchmark collections. If you
have challenging QUBOs to donate, open a GitHub issue or pull request with:

- the source files, generator, or reproducible download location;
- the collection metadata listed above;
- license or redistribution terms;
- dimensions, density, coefficient ranges, and known solutions when available;
- a short explanation of why the instances are challenging for optimizers.

Large data files should usually be mirrored through the build workflow rather
than committed directly to the repository.

## Accessing Internal Data

Use [`QUBOLib.database`](@ref) and [`QUBOLib.archive`](@ref) to access the
SQLite database and HDF5 archive of a [`QUBOLib.LibraryIndex`](@ref).


```julia
using QUBOLib

QUBOLib.access() do index
    db = QUBOLib.database(index)
    h5 = QUBOLib.archive(index)
end
```
