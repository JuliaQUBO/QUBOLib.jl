# QUBOInstances.jl
QUBO Instances for benchmarking

## Introduction

## Getting Started

### Installation

```julia
julia> import Pkg; Pkg.add(url="https://github.com/pedromxavier/QUBOInstances.jl")

julia> using QUBOInstances
```

### Example

```julia
julia> c = first(list_collections())

julia> i = first(list_instances(col))

julia> m = load_instance(c, i)
```