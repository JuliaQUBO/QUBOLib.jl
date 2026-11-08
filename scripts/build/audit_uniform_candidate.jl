"""Read-only scientific consistency checks for a closed uniform candidate."""
module UniformCandidateAudit
include("uniform_candidate.jl")
const U = UniformCandidate
const Q = U.QUBOLib
const T = U.QUBOTools
const QT_TREE = "91c59cbdb1ee82f54e36b377eab7814629294215"

function tools_identity()
    dependency=only(p for p in values(U.Pkg.dependencies()) if p.name=="QUBOTools")
    check(Base.pkgversion(T)==v"0.16.4" && dependency.is_tracking_registry && string(dependency.tree_hash)==QT_TREE,"wrong registered QUBOTools pin")
    check(realpath(pathof(T))==realpath(joinpath(dependency.source,"src","QUBOTools.jl")),"wrong loaded QUBOTools source")
    check(bytes2hex(U.Pkg.GitTools.tree_hash(dependency.source))==QT_TREE,"QUBOTools source bytes differ")
    return Dict("version"=>"0.16.4","tree"=>QT_TREE,"loaded_source"=>pathof(T))
end

rows(index,sql,args=())=Q.DBInterface.execute(Q.database(index),sql,args) |> Q.DataFrame
check(x,m)=U.require(x,m)
nullable(x)=(ismissing(x) || isnothing(x)) ? nothing : x
function prep_audit(index,x,identity)
    id=x["instance"]; r=only(eachrow(rows(index,"SELECT metadata FROM Instances WHERE instance=?;",(id,))))
    m=U.JSON.parse(String(r.metadata));check(!haskey(m,"preprocessing_runs"),"historical enrichment")
    p=m["preprocessing"];check(p["input"]==x,"wrong original identity")
    v=p["provenance"];check(v["result_source"]==v["coercive_source"]=="pipeline","nonlive result")
    check(v["qubolib_build_commit"]==identity["builder"]["commit"] && v["qubolib_build_tree_dirty"]===false,"wrong builder")
    for k in ("project_sha256","manifest_sha256");check(v[k]==identity[k],"wrong environment");end
    check(v["qubopreprocessing_tree_hash"]==U.QP_TREE,"wrong preprocessing tree")
    for mode in ("strong","weak")
        r=p[mode*"_run"];check(r["certificate_verified"]==p[mode*"_certified"],"certificate flag mismatch")
        check(p[mode*"_time_s"]==r["clocks"]["preparation_s"],"mode clock mismatch")
        check(all(haskey(r["normalization"],k) for k in ("workspace_perturbed","workspace_max_perturbation","export_perturbed","export_max_perturbation")),"missing perturbation flags")
    end
    return p
end

positive_id(x) = x isa Integer && !(x isa Bool) && 0 < x <= typemax(Int)
nonnegative_int(x) = x isa Integer && !(x isa Bool) && 0 <= x <= typemax(Int)
finite_nonnegative(x) = x isa Real && !(x isa Bool) && isfinite(x) && x >= 0

function expected_originals(values; counts=U.COUNTS)
    check(values isa AbstractVector, "original inventory must be an array")
    check(length(values)==sum(Base.values(counts)), "incomplete original inventory")
    ids=Int[]; identities=Tuple{String,String}[]; actual=Dict{String,Int}()
    for x in values
        check(positive_id(x["instance"]), "invalid original instance ID")
        check(x["collection"] isa String && x["name"] isa String && !isempty(x["name"]), "invalid collection/name identity")
        check(x["fingerprint_schema"]=="qubolib-stored-model-v1" && occursin(r"^[0-9a-f]{64}$",x["sha256"]), "invalid native model fingerprint")
        check(nonnegative_int(x["dimension"]) && nonnegative_int(x["quadratic_terms"]), "invalid original dimensions")
        check(x["domain"] in ("bool","spin") && x["sense"] in ("min","max"), "invalid native domain/sense")
        push!(ids,Int(x["instance"]));push!(identities,(x["collection"],x["name"]))
        actual[x["collection"]]=get(actual,x["collection"],0)+1
    end
    check(length(Set(ids))==length(ids) && length(Set(identities))==length(identities), "duplicate original ID or collection/name")
    check(actual==counts, "unexpected original collection counts")
    return Dict(Int(x["instance"])=>x for x in values)
