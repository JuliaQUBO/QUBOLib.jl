#!/usr/bin/env julia
"""Internal, copy-only importer for explicitly pinned follow-up capture runs.

This script does not update Artifacts.toml, migrate a source catalogue, or publish
an artifact. Its output is a reviewable private catalogue and a diff receipt.
"""
module FollowupImport

using Dates, SHA, JSON, SQLite, HDF5
import QUBOLib, QUBOTools

const DBI = QUBOLib.DBInterface
const Exact = Rational{BigInt}
const SCHEMA = "qubolib-preprocessing-run-v1"
const SOLVER = "QUBOPreprocessing.jl/followup"

require(ok, message) = ok || throw(ArgumentError(message))
sha(path) = bytes2hex(open(sha256, path))
function canonical_json(x)
    x isa AbstractDict && return "{" * join((JSON.json(String(k)) * ":" * canonical_json(x[k]) for k in sort!(collect(keys(x));by=String)), ",") * "}"
    x isa AbstractVector && return "[" * join(canonical_json.(x), ",") * "]"
    return JSON.json(x)
end
function write_new_json(path, value)
    ispath(path) && throw(ArgumentError("Refusing to overwrite $path"))
    open(path, "w") do io
        print(io, canonical_json(value), '\n')
    end
end
hexhash(x) = x isa AbstractString && occursin(r"^[0-9a-f]{64}$", x)
function exact_parse(value)
    require(value isa String && occursin(r"^-?(0|[1-9][0-9]*)/[1-9][0-9]*$", value) && ncodeunits(value) <= 8193, "Noncanonical exact objective")
    a,b = split(value, '/'); q = parse(BigInt,a)//parse(BigInt,b)
    require(string(numerator(q),"/",denominator(q)) == value, "Noncanonical rational")
    return q
end
exact_string(q) = string(numerator(q),"/",denominator(q))

"""A verifier is executable policy, never a serialized verification receipt.

Synthetic tests may implement this interface. The CLI accepts only the SHA-pinned
reviewed helper below. Every verifier receives a freshly loaded source model.
"""
abstract type AbstractWitnessVerifier end
source_hash(::AbstractWitnessVerifier, raw) = error("Implement source_hash")
verify_evidence(::AbstractWitnessVerifier, path, raw, expected) = error("Implement verify_evidence")
verifier_identity(::AbstractWitnessVerifier) = error("Implement verifier_identity")
load_source(::AbstractWitnessVerifier,index,iid) = source_raw(index,iid)

struct PinnedWitnessVerifier <: AbstractWitnessVerifier
    path::String
    file_sha256::String
    helper::Module
end
function PinnedWitnessVerifier(path::AbstractString, expected_sha256::AbstractString)
    full = realpath(path)
    require(hexhash(expected_sha256) && sha(full) == expected_sha256, "Witness helper SHA256 mismatch")
    helper = Module(gensym(:PinnedFollowupWitness))
    Base.include(helper, full)
    require(isdefined(helper,:LibraryWitnesses), "Witness helper module missing")
    return PinnedWitnessVerifier(full, String(expected_sha256), getfield(helper,:LibraryWitnesses))
end
function check_helper(v::PinnedWitnessVerifier)
    require(sha(v.path) == v.file_sha256, "Witness helper changed after loading")
end
source_hash(v::PinnedWitnessVerifier, raw) = (check_helper(v); Base.invokelatest(v.helper.source_sha256,raw))
function load_source(v::PinnedWitnessVerifier,index,iid)
    check_helper(v)
    # Read the actual catalogue archive with the same exact native canonicalizer
    # as capture: duplicate terms and Spin diagonals must not float-aggregate.
    return Base.invokelatest(v.helper.read_native_tuple,index.h5,iid)
end
function verify_evidence(v::PinnedWitnessVerifier,path,raw,expected)
    check_helper(v)
    return Base.invokelatest(v.helper.verify_witness,path;original_raw=raw,expected_source_sha256=expected)
end
verifier_identity(v::PinnedWitnessVerifier) = Dict("kind"=>"sha256_pinned_library_witnesses", "path"=>v.path, "sha256"=>v.file_sha256)

function query(db, sql, args=())
    return DBI.execute(db,sql,args) |> QUBOLib.DataFrame
