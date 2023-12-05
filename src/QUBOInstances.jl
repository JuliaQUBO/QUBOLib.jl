module QUBOInstances

using LazyArtifacts
using HDF5
using JSON
using JSONSchema
using JuliaFormatter
using LaTeXStrings
using SQLite
using DataFrames
using Tar
using Pkg
using UUIDs
using QUBOTools
using ProgressMeter

export load_instance, list_collections, list_instances, select

# Public API
include("public/interface.jl")
include("public/library.jl")
include("public/load.jl")
include("public/list.jl")
include("public/database.jl")

# Data curation methods
include("curation/index.jl")
include("curation/curate.jl")
include("curation/deploy.jl")
# include("curation/metadata.jl")
# include("curation/hash.jl")
# include("curation/tag.jl")
# include("curation/document.jl")
# include("curation/build.jl")

end # module QUBOInstances