end

function enrichment_journal(path, ids)
    check(isfile(path) && !islink(path), "missing/linked enrichment journal")
    check(filesize(path)>0, "empty enrichment journal")
    open(path,"r") do io
        seekend(io);skip(io,-1);check(read(io,UInt8)==0x0a,"unterminated enrichment journal")
    end
    result=Dict{Int,Any}(); order=Int[]
    for line in eachline(path)
        check(!isempty(line),"empty enrichment journal row")
        x=U.JSON.parse(line)
        check(x isa AbstractDict && positive_id(x["instance"]),"invalid journal instance")
        id=Int(x["instance"])
        check(id in ids && !haskey(result,id),"unknown or duplicate journal instance")
        check(x["status"]=="enriched", "unsuccessful enrichment journal row")
        for name in ("exact_count","repaired_strong_count","repaired_weak_count")
            check(nonnegative_int(x[name]),"invalid journal record count")
        end
        result[id]=x;push!(order,id)
    end
    check(order==sort!(collect(ids)),"missing or reordered journal coverage")
    return result
end

function submission_pair(index)
    data=rows(index,"SELECT submission,metadata FROM Submissions WHERE submitter='QUBOPreprocessing.jl' ORDER BY submission;")
    check(size(data,1)==2,"exactly one preprocessing submission pair is required")
    found=Dict{String,Int}(); starts=Any[]
    for r in eachrow(data)
        meta=U.JSON.parse(String(r.metadata)); kind=meta["submission_kind"]
        check(kind in ("certified_exact_reduction","certified_solution_repair") && !haskey(found,kind),"duplicate/unknown preprocessing submission kind")
        check(meta["package"]=="QUBOPreprocessing.jl" && meta["version"]=="0.2.1", "wrong preprocessing submission package")
        found[kind]=Int(r.submission);push!(starts,meta["run_started_unix_s"])
    end
    check(starts[1]==starts[2] && finite_nonnegative(starts[1]),"submission pair has mixed run identity")
    ids=(exact=found["certified_exact_reduction"],repair=found["certified_solution_repair"])
    U._validate_preprocessing_submissions(index,ids)
    return ids
end

function check_preparation(index, x, identity, expected_provenance)
    p=prep_audit(index,x,identity)
    raw=only(eachrow(rows(index,"SELECT metadata FROM Instances WHERE instance=?;",(Int(x["instance"]),))))
    meta=U.JSON.parse(String(raw.metadata))
    check(p["schema"]=="qubolib-builder-preprocessing-v1" && p["package"]=="QUBOPreprocessing.jl" && p["version"]=="0.2.1", "wrong preprocessing report")
    for (key,value) in expected_provenance
        check(haskey(p["provenance"],key) && isequal(p["provenance"][key],value), "mixed preprocessing provenance: $key")
    end
    check(p["n_init"]==x["dimension"] && p["m_init"]==x["quadratic_terms"],"wrong initial reduction size")
    for mode in ("strong","weak")
        run=p[mode*"_run"]
        check(run["policy"]==U._qubopreprocessing_policy(Symbol(mode),5.0),"wrong mode policy")
        for key in ("n_"*mode,"m_"*mode)
            check(nonnegative_int(p[key]) && meta[key]==p[key],"inconsistent top-level reduction size")
        end
        check(run["initial_variables"]==x["dimension"] && run["residual_variables"]==p["n_"*mode] <= x["dimension"],"inconsistent diagnostic dimensions")
        check(p[mode*"_certified"] isa Bool && run["certificate_verified"]===p[mode*"_certified"],"incorrect certificate flag")
        check(p[mode*"_time_s"]==run["clocks"]["preparation_s"],"inconsistent preparation clock")
        for (key,value) in run["clocks"]
            check(endswith(key,"_s") && finite_nonnegative(value),"invalid mode clock")
        end
        for key in ("workspace_perturbed","export_perturbed")
            check(run["normalization"][key] isa Bool,"missing individual perturbation flag")
        end
    end
    return p
end

