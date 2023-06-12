function _hash!(path::AbstractPath; verbose::Bool = false)
    verbose && @info "Computing Tree Hash"
    
    hash_path = abspath(joinpath(path, "..", "tree.hash"))

    write(hash_path, bytes2hex(Pkg.GitTools.tree_hash(path)))

    verbose && @info "Hash written to '$hash_path'"

    return nothing
end