end
function source_raw(index, iid)
    model = QUBOLib.load_instance(index,iid)
    domain = Symbol(QUBOTools.domain(model))
    require(domain in (:bool,:spin), "Only stored Boolean or Spin QUBOs may be imported")
    sense = Symbol(QUBOTools.sense(model))
    # Preserve the native stored coefficients. A floating Spin→Bool cast can
    # round coefficients, and cannot establish the original source identity.
    n,Ldict,Q,scale,offset = QUBOTools.form(model,:dict;sense,domain)
    L = zeros(Float64,n)
    for (i,value) in Ldict; L[i] = value; end
    raw = (n=Int(n), L=L, Q=Dict{Tuple{Int,Int},Float64}(Q), scale=Float64(scale), offset=Float64(offset), sense=sense, domain=domain)
    require(all(isfinite,L) && all(isfinite,values(raw.Q)) && isfinite(raw.scale) && isfinite(raw.offset), "Nonfinite source coefficients")
    require(all(1 <= u < v <= n for (u,v) in keys(raw.Q)), "Noncanonical stored quadratic indices")
    return raw
end
function native_state(raw,bits)
    require(raw.domain in (:bool,:spin), "Unsupported source domain")
    require(length(bits)==raw.n && all(x->x==0 || x==1,bits), "Invalid encoded binary state")
    return raw.domain===:spin ? Int[2*x-1 for x in bits] : Int.(bits)
end
state_encoding(domain) = domain===:spin ? "binary_x_native_spin_2x_minus_1" : "binary_native_bool"
function exact_objective(raw,state)
    native=native_state(raw,state)
    value=Exact(raw.offset)
    for i in eachindex(raw.L); value+=Exact(raw.L[i])*native[i]; end
    for ((i,j),w) in raw.Q; value+=Exact(w)*native[i]*native[j]; end
    return Exact(raw.scale)*value
end
density(n,m) = n < 2 ? 0.0 : m/(Float64(n)*(n-1)/2)

function confined_file(root, relative)
    require(relative isa String && !isabspath(relative), "Evidence path must be relative to capture directory")
    full = realpath(joinpath(root,relative)); parent = realpath(root)
    require(startswith(full,parent * string(Base.Filesystem.path_separator)), "Evidence path escapes capture directory")
    require(isfile(full), "Missing evidence file")
    return full
end
function load_bundle(path, source_database_sha256, source_archive_sha256, verifier)
    root=realpath(path)
    for name in ("run-plan.json","records.jsonl","terminal.json")
        require(isfile(joinpath(root,name)), "Incomplete capture bundle: $name")
    end
    plan=JSON.parsefile(joinpath(root,"run-plan.json")); terminal=JSON.parsefile(joinpath(root,"terminal.json"))
    require(get(plan,"schema_version",nothing)==1, "Unsupported capture plan schema")
    require(get(terminal,"outcome",nothing) in ("complete","complete_with_failures_or_skips"), "Capture run is unfinished")
    record_hash=sha(joinpath(root,"records.jsonl"))
    require(get(terminal,"records_sha256",nothing)==record_hash, "Capture records do not match terminal hash")
    prov=plan["provenance"]
    require(get(prov,"source_database_sha256",nothing)==source_database_sha256, "Capture catalogue hash differs from source database")
    haskey(prov,"source_archive_sha256") && require(prov["source_archive_sha256"]==source_archive_sha256, "Capture archive hash differs")
    require(hexhash(get(prov,"runner_commit",nothing)) || occursin(r"^[0-9a-f]{40}$",string(get(prov,"runner_commit",""))), "Missing runner revision")
    require(occursin(r"^[0-9a-f]{40}$",string(get(prov,"package_revision",""))) && occursin(r"^[0-9a-f]{40}$",string(get(prov,"package_tree",""))), "Missing package revision/tree")
    cfg=prov["settings"]
    require(get(cfg,"schedule",nothing) in ("current","budgeted"), "Unsupported capture schedule")
    require(get(cfg,"integerize-scale",nothing) isa Bool && get(cfg,"task",nothing) in ("census","zero","incumbents"), "Malformed capture policy")
    modes=get(cfg,"modes",nothing)
    require(modes isa AbstractVector && !isempty(modes) && all(m->m in ("raw","strong","weak"),modes) && length(unique(modes))==length(modes),"Malformed planned modes")
    cfg["schedule"]=="budgeted" && seconds(get(cfg,"prep-seconds",nothing),"planned prep-seconds")
    ids=[nonnegative_int(i,"planned instance ID") for i in plan["instance_ids"]]
    require(length(ids)==length(unique(ids)) && all(>(0),ids), "Invalid plan instance inventory")
    helper_files=get(prov,"runner_files_sha256",Dict())
    require(haskey(helper_files,"scripts/library_witnesses.jl") && hexhash(helper_files["scripts/library_witnesses.jl"]), "Missing capture helper hash")
    # A newer independently pinned verifier may recheck older evidence. Both
    # hashes are retained; a serialized original pass is never sufficient.
    return (root=root,plan=plan,terminal=terminal,provenance=prov,settings=cfg,ids=Set(ids),
        records_sha256=record_hash,plan_sha256=sha(joinpath(root,"run-plan.json")),terminal_sha256=sha(joinpath(root,"terminal.json")),
        capture_helper_sha256=helper_files["scripts/library_witnesses.jl"])