function with_readonly_index(f, candidate, scratch)
    library=Q.library_path(candidate)
    check(Set(readdir(library))==Set(["index.db","archive.h5"]),"unexpected/unclosed library members")
    for name in ("index.db","archive.h5")
        check(isfile(joinpath(library,name)) && !islink(joinpath(library,name)),"linked/missing store member")
    end
    check(!ispath(scratch) && !islink(scratch),"audit scratch exists")
    mkdir(scratch);cp(joinpath(library,"index.db"),joinpath(scratch,"index.db"))
    db=Q.SQLite.DB(joinpath(scratch,"index.db"))
    h5=nothing
    try
        Q.DBInterface.execute(db,"PRAGMA query_only=ON;")
        h5=Q.HDF5.h5open(joinpath(library,"archive.h5"),"r")
        return f(Q.LibraryIndex(db,h5,library))
    finally
        !isnothing(h5) && isopen(h5) && close(h5)
        isopen(db) && close(db)
    end
end

function audit_membership(index, originals)
    check(Set(Int.(rows(index,"SELECT instance FROM Instances;").instance))==Set(keys(originals)),"SQL originals differ from inventory")
    for (table,key,group) in (("Instances","instance","instances"),("Solutions","solution","solutions"))
        sql=Set(Int.(rows(index,"SELECT $key FROM $table;")[!,key]))
        stored=Set(parse(Int,name) for name in keys(Q.archive(index)[group]))
        check(sql==stored,"SQL/HDF5 membership mismatch: $table")
    end
    check(isempty(rows(index,"PRAGMA foreign_key_check;")),"orphaned SQL references")
end

