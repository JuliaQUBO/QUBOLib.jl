# Dataset versions and working copies

The package and dataset have separate versions. Check `Artifacts.toml` in the
installed package and cite the exact dataset version used in an experiment.
The [dataset inventory](https://github.com/JuliaQUBO/QUBOLib.jl/blob/main/DATASET.md)
records archive SHA256, artifact tree, source inputs, rights and scientific scope.

## Existing local data

`QUBOLib.access(path=working)` uses an existing `working/qubolib` library when
its database and HDF5 files are already present. Updating the Julia package does
not replace that working copy or migrate it to a different dataset release.
Choose a fresh directory to install the package's selected dataset:

```julia
import QUBOLib
working = mktempdir(; cleanup=false)
QUBOLib.access(; path=working) do index
    # Query or extend this separate working library.
end
println(working)
```

Keep experimental inputs pinned. `clear=true` creates an empty library and
deletes local data; it is not an upgrade procedure for an existing experiment.

## Historical layered dataset

The immutable
[`v0.2.6-data+9` release](https://github.com/JuliaQUBO/QUBOLib.jl/releases/tag/v0.2.6-data%2B9)
and [version DOI 10.5281/zenodo.23972765](https://doi.org/10.5281/zenodo.23972765)
preserve the layered study snapshot: 19,052 appended preprocessing histories,
1,435 capture proof records covering 622 stored QUBOs, and six separately feasible
points. Its historical parent retains its documented mixed build provenance.
Use that exact version when an experiment depends on those records.

This recipe verifies the historical artifact's download SHA256 and extracted
tree through Julia's artifact installer, then opens a writable copy in a fresh
directory. It does not change the package's selected artifact or any existing
working library. The immutable artifact is never opened with the mutable
QUBOLib index API.

```julia
import Pkg
import QUBOLib

historical_tree = "5e791d1cff8d443e0ca8bfc5c7d9cf286e638df1"
historical = mktempdir() do metadata_dir
    artifacts = joinpath(metadata_dir, "Artifacts.toml")
    write(artifacts, """
    [historical_qubolib]
    git-tree-sha1 = "$historical_tree"
    lazy = true
        [[historical_qubolib.download]]
        url = "https://github.com/JuliaQUBO/QUBOLib.jl/releases/download/v0.2.6-data+9/qubolib.tar.gz"
        sha256 = "5559c7fd070a61e6d17f9ef53393b9694f7c51b353ae0b191c30b78f90dec5bf"
    """)
    Pkg.Artifacts.ensure_artifact_installed("historical_qubolib", artifacts)
    hash = Pkg.Artifacts.artifact_hash("historical_qubolib", artifacts)
    Pkg.Artifacts.artifact_path(hash)
end
@assert bytes2hex(Pkg.GitTools.tree_hash(historical)) == historical_tree

working = mktempdir(; cleanup=false)
destination = mkdir(joinpath(working, "qubolib"))
for name in ("archive.h5", "index.db")
    target = joinpath(destination, name)
    cp(joinpath(historical, name), target)
    chmod(target, 0o644)
end
QUBOLib.access(; path=working) do index
    println("Historical working copy is open")
end
@assert bytes2hex(Pkg.GitTools.tree_hash(historical)) == historical_tree
println("Historical working directory: ", working)
```

The five companion provenance files remain available with the historical release
and version DOI. Their original hashes and lineage are retained in
[`data/releases/v0.2.6-data+9.toml`](https://github.com/JuliaQUBO/QUBOLib.jl/blob/main/data/releases/v0.2.6-data%2B9.toml).
Opening the writable copy may perform the package's ordinary schema migration;
the retained artifact, published archive and companions remain unchanged.