end

function nonnegative_int(x,name)
    require(x isa Integer && !(x isa Bool) && 0 <= x <= typemax(Int), "Invalid $name")
    return Int(x)
end
function seconds(x,name; nullable=false)
    nullable && x===nothing && return nothing
    require(x isa Real && !(x isa Bool) && isfinite(x) && x>=0, "Invalid timing $name")
    return Float64(x)
end
function record_key(row,bundle,run_id,source_sha256)
    target=row["schedule"]=="budgeted" && row["mode"]!="raw" ? get(row,"preprocessing_target_s",get(bundle.settings,"prep-seconds",nothing)) : nothing
    key=Dict{String,Any}("instance_id"=>row["instance_id"],"source_sha256"=>source_sha256,"runner_revision"=>bundle.provenance["runner_commit"],
        "package_revision"=>bundle.provenance["package_revision"],"package_tree"=>bundle.provenance["package_tree"],
        "schedule"=>row["schedule"],"preprocessing_target_s"=>target,
        "mode"=>row["mode"],"run_id"=>run_id,"integerize_scale"=>row["integerize_scale"],"task"=>row["task"])
    for field in ("heuristic","seed","attempt"); haskey(row,field) && (key[field]=row[field]); end
    return key,bytes2hex(sha256(canonical_json(key)))
end
function parse_metadata(value)
    (ismissing(value) || value===nothing || value=="") && return Dict{String,Any}()
    metadata=JSON.parse(value)
    require(metadata isa AbstractDict, "Existing instance metadata is not an object")
    return metadata
end