function derived_audit(index,id,p,submissions,model=Q.load_instance(index,id))
    result=Any[];domain=T.domain(model);sense=T.sense(model)
    records=rows(index,"SELECT * FROM SolutionRecords WHERE instance=? AND submission IN (?,?) ORDER BY record;",(id,submissions.exact,submissions.repair))
    source_present=haskey(Q.archive(index)["instances"][string(id)],"source")
    evaluator=isempty(records) ? nothing : U._qoblib_source_evaluator(index,id;context="uniform-output-audit-$id")
    repaired=Set{Tuple{Int,String}}()
    for r in eachrow(records)
        check(!ismissing(r.solution),"derived record lacks HDF5 solution")
        sol=Q.load_solution(index,id,Int(r.solution))
        check(length(sol)==1,"derived SampleSet must contain exactly one sample")
        meta=T.metadata(sol);check(U.JSON.parse(String(r.metadata))==meta,"SQL/HDF5 metadata differ")
        state=T.state(first(sol));check(length(state)==T.dimension(model),"derived dimension mismatch")
        check(all(v->v in (Symbol(domain)==:spin ? (-1,1) : (0,1)),state),"invalid native derived state")
        bits=U._state_to_bool_vector(state,domain);check(join(bits)==String(r.bitstring),"derived stored bitstring mismatch")
        check(Symbol(T.domain(sol))==Symbol(domain) && Symbol(T.sense(sol))==Symbol(sense),"native sample domain/sense mismatch")
        value=Float64(T.value(model,state));check(isapprox(value,Float64(r.qubo_value);atol=1e-8,rtol=1e-8) && isapprox(value,Float64(T.value(sol,1));atol=1e-8,rtol=1e-8),"derived objective mismatch")
        check(isfinite(value),"nonfinite derived objective")
        stored=only(eachrow(rows(index,"SELECT instance,solver,value,optimal FROM Solutions WHERE solution=?;",(Int(r.solution),))))
        check(Int(stored.instance)==id && stored.solver=="QUBOPreprocessing.jl" && isapprox(Float64(stored.value),value;atol=1e-8,rtol=1e-8) && Bool(stored.optimal)==Bool(r.proven_optimal),"Solutions row differs from derived record")
        check(r.validation_status=="validated" && r.feasibility_status=="feasible" && Bool(r.incumbent_candidate),"derived record flags mismatch")
        check(isapprox(Float64(r.source_value),value;atol=1e-8,rtol=1e-8),"source_value compatibility field mismatch")
        exact=Int(r.submission)==submissions.exact;mode=meta[exact ? "reduction_mode" : "repair_mode"]
        check(mode in ("strong","weak"),"invalid derived mode")
        check(meta["solver"]=="QUBOPreprocessing.jl" && meta["solver_version"]=="0.2.1" && nonnegative_int(meta["n_init"]) && nonnegative_int(meta["n_reduced"]) && meta["n_init"]==T.dimension(model) && meta["n_reduced"]==p["n_"*mode],"incorrect derived solver/dimensions")
        for (key,clock) in meta["capture_clocks"]
            key=="scope" || check(endswith(key,"_s") && finite_nonnegative(clock),"invalid capture clock")
        end
        check(meta["preparation_run"]==p[mode*"_run"],"derived record used different measured trace/run")
        certified=p[mode*"_certified"]===true;zero=Int(p["n_"*mode])==0
        check(Bool(r.proven_optimal)==(zero && certified),"incorrect optimality flag")
        parent=nothing
        if exact
            check(meta["origin"]=="certified_exact_reduction" && zero && certified,"invalid exact capture")
            check(meta["m_init"]==p["m_init"] && nonnegative_int(meta["m_reduced"]) && meta["m_reduced"]==0,"incorrect exact edge counts")
            check(isapprox(Float64(r.objective_bound),value;atol=1e-8,rtol=1e-8) && isapprox(Float64(r.dual_bound),value;atol=1e-8,rtol=1e-8),"exact bounds mismatch")
            check(isapprox(value,meta["certified_offset"];atol=1e-8,rtol=1e-8),"certified offset mismatch")
        else
            check(meta["origin"]=="certified_solution_repair","wrong repair origin")
            pr=only(eachrow(rows(index,"SELECT * FROM SolutionRecords WHERE record=?;",(meta["parent_record"],))))
            check(positive_id(meta["parent_record"]) && Int(pr.record)<Int(r.record) && !(nullable(pr.submission) in values(submissions)) && !Bool(pr.proven_optimal),"ineligible original repair parent")
            pair=(Int(pr.record),String(mode));check(!(pair in repaired),"duplicate parent/mode repair");push!(repaired,pair)
            check(Int(pr.instance)==id && nullable(pr.solution)==meta["parent_solution"] && nullable(pr.submission)==meta["parent_submission"],"repair parent linkage mismatch")
            check(pr.bitstring isa AbstractString && length(pr.bitstring)==T.dimension(model) && all(c->c=='0'||c=='1',pr.bitstring),"invalid native parent bitstring")
            parentstate=U._bool_vector_to_domain(Q._bitstring_state(String(pr.bitstring)),domain)
            parentval=Float64(T.value(model,parentstate));check(isapprox(parentval,meta["parent_qubo_value"];atol=1e-8,rtol=1e-8),"parent objective mismatch")
            check(isfinite(parentval) && length(parentstate)==T.dimension(model),"invalid repair parent")
            check(isapprox(meta["qubo_improvement"],value-parentval;atol=1e-8,rtol=1e-8),"incorrect repair improvement")
            check(meta["hamming_distance"]==count(i->state[i]!=parentstate[i],eachindex(state)),"incorrect repair Hamming distance")
            check(U._is_strictly_better_qubo(value,parentval,sense),"repair fails strict improvement")
            if mode=="weak"
                strong=rows(index,"SELECT metadata,qubo_value FROM SolutionRecords WHERE instance=? AND submission=?;",(id,submissions.repair))
                for s in eachrow(strong)
                    sm=U.JSON.parse(String(s.metadata))
                    if sm["repair_mode"]=="strong" && sm["parent_record"]==meta["parent_record"]
                        check(U._is_strictly_better_qubo(value,Float64(s.qubo_value),sense),"weak does not improve strong")
                    end
                end
            end
            parent=Dict("record"=>Int(pr.record),"solution"=>nullable(pr.solution),"submission"=>nullable(pr.submission),"reevaluated_value"=>parentval)
        end
        se=U._qoblib_source_evaluation(evaluator,bits;context="uniform-output-audit-$(r.record)")
        check(isequal(nullable(r.source_objective),nullable(se.source_objective)) || (nullable(r.source_objective) isa Number && se.source_objective isa Number && isapprox(r.source_objective,se.source_objective;rtol=1e-8,atol=1e-8)),"source objective audit mismatch")
        check(isequal(nullable(r.source_feasible),nullable(se.source_feasible)) || (!isnothing(nullable(se.source_feasible)) && !ismissing(r.source_feasible) && Bool(r.source_feasible)==nullable(se.source_feasible)),"source feasible audit mismatch")
        push!(result,Dict(
            "record"=>Int(r.record), "solution"=>Int(r.solution),
            "submission"=>Int(r.submission), "instance"=>id,
            "origin"=>meta["origin"], "mode"=>mode, "reevaluated_value"=>value,
            "proven_optimal"=>Bool(r.proven_optimal), "certificate_verified"=>certified,
            "normalization"=>p[mode*"_run"]["normalization"], "parent"=>parent,
            "capture_clocks"=>meta["capture_clocks"],
            "source_objective"=>nullable(r.source_objective),
            "source_feasible"=>nullable(r.source_feasible),
            "source_evaluation_status"=>!source_present ? "no_stored_source_formulation" :
                isnothing(evaluator) ? "source_evaluator_unavailable" :
                (isnothing(nullable(se.source_objective)) && isnothing(nullable(se.source_feasible))) ? "evaluation_unverified" : "known_fields_reevaluated",
            "source_value"=>nullable(r.source_value),
            "objective_bound"=>nullable(r.objective_bound), "dual_bound"=>nullable(r.dual_bound),
            "validation_status"=>r.validation_status, "feasibility_status"=>r.feasibility_status,
            "incumbent_candidate"=>Bool(r.incumbent_candidate)))
    end
    return result
