# function build(
#     collections::AbstractVector,
#     root_path::AbstractString,
#     dist_path::AbstractString=abspath(root_path, "dist");
#     cache::Bool=true,
# )
#     index = create_index(root_path, dist_path)

#     for coll in collections
#         build!(index, coll; cache)
#     end

#     # Compute Tree hash
#     tree_hash = bytes2hex(Pkg.GitTools.tree_hash(dist_path))

#     return index
# end

# function build!(index::LibraryIndex, coll::Collection; cache::Bool=true)
#     if !(cache && has_collection(index, coll))
#         load!(index, coll; cache)
#         index!(index, coll)
#         document!(index, coll)
#     end

#     return nothing
# end