function validate_row(index,row,bundle,run_id,artifact_tree,source_db_sha,source_h5_sha,verifier)
    require(get(row,"schema_version",nothing)==1, "Unsupported capture record schema")
    iid=nonnegative_int(get(row,"instance_id",nothing),"instance ID"); require(iid in bundle.ids,"Record outside declared capture inventory")
    table=query(index.db,"SELECT instance, collection, name, dimension, sense, domain, metadata FROM Instances WHERE instance=?",(iid,))
    require(size(table,1)==1,"Unknown catalogue instance")
    r=table[1,:]
    require(row["collection"]==r.collection && row["name"]==(ismissing(r.name) ? nothing : r.name) && lowercase(row["sense"])==lowercase(r.sense), "Catalogue instance identity mismatch")
    require(lowercase(r.domain) in ("bool","spin"), "Catalogue instance has unsupported stored domain")
    haskey(row,"source_domain") && require(row["source_domain"]==lowercase(r.domain),"Reported native source domain differs from catalogue")
    haskey(row,"state_encoding") && require(row["state_encoding"]==state_encoding(Symbol(lowercase(r.domain))),"Reported source state encoding differs")
    require(row["mode"] in ("raw","strong","weak") && row["mode"] in bundle.settings["modes"], "Unplanned preprocessing mode")
    require(row["schedule"]==bundle.settings["schedule"] && row["integerize_scale"]===bundle.settings["integerize-scale"] && row["task"]==bundle.settings["task"], "Record policy differs from capture plan")
    status=get(row,"status",nothing)
    require(status in ("ok","error","skipped_capacity_guard","certificate_verification_failed"),"Unrecognized record status")
    raw=nothing; source_hash_value=nothing
    if haskey(row,"source_sha256")
        require(hexhash(row["source_sha256"]),"Malformed model hash")
        raw=load_source(verifier,index,iid); source_hash_value=source_hash(verifier,raw)
        require(source_hash_value==row["source_sha256"],"Fresh catalogue model hash mismatch")
        require(raw.n==r.dimension && String(raw.sense)==lowercase(r.sense) && String(raw.domain)==lowercase(r.domain),"Catalogue row and stored model disagree")
        require(nonnegative_int(row["n_orig"],"original dimension")==raw.n && nonnegative_int(row["m_orig"],"original edge count")==length(raw.Q),"Original dimensions differ from catalogue model")
    else
        require(status!="ok", "Successful record lacks model hash")
        # A skipped/error record binds the immutable input snapshot and row ID;
        # it does not fabricate a per-model content hash or a verified result.
        source_hash_value="unloaded:"*source_h5_sha*":"*string(iid)
    end
    key,key_hash=record_key(row,bundle,run_id,source_hash_value)
    metadata=parse_metadata(r.metadata); history=get!(metadata,"preprocessing_runs",Any[])
    require(history isa AbstractVector,"Existing preprocessing_runs is not an array")
    require(!any(item->item isa AbstractDict && get(item,"key_sha256",nothing)==key_hash,history), "Duplicate/conflicting preprocessing run key")
    times=Dict{String,Any}()
    for (name,value) in row
        endswith(name,"_s") && value!==nothing && (times[name]=seconds(value,name))
    end
    original=Dict{String,Any}("n"=>Int(r.dimension),"m"=>get(row,"m_orig",nothing),"density"=>get(row,"density_orig",nothing))
    reduced=Dict{String,Any}("n"=>nothing,"m"=>nothing,"density"=>nothing)
    if status=="ok"
        if row["schedule"]=="budgeted" && row["mode"]!="raw"
            require(haskey(row,"preprocessing_target_s") && seconds(row["preprocessing_target_s"],"preprocessing_target_s")==seconds(bundle.settings["prep-seconds"],"planned prep-seconds"),"Preprocessing target differs from frozen plan")
        end
        nr=nonnegative_int(row["n_res"],"residual dimension"); mr=nonnegative_int(row["m_res"],"residual edge count")
        require(nr<=raw.n && mr<=big(nr)*(nr-1)÷2,"Impossible residual dimensions")
        require(get(row,"zero_residual",nr==0)==(nr==0),"Inconsistent zero-residual marker")
        for field in ("density_orig","density_res")
            if haskey(row,field)
                expected=field=="density_orig" ? density(raw.n,length(raw.Q)) : density(nr,mr)
                require(row[field] isa Real && isfinite(row[field]) && isapprox(row[field],expected;atol=1e-15,rtol=1e-12),"Inconsistent $field")
            end
        end
        original["density"]=density(raw.n,length(raw.Q)); reduced=Dict("n"=>nr,"m"=>mr,"density"=>density(nr,mr))
        haskey(row,"preprocessing_s") || error("Successful record lacks preprocessing time")
    end
    counts=get(row,"proof_step_counts",Dict{String,Any}())
    require(counts isa AbstractDict && all(v->v isa Integer && !(v isa Bool) && v>=0,values(counts)),"Invalid rule counts")
    evidence=nothing
    if haskey(row,"witness_path")
        require(status=="ok" && raw!==nothing,"Failed record cannot import a solution")
        path=confined_file(bundle.root,row["witness_path"]); witness_sha=sha(path)
        require(get(row,"witness_sha256",nothing)==witness_sha,"Witness hash differs from capture record")
        checked=verify_evidence(verifier,path,raw,source_hash_value)
        require(get(checked,"verification",nothing)=="pass" && get(checked,"library_source_checked",false)===true &&
            get(checked,"source_sha256",nothing)==source_hash_value && get(checked,"witness_sha256",nothing)==witness_sha &&
            get(checked,"original_dimension",nothing)==raw.n,"Independent evidence verification did not pass against catalogue source")
        document=JSON.parsefile(path)
        witness_metadata=get(document,"metadata",Dict())
        require(witness_metadata isa AbstractDict,"Malformed witness metadata")
        for field in ("instance_id","collection","name","sense","mode")
            haskey(witness_metadata,field) && require(witness_metadata[field]==row[field],"Witness and result instance/policy identity differ: $field")
        end
        witness_provenance=get(document,"provenance",Dict())
        require(witness_provenance isa AbstractDict,"Malformed witness provenance")
        haskey(witness_provenance,"source_database_sha256") && require(witness_provenance["source_database_sha256"]==source_db_sha,"Witness catalogue snapshot differs")
        haskey(witness_provenance,"source_archive_sha256") && require(witness_provenance["source_archive_sha256"]==source_h5_sha,"Witness archive snapshot differs")
        bitstring=get(document,"original_bitstring",nothing)
        require(bitstring isa String && ncodeunits(bitstring)==raw.n && all(c->c=='0'||c=='1',bitstring),"Witness original vector is not binary")
        state=Int[c=='1' for c in bitstring]; value=exact_objective(raw,state)
        require(exact_string(value)==get(document,"original_objective_exact",nothing)==get(checked,"original_objective_exact",nothing)==get(row,"original_objective_exact",nothing),"Exact original objective mismatch")
        require(get(checked,"global_optimal",nothing) isa Bool,"Verifier omitted typed global-optimality conclusion")
        if get(document,"schema",nothing)=="qubolib-exact-witness-v1"
            # The helper has already independently replayed and compared this
            # exact residual. Bind the reported metrics to that verified result.
            require(get(checked,"residual_dimension",nothing)==reduced["n"] &&
                length(document["exact_residual"]["quadratic"])==reduced["m"],"Reported residual dimensions differ from exact replay")
        end
        global_optimal=checked["global_optimal"]
        if global_optimal
            require(get(document,"schema",nothing)=="qubolib-exact-witness-v1" && get(document,"proof_scope",nothing)=="unconditioned_original" && reduced["n"]==0 &&
                get(checked,"residual_dimension",nothing)==0,"Global certification requires replayed unconditioned zero residual")
            require(get(row,"input_perturbed",false)===false,"Perturbed-input runs cannot certify original global optimality")
        end
        require(isfinite(Float64(value)),"Exact objective is outside finite storage range")
        evidence=(path=path,sha256=witness_sha,state=state,native_state=native_state(raw,state),domain=raw.domain,
            value=value,global_optimal=global_optimal,verification=checked,
            schema=get(document,"schema",nothing))
    end
    certified=evidence!==nothing && evidence.global_optimal
    replayed=evidence!==nothing && evidence.schema=="qubolib-exact-witness-v1"
    entry=Dict{String,Any}("schema"=>SCHEMA,"key"=>key,"key_sha256"=>key_hash,"status"=>status,
        "source"=>Dict("artifact_tree"=>artifact_tree,"database_sha256"=>source_db_sha,"archive_sha256"=>source_h5_sha,
            "instance_id"=>iid,"collection"=>row["collection"],"name"=>row["name"],"sense"=>row["sense"],
            "domain"=>lowercase(r.domain),"state_encoding"=>state_encoding(Symbol(lowercase(r.domain))),
            "model_sha256"=>raw===nothing ? nothing : source_hash_value),
        "original"=>original,"reduced"=>reduced,"rule_counts"=>counts,"timing_phases_s"=>times,
        "stop_reason"=>get(row,"stop_reason",nothing),"scheduler"=>get(row,"scheduler",nothing),
        "normalization"=>Dict("integerize_scale"=>row["integerize_scale"],"input_perturbed"=>get(row,"input_perturbed",nothing),
            "input_max_perturbation"=>get(row,"input_max_perturbation",nothing)),
        "materialization"=>Dict("status"=>get(row,"materialization_status",nothing),"rounding"=>"nearest",
            "export_perturbed"=>get(row,"export_perturbed",nothing),"export_max_perturbation"=>get(row,"export_max_perturbation",nothing)),
        "verification"=>Dict("catalogue_model_checked"=>raw!==nothing,"reduction"=>replayed ? "independently_replayed" : "reported_only",
            "global_optimal"=>certified,"reported"=>get(row,"verification",nothing),"independent"=>evidence===nothing ? nothing : evidence.verification,
            "native_source_feasibility"=>"unknown"),
        "guards_errors"=>Dict(field=>get(row,field,nothing) for field in ("error","max_variables","max_edges","quadratic_entries")),
        "provenance"=>Dict("capture_directory"=>bundle.root,"run_plan_sha256"=>bundle.plan_sha256,
            "results_sha256"=>bundle.records_sha256,"terminal_sha256"=>bundle.terminal_sha256,
            "capture_helper_sha256"=>bundle.capture_helper_sha256,"import_verifier"=>verifier_identity(verifier),
            "runner_files_sha256"=>bundle.provenance["runner_files_sha256"],"witness_path"=>evidence===nothing ? nothing : row["witness_path"],
            "witness_sha256"=>evidence===nothing ? nothing : evidence.sha256),
        # Keep diagnostic claims verbatim, separate from authoritative fields.
        "reported_record"=>row)
    return (iid=iid,metadata=metadata,history=history,entry=entry,evidence=evidence)
