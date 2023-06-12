module QUBOInstances

using LazyArtifacts
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

export load_instance, list_collections, list_instances, select

# Public API
include("public/interface.jl")
include("public/library.jl")
include("public/load.jl")
include("public/list.jl")
include("public/database.jl")

# Data curation methods
include("curation/interface.jl")
include("curation/library.jl")
include("curation/list.jl")
include("curation/metadata.jl")
include("curation/index.jl")
include("curation/hash.jl")
include("curation/tag.jl")
include("curation/document.jl")
include("curation/build.jl")
include("curation/deploy.jl")

end # module QUBOInstances
