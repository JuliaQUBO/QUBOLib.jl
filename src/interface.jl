# Actions

@doc raw"""
    clear!(source::Symbol, cache::Bool = true)
"""
function clear! end

@doc raw"""
    build!(source::Symbol)
"""
function build! end

@doc raw"""
    run!(index::LibraryIndex, instance::Integer, optimizer)
    run!(index::LibraryIndex, instances::Vector{U}, optimizer) where {U<:Integer}
"""
function run! end

# Data Access

@doc raw"""
    access(
        callback;
        path::Union{AbstractString,Nothing} = nothing,
        create::Bool = false
    )::LibraryIndex

Loads the index for an instance library.

If `path` is not provided, the latest QUBOLib artifact will be used.

## Example

```julia
using QUBOLib

QUBOLib.access() do index
    print(index) # Show some information about the index
end
```
"""
function access end

@doc raw"""
    database(index::LibraryIndex)::SQLite.DB

Returns a pointer that grants direct access to the SQLite database of the library index.
"""
function database end

@doc raw"""
    archive(index::LibraryIndex)::HDF5.File

Returns a pointer that grants direct access to the HDF5 archive of the library index.
"""
function archive end

@doc raw"""
    load_collection(index::LibraryIndex, code::Symbol)
"""
function load_collection end

@doc raw"""
    load_instance(index::LibraryIndex, instance::Integer)
"""
function load_instance end

@doc raw"""
    load_solution(index::LibraryIndex, solution::Integer)
    load_solution(index::LibraryIndex, instance::Integer, solution::Integer)
"""
function load_solution end

# Data Management

@doc raw"""
    add_collection!(index::LibraryIndex, code::Symbol, data::Dict{String,Any})

Creates a new collection in the library index.
"""
function add_collection! end

@doc raw"""
    remove_collection!(index::LibraryIndex, collection)

Removes a collection and its contents from the library index.
"""
function remove_collection! end

@doc raw"""
    add_solver!(index::LibraryIndex, code::Symbol, data::Dict{String,Any})

Registers a new solver in the library index.
"""
function add_solver! end

@doc raw"""
    remove_solver!(index::LibraryIndex, code::Symbol)

Removes a solver from the library index.
"""
function remove_solver! end

@doc raw"""
    add_instance!(index::LibraryIndex, model::QUBOTools.Model{Int,Float64,Int}, collection = "standalone"; kwargs...)

Adds a new instance and optional provenance metadata to the library index.
"""
function add_instance! end

@doc raw"""
    remove_instance!(index::LibraryIndex, coll::Symbol, instance::Integer)

Removes an instance from the library index.
"""
function remove_instance! end

@doc raw"""
    add_solution!(index::LibraryIndex, instance::Integer, solution::SampleSet{Float64,Int})

Registers a new solution for a given instance.

The `solution` argument is a [`QUBOTools.SampleSet`](@extref), which is a collection of samples and their respective energies.
"""
function add_solution! end

@doc raw"""
    add_submission!(index::LibraryIndex; kwargs...)
    add_submission!(index::LibraryIndex, data::Dict{String,Any})

Registers benchmark-run provenance shared by one or more solution records.
"""
function add_submission! end

@doc raw"""
    add_solution_record!(index::LibraryIndex, instance::Integer; kwargs...)

Registers a submitted or reference bitstring and its provenance for an instance.
Records are preserved even when they are not incumbent candidates.
"""
function add_solution_record! end

@doc raw"""
    best_solution_record(index::LibraryIndex, instance::Integer)

Returns the selected incumbent solution record for an instance, or `nothing`.
"""
function best_solution_record end

@doc raw"""
    load_best_solution(index::LibraryIndex, instance::Integer)

Loads the HDF5 sample set associated with the selected incumbent, or `nothing`.
"""
function load_best_solution end

@doc raw"""
    list_solution_records(index::LibraryIndex, instance::Integer)

Returns all solution records for an instance, including non-incumbents.
"""
function list_solution_records end

@doc raw"""
    remove_solution!(index::LibraryIndex, instance::Integer, solution::Integer)

Removes a solution from the library index.
"""
function remove_solution! end
