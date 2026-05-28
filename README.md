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
julia> import Pkg; Pkg.add(url="https://github.com/JuliaQUBO/QUBOLib.jl")

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
Pass `path = "/path/to/workdir"` to keep the local copy somewhere else, or pass
`clear = true` to recreate it from the packaged artifact.

## Accessing the instance index database

> **Warning**
> This requires [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl) and [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) to be installed.

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