end

function add_evidence!(index,item,submission,source_path)
    e=item.evidence; e===nothing && return nothing
    row=item.entry["reported_record"]
    predecessor=get(row,"predecessor_record",nothing)
    if predecessor!==nothing
        nonnegative_int(predecessor,"predecessor record")
        parent=query(index.db,"SELECT instance, submission FROM SolutionRecords WHERE record=?",(predecessor,))
        require(size(parent,1)==1 && parent.instance[1]==item.iid,"Predecessor record belongs to another instance or is missing")
        if get(row,"predecessor_submission",nothing)!==nothing
            require(!ismissing(parent.submission[1]) && row["predecessor_submission"]==parent.submission[1],"Predecessor submission does not match the original record")
        end
    else
        require(get(row,"predecessor_submission",nothing)===nothing,"Predecessor submission requires an identified original record")
    end
    metadata=Dict{String,Any}("solver"=>SOLVER,"status"=>e.global_optimal ? "optimal" : "feasible",
        "followup_import_schema"=>SCHEMA,"preprocessing_run_key_sha256"=>item.entry["key_sha256"],
        "original_objective_exact"=>exact_string(e.value),"objective_sense"=>item.entry["source"]["sense"],
        "source"=>item.entry["source"],"provenance"=>item.entry["provenance"],"independent_verification"=>e.verification,
        "predecessor_record"=>predecessor,"predecessor_submission"=>get(row,"predecessor_submission",nothing),
        "encoded_bitstring"=>join(e.state),"stored_domain"=>String(e.domain),"state_encoding"=>state_encoding(e.domain),
        "binary_qubo_feasible"=>e.domain===:bool ? true : nothing,"encoded_boolean_feasible"=>true,
        "stored_qubo_domain_feasible"=>true,"native_source_feasibility"=>"unknown")
    sample=QUBOTools.Sample{Float64,Int}(e.native_state,Float64(e.value),1)
    sol=QUBOTools.SampleSet{Float64,Int}([sample],metadata;sense=Symbol(item.entry["source"]["sense"]),domain=e.domain)
    sid=QUBOLib.add_solution!(index,item.iid,sol;submission,qubo_value=Float64(e.value),source_value=nothing,
        source_feasible=nothing,proven_optimal=e.global_optimal,feasibility_status="feasible",validation_status="verified",source_path)
    records=query(index.db,"SELECT record FROM SolutionRecords WHERE instance=? AND solution=?",(item.iid,sid))
    return (solution=Int(sid),record=Int(only(records.record)))
