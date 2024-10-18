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

## Accessing the instance index database

> **Warning**
> This requires [SQLite.jl](https://github.com/JuliaDatabases/SQLite.jl) and [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) to be installed.

```julia
julia> using QUBOLib

julia> using SQLite, DataFrames

julia> models = QUBOLib.access() do index
           df = DBInterface.execute(
               QUBOLib.database(index),
               "SELECT instance FROM Instances WHERE size BETWEEN 100 AND 200;"
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