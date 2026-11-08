"""Fresh uniform candidates; no release, artifact promotion, or resume side effects."""
module UniformCandidate

import LinearAlgebra
import QUBOPreprocessing
include("build.jl")

const REPO = dirname(dirname(@__DIR__))
const QP_TREE = "5050a4197600cd99d6809b9c9ee9efe4f76a8b70"
const COUNTS = Dict("arXiv-1903-10928-3r3x"=>3200,
    "arXiv-1903-10928-5r5x"=>307, "arXiv-2103-08464-3r3x"=>2300,
    "qplib"=>23, "qoblib"=>433, "minlplib"=>29, "mqlib"=>3002)
const MIRRORS = merge(copy(HEN_MIRROR_SHA256), Dict(
    "qplib"=>QPLIB_MIRROR_SHA256, "minlplib"=>MINLPLIB_MIRROR_SHA256,
    "mqlib"=>MQLIB_MIRROR_SHA256))
const JSON = QUBOLib.JSON

require(ok, message) = ok || throw(ArgumentError(message))
sha(path) = open(io->bytes2hex(SHA.sha256(io)), path, "r")
git(path, args...) = String(strip(read(`git -C $path $args`, String)))
function new_json(path, value)
    require(!ispath(path) && !islink(path), "output already exists: $path")
    open(path, "w") do io
        println(io, JSON.json(value, 2))
    end
end

function clean_source(path, expected)
    root = realpath(path)
    require(realpath(git(root,"rev-parse","--show-toplevel"))==root, "source must be a repository root")
    require(git(root,"rev-parse","HEAD")==expected, "source commit differs from the frozen plan")
    require(isempty(git(root,"status","--porcelain","--untracked-files=all")), "source tree is dirty")
    return Dict("commit"=>expected, "tree"=>git(root,"rev-parse","HEAD^{tree}"))
end

function runtime_identity(plan)
    require(plan["schema"]=="qubolib-uniform-candidate-v1", "unsupported candidate plan")
    builder = clean_source(REPO, plan["builder_commit"])
    require(realpath(dirname(dirname(pathof(QUBOLib))))==realpath(REPO), "wrong loaded QUBOLib checkout")
    require(string(VERSION)==plan["julia_version"], "Julia runtime differs from the plan")
    require(Threads.nthreads()==LinearAlgebra.BLAS.get_num_threads()==1, "one thread per library is required")
    require(Base.pkgversion(QUBOPreprocessing)==v"0.2.1", "registered QUBOPreprocessing0.2.1 is required")
    qp = only(p for p in values(Pkg.dependencies()) if p.name=="QUBOPreprocessing")
    require(qp.is_tracking_registry && string(qp.tree_hash)==QP_TREE, "wrong registered QUBOPreprocessing pin")
    require(realpath(pathof(QUBOPreprocessing))==realpath(joinpath(qp.source,"src","QUBOPreprocessing.jl")), "wrong loaded preprocessing source")
    require(bytes2hex(Pkg.GitTools.tree_hash(qp.source))==QP_TREE, "preprocessing source bytes differ")
    project = Base.active_project()
    require(!isnothing(project), "an explicit locked build environment is required")
    manifest = joinpath(dirname(project),"Manifest.toml")
    require(isfile(manifest), "build Manifest is missing")
    require(sha(project)==plan["project_sha256"] && sha(manifest)==plan["manifest_sha256"], "build environment differs from the plan")
    return Dict("builder"=>builder, "qubopreprocessing_version"=>"0.2.1",
        "qubopreprocessing_tree"=>QP_TREE, "project_sha256"=>sha(project),
        "manifest_sha256"=>sha(manifest), "julia_version"=>string(VERSION))
end

function validate_inputs(plan)
    require(Set(keys(plan["archives"]))==Set(keys(MIRRORS)), "exactly the six pinned source mirrors are required")
    archives = Dict{String,String}()
    for (name, expected) in MIRRORS
        path = String(plan["archives"][name])
        require(isfile(path) && !islink(path), "missing/linked source archive: $name")
        require(sha(path)==expected, "source archive checksum differs: $name")
        archives[name] = realpath(path)
    end
    qoblib = realpath(plan["qoblib_source"])
    qoblib_identity = clean_source(qoblib, QOBLIB_SOURCE_COMMIT)
    _validate_qoblib_source!(qoblib, QOBLIB_GROUPS)
    return archives, qoblib, qoblib_identity
end

function validate_inventory(index; expected=COUNTS)
    rows = QUBOLib.DBInterface.execute(QUBOLib.database(index),
        "SELECT collection, count(*) AS n FROM Instances GROUP BY collection;") |> QUBOLib.DataFrame
    actual = Dict(String(r.collection)=>Int(r.n) for r in eachrow(rows))
    require(actual==expected, "incomplete or unexpected collection inventory: $actual")
    duplicate = QUBOLib.DBInterface.execute(QUBOLib.database(index),
        "SELECT collection,name,count(*) AS n FROM Instances GROUP BY collection,name HAVING count(*) != 1;") |> QUBOLib.DataFrame
    require(isempty(duplicate), "duplicate collection/name identities")
    return actual
