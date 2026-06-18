# API

## Actions

```@docs
QUBOLib.clear!
QUBOLib.build!
QUBOLib.run!
```

## Path Routing

```@docs
QUBOLib.library_path
QUBOLib.database_path
QUBOLib.archive_path
```

```@docs
QUBOLib.root_path
QUBOLib.dist_path
QUBOLib.build_path
QUBOLib.cache_path
QUBOLib.cache_data_path
```

## Library Index

```@docs
QUBOLib.LibraryIndex
```

```@docs
QUBOLib.database
QUBOLib.archive
```

## Data Access

```@docs
QUBOLib.access
```

```@docs
QUBOLib.load_collection
QUBOLib.load_instance
QUBOLib.source_model
QUBOLib.project_solution
QUBOLib.evaluate_source
QUBOLib.load_solution
QUBOLib.best_solution_record
QUBOLib.load_best_solution
QUBOLib.list_solution_records
```

## Data Management

```@docs
QUBOLib.add_collection!
QUBOLib.add_instance!
QUBOLib.add_solution!
QUBOLib.add_submission!
QUBOLib.add_solution_record!
QUBOLib.add_solver!
```

```@docs
QUBOLib.remove_collection!
QUBOLib.remove_instance!
QUBOLib.remove_solution!
QUBOLib.remove_solver!
```

## Instance Synthesis

```@docs
QUBOLib.Synthesis.AbstractProblem
QUBOLib.Synthesis.generate
```

### Problem Types

```@docs
QUBOLib.Synthesis.NAE3SAT
QUBOLib.Synthesis.XORSAT
QUBOLib.Synthesis.Wishart
QUBOLib.Synthesis.SherringtonKirkpatrick
```
