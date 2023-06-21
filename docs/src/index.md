# QUBOInstances.jl

## Getting Started

### Installation

```julia
import Pkg

Pkg.add(url="https://github.com/pedromxavier/QUBOInstances.jl")

using QUBOInstances
```

### Basic Example

```@example load
using QUBOInstances

# Get code of the first registered collection
coll = first(list_collections())

# Get code of the first instance from that collection
inst = first(list_instances(coll))

# Eetrieve QUBOTools model
load_instance(coll, inst)
```

### Accessing the instance index database

```@setup sql
using QUBOInstances
```

```@example sql
using SQLite, DataFrames

db = QUBOInstances.database()

df = DBInterface.execute(
    db,
    "SELECT collection, instance FROM instances WHERE size BETWEEN 100 AND 200;"
) |> DataFrame

models = [
    load_instance(coll, inst)
    for (coll, inst) in zip(df[!,:collection], df[!,:instance])
]

first(models)
```