end

"""Stage capture runs into NEW copies. Source files must be immutable snapshots.

`apply_hook` is a typed fixture fault-injection hook, never a CLI input. On a
failure SQL rolls back and newly created HDF5 groups are removed from this new
private copy. The failed directory and failure receipt remain for inspection.
"""
function stage_import(;source_database,source_archive,output,runs,artifact_tree,run_id,
    expected_database_sha256,expected_archive_sha256,verifier::AbstractWitnessVerifier,
    expected_instance_count::Union{Nothing,Int}=nothing,apply_hook::Function=(i,item)->nothing)
    require(!ispath(output) && isdir(dirname(abspath(output))),"Staging output must be a NEW directory under an existing parent")
    require(!isempty(run_id) && !isempty(runs),"Explicit run ID and capture directories are required")
    require(occursin(r"^[0-9a-f]{40}$",artifact_tree),"Explicit source artifact tree hash is required")
    dbsrc=realpath(source_database); h5src=realpath(source_archive)
    require(dbsrc!=h5src && isfile(dbsrc) && isfile(h5src),"Invalid source snapshot")
    destination=joinpath(realpath(dirname(abspath(output))),basename(normpath(output)))
    for parent in (dirname(dbsrc),dirname(h5src))
        require(destination!=parent && !startswith(destination,parent*string(Base.Filesystem.path_separator)),"Staging output must be outside the immutable source directories")
    end
    require(hexhash(expected_database_sha256) && hexhash(expected_archive_sha256),"Expected source file hashes are required")
    require(!isfile(dbsrc*"-wal") || filesize(dbsrc*"-wal")==0,"Source SQLite WAL must be checkpointed before snapshot import")
    require(sha(dbsrc)==expected_database_sha256 && sha(h5src)==expected_archive_sha256,"Source snapshot SHA256 mismatch")
    bundles=[load_bundle(p,expected_database_sha256,expected_archive_sha256,verifier) for p in runs]
    inventory=union((bundle.ids for bundle in bundles)...)
    expected_instance_count===nothing || require(expected_instance_count>0 && length(inventory)==expected_instance_count,"Planned global instance count differs from frozen import scope")
    mkdir(output)
    dbpath=joinpath(output,"index.db"); h5path=joinpath(output,"archive.h5")
    cp(dbsrc,dbpath;force=false); cp(h5src,h5path;force=false)
    require(sha(dbpath)==expected_database_sha256 && sha(h5path)==expected_archive_sha256,"Source changed during staging copy")
    # Installed artifact files are read-only. Change permissions only on the
    # newly created private copies, matching QUBOLib's own copy-on-access policy.
    chmod(dbpath,0o600);chmod(h5path,0o600)
    db=SQLite.DB(dbpath); h5=h5open(h5path,"r+"); index=QUBOLib.LibraryIndex(db,h5,abspath(output))
    original_groups=Set(String.(keys(h5["solutions"]))); started=false; committed=false
    changes=Any[]; seen=Set{String}(); count_records=0; count_solutions=0; count_certified=0
    try
        DBI.execute(db,"BEGIN IMMEDIATE TRANSACTION"); started=true
        QUBOLib.has_solver(index,SOLVER) || QUBOLib.add_solver!(index,SOLVER,Dict("description"=>"Independently verified staged follow-up evidence"))
        for bundle in bundles
            submission=QUBOLib.add_submission!(index;source_path=bundle.root,
                metadata=Dict("schema"=>SCHEMA,"run_id"=>run_id,"capture_plan_sha256"=>bundle.plan_sha256,
                    "capture_results_sha256"=>bundle.records_sha256,"runner_revision"=>bundle.provenance["runner_commit"],
                    "package_revision"=>bundle.provenance["package_revision"]))
            observed=0; observed_pairs=Set{Tuple{Int,String}}()
            open(joinpath(bundle.root,"records.jsonl"),"r") do io
                for line in eachline(io)
                    require(!isempty(strip(line)),"Blank capture result line")
                    row=JSON.parse(line); require(row isa AbstractDict,"Capture result is not an object")
                    item=validate_row(index,row,bundle,run_id,artifact_tree,expected_database_sha256,expected_archive_sha256,verifier)
                    require(!(item.entry["key_sha256"] in seen),"Duplicate/conflicting run key in import")
                    push!(seen,item.entry["key_sha256"]); observed+=1
                    push!(observed_pairs,(item.iid,String(row["mode"])))
                    push!(item.history,item.entry)
                    DBI.execute(db,"UPDATE Instances SET metadata=? WHERE instance=?",(canonical_json(item.metadata),item.iid))
                    saved=add_evidence!(index,item,submission,get(row,"witness_path",bundle.root))
                    saved!==nothing && (count_solutions+=1)
                    item.evidence!==nothing && item.evidence.global_optimal && (count_certified+=1)
                    count_records+=1
                    push!(changes,Dict("instance_id"=>item.iid,"key_sha256"=>item.entry["key_sha256"],"status"=>row["status"],
                        "solution_id"=>saved===nothing ? nothing : saved.solution,"record_id"=>saved===nothing ? nothing : saved.record,
                        "global_optimal"=>item.evidence!==nothing && item.evidence.global_optimal))
                    apply_hook(count_records,item)
                end
            end
            require(observed==get(bundle.terminal,"records",nothing),"Capture terminal record count mismatch")
            expected_pairs=Set((iid,String(mode)) for iid in bundle.ids for mode in bundle.settings["modes"])
            require(observed_pairs==expected_pairs,"Capture instance/mode inventory is incomplete")
        end
        HDF5.flush(h5)
        DBI.execute(db,"COMMIT"); started=false; committed=true
        close(index)
        report=Dict("schema"=>"qubolib-followup-stage-v1","outcome"=>"staged","run_id"=>run_id,
            "source_artifact_tree"=>artifact_tree,"source_database_sha256"=>expected_database_sha256,"source_archive_sha256"=>expected_archive_sha256,
            "staged_database_sha256"=>sha(dbpath),"staged_archive_sha256"=>sha(h5path),
            "importer_sha256"=>sha(@__FILE__),"verifier"=>verifier_identity(verifier),
            "distinct_instances"=>length(inventory),"expected_instance_count"=>expected_instance_count,
            "preprocessing_records_added"=>count_records,"solutions_added"=>count_solutions,"exact_global_proofs_added"=>count_certified,
            "historical_preprocessing_preserved"=>true,"native_source_feasibility"=>"unknown","changes"=>changes)
        write_new_json(joinpath(output,"diff-report.json"),report)
        return report
    catch err
        started && DBI.execute(db,"ROLLBACK")
        if isopen(h5)
            for group in setdiff(Set(String.(keys(h5["solutions"]))),original_groups)
                HDF5.delete_object(h5["solutions"],group)
            end
            HDF5.flush(h5)
        end
        close(index)
        write_new_json(joinpath(output,"failed-import.json"),Dict("outcome"=>committed ? "failed_after_commit_unpublishable" : "failed_rolled_back","error"=>sprint(showerror,err),
            "source_database_sha256"=>expected_database_sha256,"source_archive_sha256"=>expected_archive_sha256,
            "staged_copy_not_publishable"=>true))
        rethrow()
    finally
        close(index)
    end
