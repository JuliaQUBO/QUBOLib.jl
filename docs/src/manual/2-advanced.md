# Advanced Usage

## Adding a new collection

## Acessing Internal Data

One is able to acess the database and archive of a [`QUBOLib.LibraryIndex`](@ref) by recalling the [`QUBOLib.database`](@ref) and [`QUBOLib.archive`](@ref) functions.


```julia
using QUBOLib

QUBOLib.access() do index
    db = QUBOLib.database(index)
    h5 = QUBOLib.archive(index)
end
```