end

function audit_instance(index, x, journal, submissions, identity, provenance)
    id=Int(x["instance"])
    r=only(eachrow(rows(index,"SELECT collection,name,dimension,domain,sense FROM Instances WHERE instance=?;",(id,))))
    model=Q.load_instance(index,id)
    actual=merge(Dict("instance"=>id,"collection"=>String(r.collection),"name"=>String(r.name)),U._qubopreprocessing_model_identity(model))
    check(actual==x,"original model/SQL identity changed")
    check(Int(r.dimension)==T.dimension(model) && String(r.domain)==x["domain"] && String(r.sense)==x["sense"],"SQL/native dimensions/domain/sense differ")
    p=check_preparation(index,x,identity,provenance)
    derived=derived_audit(index,id,p,submissions,model)
    exact=filter(r->r["origin"]=="certified_exact_reduction",derived)
    expected=p["strong_certified"] && p["n_strong"]==0 ? "strong" : p["weak_certified"] && p["n_weak"]==0 ? "weak" : nothing
    check(length(exact)==(isnothing(expected) ? 0 : 1),"missing or duplicate expected exact capture")
    isnothing(expected) || check(only(exact)["mode"]==expected,"wrong exact mode precedence")
    strong=count(r->r["origin"]=="certified_solution_repair" && r["mode"]=="strong",derived)
    weak=count(r->r["origin"]=="certified_solution_repair" && r["mode"]=="weak",derived)
    check(length(exact)==journal["exact_count"] && strong==journal["repaired_strong_count"] && weak==journal["repaired_weak_count"],"producer journal and actual derived records differ")
    return Dict("instance"=>id,"collection"=>String(r.collection),"name"=>String(r.name),
        "fingerprint"=>actual,"scale_exact"=>string(U._to_exact_rational_qubolib(T.scale(model))),
        "offset_exact"=>string(U._to_exact_rational_qubolib(T.offset(model))),
        "strong_certified"=>p["strong_certified"],"weak_certified"=>p["weak_certified"],
        "strong_normalization"=>p["strong_run"]["normalization"],"weak_normalization"=>p["weak_run"]["normalization"],
        "exact_count"=>length(exact),"repaired_strong_count"=>strong,"repaired_weak_count"=>weak,
        "derived_records"=>derived)
end

