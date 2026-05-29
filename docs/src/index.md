# QUBOLib.jl

QUBOLib provides a Julia interface to a curated collection of binary quadratic
optimization benchmark instances.

## Installation

Install the package directly from GitHub:

```julia
import Pkg

Pkg.add(url="https://github.com/JuliaQUBO/QUBOLib.jl")

using QUBOLib
```

## Retrieving instances

QUBOLib instances are distributed as a Julia artifact recorded in
[`Artifacts.toml`](https://github.com/JuliaQUBO/QUBOLib.jl/blob/main/Artifacts.toml),
not as checked-in data files. The artifact is downloaded from the package
releases the first time [`QUBOLib.access`](@ref) needs it, then copied into a
local `qubolib` directory for use.

Use [`QUBOLib.access`](@ref) to open the local index, query the SQLite database
for instance identifiers, and load the selected models from the HDF5 archive:

The database-query examples below use SQLite.jl and DataFrames.jl directly, so
add them to the active Julia project before running those examples:

```julia
import Pkg

Pkg.add(["SQLite", "DataFrames"])
```

```julia
using QUBOLib
using SQLite, DataFrames

model = QUBOLib.access() do index
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
directory and call [`QUBOLib.access`](@ref) again.

## Accessing the instance index database

The local index exposes both the SQLite database and the HDF5 archive:

```julia
using QUBOLib
using SQLite, DataFrames

models = QUBOLib.access() do index
    df = DBInterface.execute(
        QUBOLib.database(index),
        "SELECT instance FROM Instances WHERE dimension BETWEEN 100 AND 200;"
    ) |> DataFrame

    return [QUBOLib.load_instance(index, i) for i in df[!, :instance]]
end
```

See [Basic Usage](manual/1-basic.md) for the common access workflow and
[API](@ref) for the exported functions.

## Contributing benchmark collections

QUBOLib is also an invitation to donate challenging QUBOs. If you have benchmark
instances, reproducible generators, or source archives that should be part of
the library, see [Advanced Usage](manual/2-advanced.md) for the collection
metadata, local import workflow, and packaged artifact workflow.