end

function main(args=ARGS)
    if args==["--help"]
        println("Internal copy-only import: --source-database=FILE --source-archive=FILE --database-sha256=HEX --archive-sha256=HEX --artifact-tree=HEX --run-id=ID --expected-instance-count=N --runs=DIR[,DIR...] --output=NEW_DIR --witness-tools=FILE --witness-tools-sha256=HEX")
        return 0
    end
    cfg=Dict{String,String}()
    for arg in args
        require(startswith(arg,"--") && occursin('=',arg),"Expected --key=value")
        key,value=split(arg[3:end],'=';limit=2);require(!haskey(cfg,key),"Repeated option $key");cfg[key]=value
    end
    fields=["source-database","source-archive","database-sha256","archive-sha256","artifact-tree","run-id","expected-instance-count","runs","output","witness-tools","witness-tools-sha256"]
    require(Set(keys(cfg))==Set(fields),"Required options: "*join(fields,", "))
    lowercase(first(split(gethostname(),'.')))=="dantzig" || error("Real catalogue follow-up staging is allowed only on Dantzig")
    verifier=PinnedWitnessVerifier(cfg["witness-tools"],cfg["witness-tools-sha256"])
    stage_import(;source_database=cfg["source-database"],source_archive=cfg["source-archive"],
        expected_database_sha256=cfg["database-sha256"],expected_archive_sha256=cfg["archive-sha256"],
        artifact_tree=cfg["artifact-tree"],run_id=cfg["run-id"],expected_instance_count=parse(Int,cfg["expected-instance-count"]),runs=split(cfg["runs"],','),output=cfg["output"],verifier)
    return 0
end

end # module
if abspath(PROGRAM_FILE)==@__FILE__
    exit(FollowupImport.main())
end