function audit_records(index, originals, journal, identity, emit; counts=U.COUNTS)
    U.validate_inventory(index;expected=counts);audit_membership(index,originals)
    pair=submission_pair(index)
    provenance=U._qubopreprocessing_build_provenance(U.QUBOPreprocessing)
    totals=Dict("originals"=>0,"exact"=>0,"repair_strong"=>0,"repair_weak"=>0)
    solutions=Set{Int}()
    for id in sort!(collect(keys(originals)))
        report=audit_instance(index,originals[id],journal[id],pair,identity,provenance)
        totals["originals"]+=1;totals["exact"]+=report["exact_count"]
        totals["repair_strong"]+=report["repaired_strong_count"];totals["repair_weak"]+=report["repaired_weak_count"]
        for r in report["derived_records"]
            check(!(r["solution"] in solutions),"duplicate derived solution ownership")
            push!(solutions,r["solution"])
        end
        emit(report)
        report=nothing;GC.gc(false)
    end
    all_preprocessing=Set(Int.(rows(index,"SELECT solution FROM Solutions WHERE solver='QUBOPreprocessing.jl';").solution))
    check(solutions==all_preprocessing,"unrecorded or missing preprocessing solutions")
    # Iterate the SQL cursor: preparation diagnostics can be large even though
    # only one original/model's full records are retained in the main audit.
    for r in Q.DBInterface.execute(Q.database(index),"SELECT submission,metadata FROM SolutionRecords;")
        meta=ismissing(r.metadata) || isempty(String(r.metadata)) ? Dict() : U.JSON.parse(String(r.metadata))
        if meta isa AbstractDict && get(meta,"origin",nothing) in ("certified_exact_reduction","certified_solution_repair")
            check(nullable(r.submission) in values(pair),"derived origin outside the shared pair")
        end
    end
    check(totals["originals"]==length(originals),"incomplete model audit")
    return Dict("counts"=>totals,"submissions"=>pair,
        "certificate_scope"=>"stored diagnostics and native derived objectives; no independent certificate replay",
        "repair_scope"=>"stored-record consistency; unsuccessful opportunities are not retained")
end

function member_hashes(library)
    return Dict(name=>Dict("bytes"=>filesize(joinpath(library,name)),"sha256"=>U.sha(joinpath(library,name)))
        for name in ("archive.h5","index.db"))
end

function verify_artifact(candidate, receipt)
    library=Q.library_path(candidate);members=member_hashes(library)
    check(Set(readdir(library))==Set(keys(members)),"unexpected artifact members")
    check(receipt["members"]==members,"producer member hashes differ")
    tree=bytes2hex(U.Pkg.GitTools.tree_hash(library))
    check(tree==receipt["artifact_tree"],"artifact Git tree differs")
    archive=joinpath(candidate,"qubolib.tar.gz")
    check(isfile(archive) && !islink(archive),"missing/linked candidate archive")
    check(filesize(archive)==receipt["archive_bytes"] && U.sha(archive)==receipt["archive_sha256"],"candidate archive differs")
    listed=split(chomp(read(`tar -tzf $archive`,String)),'\n')
    normalized=replace.(listed,r"^\./"=>"")
    check(length(listed)==2 && Set(normalized)==Set(keys(members)),"unexpected/duplicate archive members")
    verbose=split(chomp(read(`tar -tvzf $archive`,String)),'\n')
    check(length(verbose)==2 && all(line->startswith(line,"-"),verbose),"archive members must be regular files")
    for (name,canonical) in zip(listed,normalized)
        digest=open(io->bytes2hex(U.SHA.sha256(io)),`tar -xOzf $archive -- $name`,"r")
        check(digest==members[canonical]["sha256"],"archived member differs from the audited library")
    end
    return Dict("members"=>members,"artifact_tree"=>tree,"archive_sha256"=>U.sha(archive),"archive_bytes"=>filesize(archive))
end