end

function raw_inventory(index)
    rows = QUBOLib.DBInterface.execute(QUBOLib.database(index),
        "SELECT instance,collection,name FROM Instances ORDER BY collection,name;") |> QUBOLib.DataFrame
    result = Dict{String,Any}[]
    for row in eachrow(rows)
        model = QUBOLib.load_instance(index,Int(row.instance))
        push!(result, merge(Dict("instance"=>Int(row.instance), "collection"=>String(row.collection),
            "name"=>String(row.name)), _qubopreprocessing_model_identity(model)))
    end
    return result
end

function require_unenriched(index)
    rows = QUBOLib.DBInterface.execute(QUBOLib.database(index), "SELECT metadata FROM Instances;") |> QUBOLib.DataFrame
    for row in eachrow(rows)
        value = row.metadata
        (ismissing(value) || isnothing(value) || isempty(strip(String(value)))) && continue
        meta = JSON.parse(String(value))
        require(!any(haskey(meta,key) for key in ("preprocessing","preprocessing_runs","n_strong","n_weak")),
            "uniform enrichment requires fresh original models; unsafe reuse/resume is refused")
    end
end

function enrich_streaming!(path; journal)
    ids, submissions = QUBOLib.access(;path) do index
        require_unenriched(index)
        rows = QUBOLib.DBInterface.execute(QUBOLib.database(index), "SELECT instance FROM Instances ORDER BY instance;") |> QUBOLib.DataFrame
        provenance = _qubopreprocessing_build_provenance(QUBOPreprocessing)
        provenance["run_started_unix_s"] = time()
        _ensure_qubopreprocessing_solver!(index)
        Int.(rows.instance), _qubopreprocessing_submissions!(index,provenance)
    end
    # Close both stores after each instance; this is not a crash-atomic commit
    # across SQLite and HDF5. Only the final audited terminal receipt is accepted.
    # No whole-corpus model/trace cache survives the call. Failed destinations
    # are retained for diagnosis and never advertised as resumable candidates.
    for id in ids
        stats = QUBOLib.access(;path) do index
            enrich_preprocessing!(index,QUBOPreprocessing;
                instance_ids=Set([id]), repair_instance_ids=Set([id]), submission_ids=submissions)
        end
        println(journal,JSON.json(Dict("instance"=>id,"status"=>"enriched", "exact_count"=>stats.exact_count,
            "repaired_strong_count"=>stats.repaired_strong_count,"repaired_weak_count"=>stats.repaired_weak_count)))
        flush(journal)
        GC.gc(false)
    end
    return length(ids)
end

function audit_enrichment(index, identity; originals=nothing)
    rows = QUBOLib.DBInterface.execute(QUBOLib.database(index), "SELECT instance,metadata FROM Instances ORDER BY instance;") |> QUBOLib.DataFrame
    for row in eachrow(rows)
        meta = JSON.parse(String(row.metadata))
        require(!haskey(meta,"preprocessing_runs"), "historical preprocessing was appended instead of a uniform fresh build")
        prep = meta["preprocessing"]; provenance = prep["provenance"]
        if !isnothing(originals)
            require(prep["input"]==originals[Int(row.instance)], "enrichment input identity differs from the original model")
        end
        require(provenance["result_source"]==provenance["coercive_source"]=="pipeline", "TSV or mixed enrichment source")
        require(provenance["qubolib_build_commit"]==identity["builder"]["commit"] &&
            provenance["qubolib_build_tree_dirty"]===false, "unverified enrichment builder")
        require(provenance["qubopreprocessing_tree_hash"]==QP_TREE &&
            provenance["project_sha256"]==identity["project_sha256"] &&
            provenance["manifest_sha256"]==identity["manifest_sha256"], "mixed enrichment environment")
        for mode in ("strong","weak")
            require(haskey(prep,"$(mode)_run"), "missing mode report")
        end
    end
    return length(rows.instance)
end

function mirror_root(path, required)
    candidates = String[]
    for (root, _, _) in walkdir(path)
        all(name->isfile(joinpath(root,name)),required) && push!(candidates,root)
    end
    require(length(candidates)==1, "source mirror has missing/ambiguous required files")
    return only(candidates)
end

function validate_mqlib_inventory(root)
    require(all(name->isfile(joinpath(root,name)),
        ("standard.csv","catalog_tier2.csv","metrics_standard.csv","results_standard.csv")), "MQLib catalogues/results are incomplete")
    rows = vcat(_parse_mqlib_csv(joinpath(root,"standard.csv")),
        _parse_mqlib_csv(joinpath(root,"catalog_tier2.csv")))
    for row in rows
        graphname = row["graphname"]
        require(basename(graphname)==graphname && !isempty(graphname), "invalid MQLib model path")
        base = replace(graphname,r"\.zip$"=>"")
        require(isfile(joinpath(root,graphname)) || isfile(joinpath(root,"$base.txt")),
            "MQLib model is missing: $graphname")
    end
    return length(rows)
