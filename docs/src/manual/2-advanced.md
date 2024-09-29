# Advanced Usage

```julia
using QUBOLib

QUBOLib.access() do index
    db = QUBOLib.database(index)
    h5 = QUBOLib.archive(index)
end
```