function canonical_producer(command, candidate, plan_path, memory_mib; heap_size_hint=nothing)
    check(command isa AbstractVector && all(x->x isa String,command),"producer command must be an argv array")
    check(positive_id(memory_mib),"invalid producer memory reservation")
    julia=realpath(joinpath(Sys.BINDIR,Base.julia_exename()))
    payload=[julia,"--startup-file=no"]
    if !isnothing(heap_size_hint)
        check(heap_size_hint isa String && occursin(r"^[1-9][0-9]*[MG]$",heap_size_hint),"invalid frozen GC heap-size hint")
        hint_mib=parse(BigInt,heap_size_hint[1:end-1])*(endswith(heap_size_hint,"G") ? 1024 : 1)
        check(0<hint_mib<memory_mib,"GC heap-size hint must be below the memory reservation")
        push!(payload,"--heap-size-hint="*heap_size_hint)
    end
    append!(payload,["--project="*dirname(Base.active_project()),
        joinpath(U.REPO,"scripts","build","uniform_candidate.jl"),abspath(plan_path),abspath(candidate)])
    environment=["env","JULIA_PKG_OFFLINE=true","JULIA_DEPOT_PATH="*get(ENV,"JULIA_DEPOT_PATH","")]
    valid_payload(args)=args==payload || args==vcat(environment,payload)
    valid_payload(command) && return true
    check(length(command)>=3 && command[1]=="/usr/bin/python3" &&
        command[2]==joinpath(U.REPO,"scripts","build","measure_command.py"),"unsupported producer executable/prefix")
    separator=findfirst(==("--"),command)
    check(!isnothing(separator) && separator>=9,"invalid measurement wrapper command")
    flags=command[3:separator-1]
    check(iseven(length(flags)),"measurement wrapper requires option/value pairs")
    options=Dict{String,String}();labels=Set{String}()
    for i in 1:2:length(flags)
        key,value=flags[i],flags[i+1]
        check(key in ("--journal","--receipt","--memory-mib","--interval","--stop-grace","--disk-path"),"unknown measurement wrapper option")
        if key=="--disk-path"
            parts=split(value,'=';limit=2)
            check(length(parts)==2 && all(!isempty,parts) && !(parts[1] in labels),"invalid/duplicate measurement disk label")
            push!(labels,parts[1])
        else
            check(!haskey(options,key),"duplicate measurement wrapper option")
            options[key]=value
        end
    end
    check(all(haskey(options,key) for key in ("--journal","--receipt","--memory-mib")),"incomplete measurement wrapper options")
    check(isabspath(options["--journal"]) && isabspath(options["--receipt"]) &&
        normpath(options["--journal"])!=normpath(options["--receipt"]),"invalid measurement output paths")
    check(positive_id(memory_mib) && parse(Int,options["--memory-mib"])==memory_mib,"measurement limit differs from supervisor reservation")
    interval=parse(Float64,get(options,"--interval","1"));grace=parse(Float64,get(options,"--stop-grace","1"))
    check(isfinite(interval) && .05<=interval<=60 && isfinite(grace) && 0<grace<=2,"invalid measurement timing options")
    check(valid_payload(command[separator+1:end]),"measurement wrapper does not invoke the canonical producer")
    return true
end

function producer_terminal(path, candidate, plan_path)
    terminal=U.JSON.parsefile(path)
    check(terminal["state"]=="completed" && terminal["exit_code"]==0 && terminal["primary_exit_code"]==0 && terminal["quiescent"]===true && terminal["allocation_present"]===false,"producer did not complete quiescently")
    run_path=joinpath(dirname(path),"run.json");run=U.JSON.parsefile(run_path)
    for key in ("run_id","nonce","owner","boot_id")
        check(isequal(run[key],terminal[key]),"producer supervisor identity differs")
    end
    frozen=U.TOML.parsefile(plan_path)
    canonical_producer(run["command"],candidate,plan_path,run["memory_mib"];heap_size_hint=get(frozen,"julia_heap_size_hint",nothing))
    return Dict("terminal_sha256"=>U.sha(path),"run_sha256"=>U.sha(run_path),"run_id"=>terminal["run_id"])
end