end

function import_sources!(path, archives, qoblib)
    QUBOLib.access(;path,clear=true) do index
        for code in keys(HEN_DATA)
            target = QUBOLib.cache_path(index,code,"$code.zip")
            mkpath(dirname(target)); cp(archives[code],target)
        end
        target = QUBOLib.cache_path(index,"qplib","qplib.zip")
        mkpath(dirname(target)); cp(archives["qplib"],target)
        roots = Dict{String,String}()
        for name in ("minlplib","mqlib")
            destination = joinpath(path,"sources",name)
            mkpath(destination)
            run(`unzip -qq $(archives[name]) -d $destination`)
            required = name=="mqlib" ? ["standard.csv","catalog_tier2.csv","metrics_standard.csv","results_standard.csv"] :
                vcat([["$(info.name).pip"; ["$(info.name).$(point).sol" for point in info.points]] for info in MINLPLIB_QUBO_INSTANCES]...)
            roots[name] = mirror_root(destination,required)
        end
        # Reject missing MQLib models before the importer can silently skip them.
        validate_mqlib_inventory(roots["mqlib"])
        build_hen!(index)
        build_qplib!(index)
        build_qoblib!(index;source_path=qoblib)
        build_minlplib!(index;root=roots["minlplib"])
        build_mqlib!(index;root=roots["mqlib"])
        validate_inventory(index)
    end
end

function build_candidate(plan_path, destination)
    require(!ispath(destination) && !islink(destination), "candidate destination already exists; resume is unsupported")
    plan = TOML.parsefile(plan_path)
    identity = runtime_identity(plan)
    archives,qoblib,qoblib_identity = validate_inputs(plan)
    require(!ispath(destination) && !islink(destination), "candidate destination appeared during preflight")
    mkdir(destination) # atomic claim; never clear/overwrite a prior attempt
    new_json(joinpath(destination,"run-plan.json"),Dict("plan"=>plan,"identity"=>identity,
        "plan_sha256"=>sha(plan_path),"qoblib"=>qoblib_identity,"state"=>"prepared"))
    try
        withenv("QUBOLIB_QOBLIB_SOURCE"=>qoblib) do
            import_sources!(destination,archives,qoblib)
            before = QUBOLib.access(index->raw_inventory(index);path=destination)
            new_json(joinpath(destination,"original-models.json"),before)
            open(joinpath(destination,"enrichment.jsonl"),"w") do journal
                enrich_streaming!(destination;journal)
            end
            QUBOLib.access(;path=destination) do index
                validate_inventory(index)
                require(raw_inventory(index)==before, "original models changed during enrichment")
                require(audit_enrichment(index,identity; originals=Dict(item["instance"]=>item for item in before))==sum(values(COUNTS)), "incomplete enrichment")
            end
        end
        require(runtime_identity(plan)==identity, "source/runtime identity changed during the build")
        validate_inputs(plan)
        library = QUBOLib.library_path(destination)
        require(Set(readdir(library))==Set(["archive.h5","index.db"]), "unexpected artifact members")
        tree = bytes2hex(Pkg.GitTools.tree_hash(library))
        tar_path = joinpath(destination,"qubolib.tar")
        Tar.create(library,tar_path)
        archive_path = joinpath(destination,"qubolib.tar.gz")
        open(archive_path,"w") do io
            run(pipeline(`gzip -n -c $tar_path`;stdout=io))
        end
        receipt = Dict("state"=>"complete", "schema"=>"qubolib-uniform-candidate-v1",
            "build_commit"=>identity["builder"]["commit"], "build_commit_status"=>"verified",
            "identity"=>identity, "counts"=>COUNTS, "artifact_tree"=>tree,
            "archive_sha256"=>sha(archive_path), "archive_bytes"=>filesize(archive_path),
            "members"=>Dict(name=>Dict("sha256"=>sha(joinpath(library,name)),"bytes"=>filesize(joinpath(library,name))) for name in readdir(library)),
            "publication"=>"not_published_requires_human_review")
        new_json(joinpath(destination,"terminal.json"),receipt)
        return receipt
    catch err
        new_json(joinpath(destination,"failure.json"),Dict("state"=>"failed", "error"=>sprint(showerror,err),
            "build_commit_status"=>"unverified", "resume_supported"=>false))
        rethrow()
    end
end

function main(args=ARGS)
    length(args)==2 || error("Usage: uniform_candidate.jl FROZEN_PLAN.toml NEW_DESTINATION")
    build_candidate(args[1],abspath(args[2]))
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    UniformCandidate.main()
end
