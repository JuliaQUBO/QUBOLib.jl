#!/usr/bin/env julia
"""Copy-only import of source-bound feasible points, without preprocessing rows.

The CLI is restricted to Dantzig. It never treats a solver status or an audit
receipt as an optimality proof; every imported state is evaluated afresh against
its exact native catalogue model by the explicitly pinned source reader.
"""
module ValidatedPointImport

include(joinpath(@__DIR__, "import_followup_results.jl"))
const FI = FollowupImport
using SHA, JSON, SQLite, HDF5
import QUBOLib, QUBOTools

const SCHEMA = "qubolib-validated-points-v1"
const SOLVER = "QUBOLib/validated-point-import"
const DBI = QUBOLib.DBInterface
require(ok, message) = FI.require(ok, message)

function load_bundle(path, expected_hash, database_hash, archive_hash)
    require(FI.hexhash(expected_hash) && FI.sha(path) == expected_hash, "Point bundle SHA256 mismatch")
    bundle_file = realpath(path)
    root = dirname(bundle_file)
    data = JSON.parsefile(bundle_file)
    require(get(data, "schema", nothing) == SCHEMA, "Unsupported point bundle schema")
    require(get(data, "import_id", nothing) isa String && !isempty(data["import_id"]), "Explicit point import ID required")
    parent = get(data, "parent_snapshot", nothing)
    require(parent isa AbstractDict && get(parent, "database_sha256", nothing) == database_hash &&
            get(parent, "archive_sha256", nothing) == archive_hash, "Point bundle parent snapshot differs")
    ancestor = get(data, "ancestor_snapshot", nothing)
    require(ancestor isa AbstractDict && occursin(r"^[0-9a-f]{40}$", string(get(ancestor, "artifact_tree", ""))) &&
            FI.hexhash(get(ancestor, "database_sha256", nothing)) && FI.hexhash(get(ancestor, "archive_sha256", nothing)),
            "Ancestor snapshot pins required")
    require(get(data, "provenance", nothing) isa AbstractDict, "Point bundle provenance required")
    points = get(data, "points", nothing)
    require(points isa AbstractVector && !isempty(points), "Nonempty point inventory required")
    ids = Set{Int}()
    for point in points
        require(point isa AbstractDict, "Malformed point")
        iid = FI.nonnegative_int(get(point, "instance_id", nothing), "instance ID")
        require(iid > 0 && !(iid in ids), "Duplicate or invalid point instance ID")
        push!(ids, iid)
        require(get(point, "global_optimal", nothing) === false &&
                get(point, "native_source_feasibility", nothing) == "unknown", "Points cannot declare global or native-source certification")
        require(FI.hexhash(get(point, "native_source_sha256", nothing)) &&
                FI.hexhash(get(point, "state_sha256", nothing)) && FI.hexhash(get(point, "state_file_sha256", nothing)), "Point hashes required")
        FI.exact_parse(get(point, "original_objective_exact", nothing))
        state_path = FI.confined_file(root, get(point, "state_path", nothing))
        require(FI.sha(state_path) == point["state_file_sha256"], "Point state file SHA256 mismatch")
        require(get(point, "provenance", nothing) isa AbstractDict, "Point provenance required")
    end
    return (root=root, path=bundle_file, sha256=expected_hash, data=data, ids=ids)
end

function validate_point(index, point, bundle, verifier)
    iid = Int(point["instance_id"])
    rows = FI.query(index.db, "SELECT instance, collection, name, dimension, sense, domain FROM Instances WHERE instance=?", (iid,))
    require(size(rows, 1) == 1, "Unknown catalogue instance")
    row = rows[1, :]
    domain = lowercase(row.domain)
    require(domain in ("bool", "spin") && point["collection"] == row.collection &&
            point["name"] == (ismissing(row.name) ? nothing : row.name) &&
            point["sense"] == lowercase(row.sense) && point["domain"] == domain &&
            point["state_encoding"] == FI.state_encoding(Symbol(domain)), "Point catalogue identity differs")
    raw = FI.load_source(verifier, index, iid)
    require(raw.n == row.dimension && String(raw.domain) == domain && String(raw.sense) == lowercase(row.sense), "Stored model and catalogue identity differ")
    model_hash = FI.source_hash(verifier, raw)
    require(model_hash == point["native_source_sha256"], "Point native model SHA256 differs")
    state_path = FI.confined_file(bundle.root, point["state_path"])
    require(FI.sha(state_path) == point["state_file_sha256"], "Point state file changed")
    require(filesize(state_path) == raw.n + 1, "Point state file has wrong dimension")
    state_text = read(state_path, String)
    require(ncodeunits(state_text) == raw.n + 1 && endswith(state_text, "\n"), "Point state file must be bits followed by one LF")
    bitstring = chop(state_text; tail=1)
    require(ncodeunits(bitstring) == raw.n && all(c -> c == '0' || c == '1', bitstring), "Point state is not a native encoded binary vector")
    state_hash = bytes2hex(sha256(bitstring))
    require(state_hash == point["state_sha256"], "Point encoded state SHA256 differs")
    bits = Int[c == '1' for c in bitstring]
    value = FI.exact_objective(raw, bits)
    require(value == FI.exact_parse(point["original_objective_exact"]), "Point exact native objective differs")
    require(isfinite(Float64(value)), "Point objective exceeds finite catalogue storage")
    source = Dict("parent_snapshot" => bundle.data["parent_snapshot"],
                  "ancestor_snapshot" => bundle.data["ancestor_snapshot"],
                  "instance_id" => iid, "collection" => row.collection, "name" => point["name"],
                  "domain" => domain, "sense" => lowercase(row.sense), "model_sha256" => model_hash)
    verified = Dict("kind" => "fresh_exact_native_point_evaluation", "catalogue_model_checked" => true,
                    "source_sha256" => model_hash, "state_sha256" => state_hash,
                    "original_objective_exact" => FI.exact_string(value), "global_optimal" => false,
                    "native_source_feasibility" => "unknown", "verifier" => FI.verifier_identity(verifier))
    key = bytes2hex(sha256(FI.canonical_json(Dict("import_id" => bundle.data["import_id"],
        "bundle_sha256" => bundle.sha256, "instance_id" => iid, "source_sha256" => model_hash, "state_sha256" => state_hash))))
    return (iid=iid, raw=raw, bits=bits, bitstring=bitstring, value=value, source=source, verified=verified,
            state_path=state_path, key=key, point=point)