function audit_candidate(plan_path, candidate, supervisor_terminal, evidence)
    check(isdir(candidate) && !islink(candidate),"candidate must be a real directory")
    check(!ispath(evidence) && !islink(evidence),"audit evidence destination exists")
    check(isdir(dirname(abspath(evidence))),"audit evidence parent must exist")
    target=joinpath(realpath(dirname(abspath(evidence))),basename(evidence))
    relative=relpath(target,realpath(candidate))
    check(relative==".." || startswith(relative,"../") || startswith(relative,"..\\"),"audit evidence must be outside the candidate")
    # mkdir claims the separate audit attempt; failures retain a prefix only.
    mkdir(evidence)
    try
        plan=U.TOML.parsefile(plan_path);identity=U.runtime_identity(plan);tools=tools_identity()
        U.validate_inputs(plan)
        supervisor=producer_terminal(supervisor_terminal,candidate,plan_path)
        check(!ispath(joinpath(candidate,"failure.json")),"failed producer cannot be accepted")
        receipt=U.JSON.parsefile(joinpath(candidate,"terminal.json"))
        check(receipt["schema"]=="qubolib-uniform-candidate-v1" && receipt["state"]=="complete" && receipt["build_commit_status"]=="verified","missing verified full producer receipt")
        check(receipt["identity"]==identity && receipt["build_commit"]==identity["builder"]["commit"] && receipt["counts"]==U.COUNTS,"producer identity/counts differ")
        prepared=U.JSON.parsefile(joinpath(candidate,"run-plan.json"))
        check(prepared["plan"]==plan && prepared["identity"]==identity && prepared["plan_sha256"]==U.sha(plan_path),"producer plan differs")
        original_path=joinpath(candidate,"original-models.json");journal_path=joinpath(candidate,"enrichment.jsonl")
        originals=expected_originals(U.JSON.parsefile(original_path))
        journal=enrichment_journal(journal_path,Set(keys(originals)))
        before=member_hashes(Q.library_path(candidate))
        U.new_json(joinpath(evidence,"audit-start.json"),Dict("schema"=>"qubolib-uniform-output-audit-v1","state"=>"running","identity"=>identity,"producer"=>supervisor,"original_inventory_sha256"=>U.sha(original_path),"producer_journal_sha256"=>U.sha(journal_path)))
        output=joinpath(evidence,"scientific-audit.jsonl")
        summary=open(output,"w") do io
            mktempdir(dirname(abspath(evidence));prefix="qubolib-audit-private-") do scratch
                with_readonly_index(candidate,joinpath(scratch,"sqlite-copy")) do index
                    audit_records(index,originals,journal,identity,r->(println(io,U.JSON.json(r));flush(io)))
                end
            end
        end
        check(before==member_hashes(Q.library_path(candidate)),"read-only audit changed original store bytes")
        artifact=verify_artifact(candidate,receipt)
        check(U.runtime_identity(plan)==identity && tools_identity()==tools,"source/runtime changed during audit");U.validate_inputs(plan)
        check(U.sha(original_path)==U.JSON.parsefile(joinpath(evidence,"audit-start.json"))["original_inventory_sha256"] &&
              U.sha(journal_path)==U.JSON.parsefile(joinpath(evidence,"audit-start.json"))["producer_journal_sha256"],"producer evidence changed during audit")
        accepted=Dict("schema"=>"qubolib-uniform-output-audit-v1","state"=>"complete","full_candidate"=>true,
            "identity"=>identity,"qubotools"=>tools,"producer"=>supervisor,"summary"=>summary,"artifact"=>artifact,
            "original_inventory_sha256"=>U.sha(original_path),"producer_journal_sha256"=>U.sha(journal_path),
            "scientific_audit_sha256"=>U.sha(output),"producer_receipt_sha256"=>U.sha(joinpath(candidate,"terminal.json")),
            "publication"=>"not_published_requires_human_review")
        U.new_json(joinpath(evidence,"accepted.json"),accepted)
        return accepted
    catch error
        U.new_json(joinpath(evidence,"failure.json"),Dict("schema"=>"qubolib-uniform-output-audit-v1","state"=>"failed","full_candidate"=>false,"error"=>sprint(showerror,error)))
        rethrow()
    end
end

function main(args=ARGS)
    length(args)==4 || error("Usage: audit_uniform_candidate.jl PLAN.toml CANDIDATE PRODUCER_SUPERVISOR_TERMINAL.json NEW_AUDIT_DIRECTORY")
    audit_candidate(args...)
end
end # module

if abspath(PROGRAM_FILE)==@__FILE__
    UniformCandidateAudit.main()
end
