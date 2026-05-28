# Basic Usage

## Opening the library index

Use [`QUBOLib.access`](@ref) to create or reuse a local copy of the packaged
library artifact and open the instance index:

```julia
using QUBOLib

QUBOLib.access() do index
    print(index)
end
```

By default, the local copy is stored in `joinpath(pwd(), "qubolib")`. Pass a
custom `path` when the data should be kept outside the current working
directory:

```julia
using QUBOLib

QUBOLib.access(path = "/path/to/workdir") do index
    print(index)
end
```

## Loading an instance

The [`QUBOLib.database`](@ref) function exposes the SQLite index, and
[`QUBOLib.load_instance`](@ref) loads a selected model from the HDF5 archive:

The example below queries the SQLite database directly, so add SQLite.jl and
DataFrames.jl to the active Julia project before running it:

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

To refresh the local copy from the packaged artifact, delete the local
`qubolib` directory and call [`QUBOLib.access`](@ref) again.