end

function add_point!(index, item, submission, bundle)
    metadata = Dict{String,Any}("solver" => SOLVER, "status" => "feasible", "point_import_schema" => SCHEMA,
        "point_import_key_sha256" => item.key, "original_objective_exact" => FI.exact_string(item.value),
        "objective_sense" => String(item.raw.sense), "encoded_bitstring" => item.bitstring,
        "stored_domain" => String(item.raw.domain), "state_encoding" => FI.state_encoding(item.raw.domain),
        "stored_qubo_domain_feasible" => true, "encoded_boolean_feasible" => true,
        "native_source_feasibility" => "unknown", "global_optimal" => false, "source" => item.source,
        "independent_verification" => item.verified, "bundle_sha256" => bundle.sha256,
        "provenance" => Dict("bundle" => bundle.data["provenance"], "point" => item.point["provenance"]))
    sample = QUBOTools.Sample{Float64,Int}(FI.native_state(item.raw, item.bits), Float64(item.value), 1)
    sol = QUBOTools.SampleSet{Float64,Int}([sample], metadata; sense=item.raw.sense, domain=item.raw.domain)
    sid = QUBOLib.add_solution!(index, item.iid, sol; submission, qubo_value=Float64(item.value),
        source_value=missing, source_objective=nothing, source_feasible=nothing, proven_optimal=false,
        feasibility_status="feasible", validation_status="verified", source_path=item.state_path)
    records = FI.query(index.db, "SELECT record FROM SolutionRecords WHERE instance=? AND solution=?", (item.iid, sid))
    return (solution=Int(sid), record=Int(only(records.record)))
end

"""Write only a fresh private copy. `apply_hook` is a fixture fault injector."""
function stage_points(; source_database, source_archive, expected_database_sha256, expected_archive_sha256,
        bundle_path, expected_bundle_sha256, output, verifier::FI.AbstractWitnessVerifier,
        apply_hook::Function=(i,item)->nothing)
    require(!ispath(output) && isdir(dirname(abspath(output))), "Point stage output must be a NEW directory")
    dbsrc = realpath(source_database); h5src = realpath(source_archive)
    require(dbsrc != h5src && isfile(dbsrc) && isfile(h5src), "Invalid parent snapshot")
    destination = joinpath(realpath(dirname(abspath(output))), basename(normpath(output)))
    evidence_root = dirname(realpath(bundle_path))
    for parent in (dirname(dbsrc), dirname(h5src), evidence_root)
        require(destination != parent && !startswith(destination, parent * string(Base.Filesystem.path_separator)), "Point stage output overlaps immutable inputs")
    end
    require(FI.hexhash(expected_database_sha256) && FI.hexhash(expected_archive_sha256), "Parent file hashes required")
    require(!isfile(dbsrc * "-wal") || filesize(dbsrc * "-wal") == 0, "Parent SQLite WAL must be checkpointed")
    require(FI.sha(dbsrc) == expected_database_sha256 && FI.sha(h5src) == expected_archive_sha256, "Parent snapshot SHA256 differs")
    bundle = load_bundle(bundle_path, expected_bundle_sha256, expected_database_sha256, expected_archive_sha256)
    mkdir(output)
    dbpath = joinpath(output, "index.db"); h5path = joinpath(output, "archive.h5")
    cp(dbsrc, dbpath; force=false); cp(h5src, h5path; force=false)
    require(FI.sha(dbpath) == expected_database_sha256 && FI.sha(h5path) == expected_archive_sha256, "Parent changed during copy")
    chmod(dbpath, 0o600); chmod(h5path, 0o600)
    db = SQLite.DB(dbpath); h5 = h5open(h5path, "r+")
    index = QUBOLib.LibraryIndex(db, h5, abspath(output))
    original_groups = Set(String.(keys(h5["solutions"])))
    started = false; committed = false; changes = Any[]
    try
        DBI.execute(db, "BEGIN IMMEDIATE TRANSACTION"); started = true
        QUBOLib.has_solver(index, SOLVER) || QUBOLib.add_solver!(index, SOLVER, Dict("description" => "Freshly checked exact native feasible points"))
        submission = QUBOLib.add_submission!(index; source_path=bundle.path,
            metadata=Dict("schema" => SCHEMA, "import_id" => bundle.data["import_id"], "bundle_sha256" => bundle.sha256,
                          "source_snapshot" => bundle.data["parent_snapshot"], "provenance" => bundle.data["provenance"]))
        for (i, point) in enumerate(bundle.data["points"])
            item = validate_point(index, point, bundle, verifier)
            saved = add_point!(index, item, submission, bundle)
            push!(changes, Dict("instance_id" => item.iid, "solution_id" => saved.solution, "record_id" => saved.record,
                                "source_sha256" => item.verified["source_sha256"], "state_sha256" => item.verified["state_sha256"],
                                "original_objective_exact" => FI.exact_string(item.value), "global_optimal" => false))
            apply_hook(i, item)
        end
        HDF5.flush(h5)
        DBI.execute(db, "COMMIT"); started = false; committed = true
        close(index)
        require(FI.sha(dbsrc) == expected_database_sha256 && FI.sha(h5src) == expected_archive_sha256, "Parent snapshot changed during import")
        report = Dict("schema" => "qubolib-validated-point-stage-v1", "outcome" => "staged",
            "import_id" => bundle.data["import_id"], "bundle_sha256" => bundle.sha256,
            "source_database_sha256" => expected_database_sha256, "source_archive_sha256" => expected_archive_sha256,
            "staged_database_sha256" => FI.sha(dbpath), "staged_archive_sha256" => FI.sha(h5path),
            "importer_sha256" => FI.sha(@__FILE__), "support_importer_sha256" => FI.sha(joinpath(@__DIR__, "import_followup_results.jl")),
            "verifier" => FI.verifier_identity(verifier), "solutions_added" => length(changes),
            "distinct_instances" => length(bundle.ids), "preprocessing_records_added" => 0, "exact_global_proofs_added" => 0,
            "historical_preprocessing_preserved" => true, "native_source_feasibility" => "unknown", "changes" => changes)
        FI.write_new_json(joinpath(output, "diff-report.json"), report)
        return report
    catch err
        started && DBI.execute(db, "ROLLBACK")
        if isopen(h5)
            for group in setdiff(Set(String.(keys(h5["solutions"]))), original_groups)
                HDF5.delete_object(h5["solutions"], group)
            end
            HDF5.flush(h5)
        end
        close(index)
        FI.write_new_json(joinpath(output, "failed-import.json"), Dict("outcome" => committed ? "failed_after_commit_unpublishable" : "failed_rolled_back",
            "error" => sprint(showerror, err), "staged_copy_not_publishable" => true))
        rethrow()
    finally
        close(index)
    end
end

function main(args=ARGS)
    if args == ["--help"]
        println("Copy-only feasible-point import: --source-database=FILE --source-archive=FILE --database-sha256=HEX --archive-sha256=HEX --bundle=FILE --bundle-sha256=HEX --output=NEW_DIR --witness-tools=FILE --witness-tools-sha256=HEX")
        return 0
    end
    cfg = Dict{String,String}()
    for arg in args
        require(startswith(arg, "--") && occursin('=', arg), "Expected --key=value")
        key, value = split(arg[3:end], '='; limit=2)
        require(!haskey(cfg, key), "Repeated option $key"); cfg[key] = value
    end
    fields = ["source-database", "source-archive", "database-sha256", "archive-sha256", "bundle", "bundle-sha256", "output", "witness-tools", "witness-tools-sha256"]
    require(Set(keys(cfg)) == Set(fields), "Required options: " * join(fields, ", "))
    lowercase(first(split(gethostname(), '.'))) == "dantzig" || error("Real catalogue point staging is allowed only on Dantzig")
    verifier = FI.PinnedWitnessVerifier(cfg["witness-tools"], cfg["witness-tools-sha256"])
    stage_points(; source_database=cfg["source-database"], source_archive=cfg["source-archive"],
        expected_database_sha256=cfg["database-sha256"], expected_archive_sha256=cfg["archive-sha256"],
        bundle_path=cfg["bundle"], expected_bundle_sha256=cfg["bundle-sha256"], output=cfg["output"], verifier)
    return 0
end

end # module
if abspath(PROGRAM_FILE) == @__FILE__
    exit(ValidatedPointImport.main())
end
