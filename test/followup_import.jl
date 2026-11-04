using Test, JSON, SQLite, HDF5, SHA
import QUBOLib, QUBOTools, QUBOPreprocessing
include(joinpath(@__DIR__,"..","scripts","import_followup_results.jl"))
const FI=FollowupImport
const DBI=QUBOLib.DBInterface
const WITNESS_TOOLS=get(ENV,"FOLLOWUP_WITNESS_TOOLS","")
const WITNESS_SHA=get(ENV,"FOLLOWUP_WITNESS_SHA256","")
isempty(WITNESS_TOOLS) && error("Set FOLLOWUP_WITNESS_TOOLS to the explicitly reviewed library_witnesses.jl")
FI.hexhash(WITNESS_SHA) || error("Set FOLLOWUP_WITNESS_SHA256 to that reviewed file's SHA256")
const PINNED=FI.PinnedWitnessVerifier(WITNESS_TOOLS,WITNESS_SHA)

mutable struct TrackingVerifier <: FI.AbstractWitnessVerifier
    calls::Vector{Any}
    verdict::Symbol
end
FI.verifier_identity(v::TrackingVerifier)=Dict("kind"=>"typed_synthetic_fixture","sha256"=>WITNESS_SHA)
FI.source_hash(v::TrackingVerifier,raw)=FI.source_hash(PINNED,raw)
FI.load_source(v::TrackingVerifier,index,iid)=FI.load_source(PINNED,index,iid)
function FI.verify_evidence(v::TrackingVerifier,path,raw,expected)
    push!(v.calls,(path=path,n=raw.n,source_hash=expected,L=copy(raw.L)))
    result=FI.verify_evidence(PINNED,path,raw,expected)
    v.verdict==:fail && (result["verification"]="failed")
    v.verdict==:unknown && delete!(result,"verification")
    v.verdict==:wrong_source && (result["source_sha256"]=repeat("0",64))
    return result
end

function fixture(path; sense=:min,domain=:bool,scale=1.0,offset=0.0,L=[1.0,2.0])
    mkdir(path)
    dbpath=joinpath(path,"index.db");h5path=joinpath(path,"archive.h5")
    db=QUBOLib.create_database(dbpath);h5=QUBOLib.create_archive(h5path)
    index=QUBOLib.LibraryIndex(db,h5,path)
    model=QUBOTools.Model(Dict(i=>Float64(L[i]) for i in eachindex(L)),Dict((1,2)=>0.5);sense,domain,scale,offset)
    legacy=Dict("preprocessing"=>Dict("strong"=>Dict("n"=>1,"m"=>0)),"n_strong"=>1,"m_strong"=>0,"other"=>"preserve")
    iid=QUBOLib.add_instance!(index,model;name="tiny",metadata=legacy)
    DBI.execute(db,"ALTER TABLE Instances ADD COLUMN n_strong INTEGER")
    DBI.execute(db,"ALTER TABLE Instances ADD COLUMN m_strong INTEGER")
    DBI.execute(db,"UPDATE Instances SET n_strong=1,m_strong=0 WHERE instance=?",(iid,))
    submission=QUBOLib.add_submission!(index;submitter="original fixture")
    parent=QUBOLib.add_solution_record!(index,iid;submission,bitstring="11",source_feasible=true,feasibility_status="feasible")
    raw=FI.source_raw(index,iid)
    close(index)
    return (db=dbpath,h5=h5path,iid=Int(iid),raw=raw,legacy=legacy,parent=Int(parent),submission=Int(submission))
end

function capture(path,f; mode="strong", proof=true, state=[0,0],identityproof=false,task="census",schedule="budgeted")
    mkdir(path);mkdir(joinpath(path,"witnesses"))
    helper=PINNED.helper
    if proof
        encoded=f.raw.domain===:bool ? f.raw : Base.invokelatest(helper.exact_bool_tuple,f.raw)
        model=QUBOTools.Model(Dict(i=>encoded.L[i] for i in 1:encoded.n),encoded.Q;
            sense=encoded.sense,domain=:bool,scale=encoded.scale,offset=encoded.offset)
        ws=QUBOPreprocessing.Workspace(model;rules=:mixed,integerize_scale=true)
        QUBOPreprocessing.schedule_budgeted!(ws;time_limit=1.0,allow_weak=mode=="weak")
        mat=QUBOPreprocessing.materialize(ws;rounding=:nearest)
        @test count(==(2),ws._state.fixed)==0
        saved=Base.invokelatest(helper.write_witness,joinpath(path,"witnesses","state.json");raw=f.raw,mat,residual_state=Int[])
        nr=0;mr=0
    elseif identityproof
        saved=Base.invokelatest(helper.write_witness,joinpath(path,"witnesses","state.json");raw=f.raw,residual_state=state)
        nr=f.raw.n;mr=length(f.raw.Q)
    else
        saved=Base.invokelatest(helper.write_feasible_state,joinpath(path,"witnesses","state.json");raw=f.raw,original_state=state)
        nr=f.raw.n;mr=length(f.raw.Q)
    end
    saved["witness_path"]="witnesses/state.json"
    cfg=Dict("schedule"=>schedule,"integerize-scale"=>true,"prep-seconds"=>5.0,"modes"=>[mode],"task"=>task)
    prov=Dict("runner_commit"=>repeat("a",40),"package_revision"=>repeat("b",40),"package_tree"=>repeat("c",40),
        "source_database_sha256"=>FI.sha(f.db),"source_archive_sha256"=>FI.sha(f.h5),"settings"=>cfg,
        "runner_files_sha256"=>Dict("scripts/library_witnesses.jl"=>WITNESS_SHA))
    plan=Dict("schema_version"=>1,"provenance"=>prov,"instance_ids"=>[f.iid])
    row=merge(Dict{String,Any}("schema_version"=>1,"instance_id"=>f.iid,"collection"=>"standalone","name"=>"tiny",
        "sense"=>String(f.raw.sense),"status"=>"ok","task"=>task,"schedule"=>schedule,"mode"=>mode,"integerize_scale"=>true,
        "source_domain"=>String(f.raw.domain),"state_encoding"=>FI.state_encoding(f.raw.domain),
        "source_sha256"=>FI.source_hash(PINNED,f.raw),"n_orig"=>f.raw.n,"m_orig"=>length(f.raw.Q),"density_orig"=>FI.density(f.raw.n,length(f.raw.Q)),
        "n_res"=>nr,"m_res"=>mr,"density_res"=>FI.density(nr,mr),"zero_residual"=>nr==0,
        "workspace_s"=>0.01,"schedule_s"=>0.02,"materialization_s"=>0.001,"accounting_s"=>0.001,"preprocessing_s"=>0.032,
        "preprocessing_target_s"=>schedule=="budgeted" && mode!="raw" ? 5.0 : nothing,"stop_reason"=>"fixpoint","proof_step_counts"=>Dict("UnaryStep"=>2),
        "input_perturbed"=>false,"input_max_perturbation"=>"0/1","export_perturbed"=>false,"export_max_perturbation"=>"0/1",
        "materialization_status"=>"success","verification"=>Dict("valid"=>true,"status"=>"complete"),
        "predecessor_record"=>f.parent,"predecessor_submission"=>f.submission),saved)
    FI.write_new_json(joinpath(path,"run-plan.json"),plan)
    rewrite_records(path,[row])
    return path,row
end

function rewrite_records(path,rows)
    open(joinpath(path,"records.jsonl"),"w") do io
        for row in rows; println(io,FI.canonical_json(row)); end
    end
    open(joinpath(path,"terminal.json"),"w") do io
        JSON.print(io,Dict("records"=>length(rows),"records_sha256"=>FI.sha(joinpath(path,"records.jsonl")),"outcome"=>"complete"))
    end
end
function stage(root,f,runs; name="staged",verifier=PINNED,hook=(i,item)->nothing,run_id="fixture-run",artifact=repeat("d",40),database_hash=FI.sha(f.db),archive_hash=FI.sha(f.h5))
    return FI.stage_import(;source_database=f.db,source_archive=f.h5,output=joinpath(root,name),runs,
        artifact_tree=artifact,run_id,expected_database_sha256=database_hash,expected_archive_sha256=archive_hash,verifier,expected_instance_count=1,apply_hook=hook)
end
function open_index(path)
    QUBOLib.LibraryIndex(SQLite.DB(joinpath(path,"index.db")),h5open(joinpath(path,"archive.h5"),"r"),path)
end

@testset "Current zero recapture and raw incumbent capture schemas" begin
    mktempdir() do root
        f=fixture(joinpath(root,"source"))
        run,_=capture(joinpath(root,"current"),f;task="zero",schedule="current")
        @test stage(root,f,[run])["exact_global_proofs_added"]==1
        index=open_index(joinpath(root,"staged"))
        try
            meta=JSON.parse(only(FI.query(index.db,"SELECT metadata FROM Instances").metadata))
            entry=only(meta["preprocessing_runs"])
            @test entry["key"]["schedule"]=="current"
            @test entry["key"]["preprocessing_target_s"]===nothing
        finally;close(index);end
    end
    mktempdir() do root
        f=fixture(joinpath(root,"source"))
        run,row=capture(joinpath(root,"raw"),f;task="incumbents",mode="raw",proof=false,identityproof=true,state=[1,0])
        row["heuristic"]="fixture";row["seed"]=1;row["attempt"]=1
        second=deepcopy(row);second["seed"]=2
        rewrite_records(run,[row,second])
        report=stage(root,f,[run])
        @test report["solutions_added"]==2
        @test report["exact_global_proofs_added"]==0
        index=open_index(joinpath(root,"staged"))
        try
            meta=JSON.parse(only(FI.query(index.db,"SELECT metadata FROM Instances").metadata))
            entries=meta["preprocessing_runs"]
            @test length(entries)==2
            @test all(e->e["key"]["preprocessing_target_s"]===nothing,entries)
            @test entries[1]["key_sha256"]!=entries[2]["key_sha256"]
            @test all(e->e["verification"]["global_optimal"]===false,entries)
        finally;close(index);end
    end
end

@testset "Pinned executable verifier and exact source convention" begin
    @test_throws ArgumentError FI.PinnedWitnessVerifier(WITNESS_TOOLS,repeat("0",64))
    @test FI.verifier_identity(PINNED)["sha256"]==WITNESS_SHA
    raw=(n=2,L=[0.1,2.0],Q=Dict((1,2)=>0.5),scale=3.0,offset=1.0,sense=:max,domain=:bool)
    @test FI.exact_objective(raw,[1,0]) == 3*(1+Rational{BigInt}(0.1))
    @test FI.exact_objective(raw,[1,0]) != 33//10
    @test_throws ArgumentError FI.exact_objective(raw,[1,2])
    @test_throws ArgumentError FI.exact_objective(raw,[1])
    @test FI.exact_parse("3/2")==3//2
    for bad in ("1.5","2/2","1/0","+1/1","01/1","-0/1")
        @test_throws ArgumentError FI.exact_parse(bad)
    end
end

@testset "Separate staged metrics and actual HDF5 solutions" begin
    mktempdir() do root
        f=fixture(joinpath(root,"source"));dbsha=FI.sha(f.db);h5sha=FI.sha(f.h5)
        strong,_=capture(joinpath(root,"strong"),f)
        weak,row=capture(joinpath(root,"weak"),f;mode="weak",proof=false,state=[1,0])
        # Backend/result claims are deliberately false. Only replay is authoritative.
        row["global_optimal"]=true;row["proven_optimal"]=true;row["backend_status"]="optimal"
        row["source_feasible"]=true
        rewrite_records(weak,[row])
        chmod(f.db,0o444);chmod(f.h5,0o444)
        tracker=TrackingVerifier(Any[],:pass)
        report=stage(root,f,[strong,weak];verifier=tracker)
        @test report["outcome"]=="staged"
        @test report["preprocessing_records_added"]==2
        @test report["solutions_added"]==2
        @test report["exact_global_proofs_added"]==1
        @test FI.sha(f.db)==dbsha && FI.sha(f.h5)==h5sha
        @test filemode(f.db)&0o777==0o444 && filemode(f.h5)&0o777==0o444
        @test filemode(joinpath(root,"staged","index.db"))&0o777==0o600
        @test filemode(joinpath(root,"staged","archive.h5"))&0o777==0o600
        @test length(tracker.calls)==2
        @test all(c->c.n==2 && c.L==f.raw.L,tracker.calls)
        @test isfile(joinpath(root,"staged","diff-report.json"))
        index=open_index(joinpath(root,"staged"))
        try
            rows=FI.query(index.db,"SELECT metadata,n_strong,m_strong FROM Instances WHERE instance=?",(f.iid,))
            metadata=JSON.parse(only(rows.metadata));history=metadata["preprocessing_runs"]
            for (key,value) in f.legacy; @test metadata[key]==value; end
            @test only(rows.n_strong)==1 && only(rows.m_strong)==0
            @test length(history)==2
            @test history[1]["schema"]==FI.SCHEMA
            @test history[1]["verification"]["global_optimal"]===true
            @test history[1]["verification"]["reduction"]=="independently_replayed"
            @test history[2]["verification"]["global_optimal"]===false
            @test history[2]["verification"]["reduction"]=="reported_only"
            @test history[1]["key"]["preprocessing_target_s"]==5.0
            @test history[1]["source"]["archive_sha256"]==h5sha
            @test history[1]["source"]["database_sha256"]==dbsha
            @test history[1]["normalization"]["integerize_scale"]===true
            @test history[1]["timing_phases_s"]["workspace_s"]==0.01
            solutions=FI.query(index.db,"SELECT solution,optimal FROM Solutions ORDER BY solution")
            @test size(solutions,1)==2
            @test solutions.optimal==[1,0]
            records=FI.query(index.db,"SELECT * FROM SolutionRecords WHERE solution IS NOT NULL ORDER BY solution")
            @test records.proven_optimal==[1,0]
            @test all(ismissing,records.source_feasible)
            @test all(==("feasible"),records.feasibility_status)
            @test all(==("verified"),records.validation_status)
            @test all(!ismissing,records.submission)
            for i in 1:2
                solution=QUBOLib.load_solution(index,f.iid,solutions.solution[i])
                @test QUBOTools.state(solution[1])==(i==1 ? [0,0] : [1,0])
                data=QUBOTools.metadata(solution)
                @test data["original_objective_exact"]==(i==1 ? "0/1" : "1/1")
                @test data["predecessor_record"]==f.parent
                @test data["predecessor_submission"]==f.submission
                @test data["native_source_feasibility"]=="unknown"
                @test data["binary_qubo_feasible"]===true
                @test QUBOTools.value(solution,1)==(i==1 ? 0.0 : 1.0)
            end
            @test QUBOLib.best_solution_record(index,f.iid)[:proven_optimal]==1
        finally;close(index);end
        @test_throws ArgumentError stage(root,f,[strong]) # existing output
        @test_throws ArgumentError stage(root,f,[strong];name="bad_hash",database_hash=repeat("0",64))
        @test !ispath(joinpath(root,"bad_hash"))
        @test_throws ArgumentError stage(joinpath(root,"source"),f,[strong];name="forbidden_in_artifact")
        @test !ispath(joinpath(root,"source","forbidden_in_artifact"))
    end
end

@testset "Reported-only, failed and guarded runs never become certified" begin
    for status in ("ok","error","skipped_capacity_guard","certificate_verification_failed")
        mktempdir() do root
            f=fixture(joinpath(root,"source"));run,row=capture(joinpath(root,"run"),f;proof=false)
            for field in ("witness_path","witness_sha256","original_objective_exact");delete!(row,field);end
            row["status"]=status;row["global_optimal"]=true;row["proven_optimal"]=true
            row["verification"]=Dict("status"=>"complete","valid"=>true)
            if status!="ok"
                delete!(row,"source_sha256");row["error"]="synthetic failure"
            end
            rewrite_records(run,[row]);report=stage(root,f,[run])
            @test report["solutions_added"]==0
            @test report["exact_global_proofs_added"]==0
            index=open_index(joinpath(root,"staged"))
            try
                meta=JSON.parse(only(FI.query(index.db,"SELECT metadata FROM Instances").metadata))
                item=only(meta["preprocessing_runs"])
                @test item["verification"]["global_optimal"]===false
                @test item["verification"]["reduction"]=="reported_only"
                @test item["status"]==status
                @test item["source"]["model_sha256"]==get(row,"source_sha256",nothing)
                @test size(FI.query(index.db,"SELECT * FROM Solutions"),1)==0
            finally;close(index);end
        end
    end
end

@testset "Transactional rollback and identity/proof rejection" begin
    for failure in (:instance_name,:instance_id,:model_hash,:sense,:dimension,:budget,:negative_time,:density,:counts,:vector,:objective,:witness_identity,:proof_residual,
        :witness_hash,:path_escape,:predecessor,:predecessor_submission,:duplicate,:terminal_count,:verifier_fail,:verifier_unknown,:verifier_source,:apply_fault)
        mktempdir() do root
            f=fixture(joinpath(root,"source"));before_db=FI.sha(f.db);before_h5=FI.sha(f.h5)
            first_run,_=capture(joinpath(root,"first"),f;mode="strong",proof=false)
            run,row=capture(joinpath(root,"second"),f;mode="weak",proof=false,identityproof=failure==:proof_residual)
            rows=[row];tracker=TrackingVerifier(Any[],:pass);hook=(i,item)->nothing
            failure==:instance_name && (row["name"]="wrong")
            failure==:instance_id && (row["instance_id"]=f.iid+1)
            failure==:model_hash && (row["source_sha256"]=repeat("0",64))
            failure==:sense && (row["sense"]="max")
            failure==:dimension && (row["n_orig"]=3)
            failure==:budget && (row["preprocessing_target_s"]=4.0)
            failure==:negative_time && (row["preprocessing_s"]=-1.0)
            failure==:density && (row["density_res"]=0.25)
            failure==:counts && (row["proof_step_counts"]=Dict("UnaryStep"=>-1))
            failure==:proof_residual && (row["m_res"]=0;row["density_res"]=0.0)
            if failure in (:vector,:objective,:witness_identity)
                doc=JSON.parsefile(joinpath(run,"witnesses","state.json"))
                if failure==:witness_identity
                    doc["metadata"]=Dict("instance_id"=>999)
                else
                    doc[failure==:vector ? "original_bitstring" : "original_objective_exact"]=failure==:vector ? "02" : "999/1"
                end
                open(joinpath(run,"witnesses","state.json"),"w") do io;JSON.print(io,doc);end
                row["witness_sha256"]=FI.sha(joinpath(run,"witnesses","state.json"))
            end
            failure==:witness_hash && (row["witness_sha256"]=repeat("0",64))
            failure==:path_escape && (row["witness_path"]="../first/witnesses/state.json")
            failure==:predecessor && (row["predecessor_record"]=999)
            failure==:predecessor_submission && (row["predecessor_submission"]=999)
            failure==:duplicate && push!(rows,deepcopy(row))
            failure==:verifier_fail && (tracker.verdict=:fail)
            failure==:verifier_unknown && (tracker.verdict=:unknown)
            failure==:verifier_source && (tracker.verdict=:wrong_source)
            failure==:apply_fault && (hook=(i,item)->i==2 ? error("synthetic after-HDF5 fault") : nothing)
            rewrite_records(run,rows)
            if failure==:terminal_count
                terminal=JSON.parsefile(joinpath(run,"terminal.json"));terminal["records"]=99
                open(joinpath(run,"terminal.json"),"w") do io;JSON.print(io,terminal);end
            end
            @test_throws Exception stage(root,f,[first_run,run];verifier=tracker,hook)
            @test FI.sha(f.db)==before_db && FI.sha(f.h5)==before_h5
            @test isfile(joinpath(root,"staged","failed-import.json"))
            index=open_index(joinpath(root,"staged"))
            try
                @test size(FI.query(index.db,"SELECT * FROM Solutions"),1)==0
                @test size(FI.query(index.db,"SELECT * FROM SolutionRecords"),1)==1
                @test size(FI.query(index.db,"SELECT * FROM Submissions"),1)==1
                @test !QUBOLib.has_solver(index,FI.SOLVER)
                @test isempty(keys(index.h5["solutions"]))
                metadata=JSON.parse(only(FI.query(index.db,"SELECT metadata FROM Instances").metadata))
                @test metadata==f.legacy
            finally;close(index);end
        end
    end
end

@testset "Maximization and explicit complete global inventory" begin
    mktempdir() do root
        f=fixture(joinpath(root,"source");sense=:max)
        run,_=capture(joinpath(root,"run"),f)
        report=stage(root,f,[run])
        @test report["exact_global_proofs_added"]==1
        @test report["distinct_instances"]==1
        index=open_index(joinpath(root,"staged"))
        try
            sol=QUBOLib.load_best_solution(index,f.iid)
            @test QUBOTools.state(sol[1])==[1,1]
            @test QUBOTools.value(sol,1)==3.5
            @test QUBOTools.metadata(sol)["original_objective_exact"]=="7/2"
            @test QUBOTools.metadata(sol)["objective_sense"]=="max"
        finally;close(index);end
        plan=JSON.parsefile(joinpath(run,"run-plan.json"));push!(plan["instance_ids"],999)
        open(joinpath(run,"run-plan.json"),"w") do io;JSON.print(io,plan);end
        @test_throws ArgumentError stage(root,f,[run];name="missing_shard")
        @test !ispath(joinpath(root,"missing_shard"))
    end
end

@testset "Same-key imports rejected; distinct policies retained" begin
    mktempdir() do root
        f=fixture(joinpath(root,"source"));run,_=capture(joinpath(root,"run"),f;proof=false)
        report=stage(root,f,[run])
        staged=(;f...,db=joinpath(root,"staged","index.db"),h5=joinpath(root,"staged","archive.h5"))
        # New capture legitimately refers to the new immutable snapshot, while
        # retaining the same model, runner/package/policy/run identity.
        next,row=capture(joinpath(root,"next"),staged;proof=false)
        @test_throws ArgumentError stage(root,staged,[next];name="duplicate")
        @test stage(root,staged,[next];name="different_run",run_id="fixture-run-2")["preprocessing_records_added"]==1
    end
end

@testset "Native Spin source identity and SampleSet storage" begin
    for sense in (:min,:max)
        mktempdir() do root
            f=fixture(joinpath(root,"source");domain=:spin,sense,scale=3.0,offset=1.0)
            @test f.raw.domain===:spin
            @test f.raw.L==[1.0,2.0]
            @test f.raw.offset==1.0 && f.raw.scale==3.0
            @test FI.native_state(f.raw,[0,1])==[-1,1]
            @test FI.exact_objective(f.raw,[0,0]) == -9//2
            @test FI.exact_objective(f.raw,[1,0]) == -3//2
            @test FI.exact_objective(f.raw,[0,1]) == 9//2
            @test FI.exact_objective(f.raw,[1,1]) == 27//2
            @test_throws ArgumentError FI.native_state(f.raw,[-1,1])
            encoded=Base.invokelatest(PINNED.helper.exact_bool_tuple,f.raw)
            @test FI.source_hash(PINNED,f.raw)!=FI.source_hash(PINNED,encoded)
            for x in ([0,0],[1,0],[0,1],[1,1])
                @test FI.exact_objective(f.raw,x)==FI.exact_objective(encoded,x)
            end
            strong,_=capture(joinpath(root,"strong"),f)
            weak,_=capture(joinpath(root,"weak"),f;mode="weak",proof=false,state=[1,0])
            report=stage(root,f,[strong,weak])
            @test report["solutions_added"]==2
            @test report["exact_global_proofs_added"]==1
            index=open_index(joinpath(root,"staged"))
            try
                rows=FI.query(index.db,"SELECT * FROM SolutionRecords WHERE solution IS NOT NULL ORDER BY solution")
                @test rows.bitstring==(sense===:min ? ["00","10"] : ["11","10"])
                @test rows.proven_optimal==[1,0]
                @test all(ismissing,rows.source_feasible)
                for i in 1:2
                    sol=QUBOLib.load_solution(index,f.iid,rows.solution[i])
                    expected=i==2 ? [1,-1] : sense===:min ? [-1,-1] : [1,1]
                    @test Symbol(QUBOTools.domain(sol))===:spin
                    @test QUBOTools.state(sol[1])==expected
                    @test QUBOTools.value(sol,1)==(i==2 ? -1.5 : sense===:min ? -4.5 : 13.5)
                    @test QUBOTools.value(QUBOLib.load_instance(index,f.iid),expected)==QUBOTools.value(sol,1)
                    metadata=QUBOTools.metadata(sol)
                    @test metadata["stored_domain"]=="spin"
                    @test metadata["encoded_bitstring"]==rows.bitstring[i]
                    @test metadata["state_encoding"]=="binary_x_native_spin_2x_minus_1"
                    @test metadata["stored_qubo_domain_feasible"]===true
                    @test metadata["encoded_boolean_feasible"]===true
                    @test metadata["binary_qubo_feasible"]===nothing
                    @test metadata["native_source_feasibility"]=="unknown"
                end
                metadata=JSON.parse(only(FI.query(index.db,"SELECT metadata FROM Instances").metadata))
                @test all(entry->entry["source"]["domain"]=="spin",metadata["preprocessing_runs"])
            finally;close(index);end
        end
    end
end

@testset "Spin exact objectives avoid floating Boolean-conversion cancellation" begin
    mktempdir() do root
        f=fixture(joinpath(root,"source");domain=:spin,L=[2.0^53,1.0],offset=2.0^53)
        @test f.raw.domain===:spin
        @test f.raw.L==[2.0^53,1.0]
        @test FI.exact_objective(f.raw,[0,0]) == -1//2
        run,_=capture(joinpath(root,"run"),f;proof=false,state=[0,0])
        @test stage(root,f,[run])["exact_global_proofs_added"]==0
        index=open_index(joinpath(root,"staged"))
        try
            sol=QUBOLib.load_best_solution(index,f.iid)
            @test Symbol(QUBOTools.domain(sol))===:spin
            @test QUBOTools.state(sol[1])==[-1,-1]
            @test QUBOTools.value(sol,1)==-0.5
            @test QUBOTools.metadata(sol)["original_objective_exact"]=="-1/2"
        finally;close(index);end
    end
end

@testset "Spin domain/encoding mismatches are rejected" begin
    for field in ("source_domain","state_encoding")
        mktempdir() do root
            f=fixture(joinpath(root,"source");domain=:spin)
            run,row=capture(joinpath(root,"run"),f;proof=false)
            row[field]=field=="source_domain" ? "bool" : "binary_native_bool"
            rewrite_records(run,[row])
            @test_throws ArgumentError stage(root,f,[run])
            @test isfile(joinpath(root,"staged","failed-import.json"))
            @test FI.sha(f.db)==JSON.parsefile(joinpath(root,"staged","failed-import.json"))["source_database_sha256"]
        end
    end
end

@testset "Identical native models retain distinct catalogue instance identities" begin
    for domain in (:bool,:spin)
        mktempdir() do root
            f=fixture(joinpath(root,"source");domain)
            index=QUBOLib.LibraryIndex(SQLite.DB(f.db),h5open(f.h5,"r+"),dirname(f.db))
            alias=try
                iid=QUBOLib.add_instance!(index,QUBOLib.load_instance(index,f.iid);name="tiny",metadata=f.legacy)
                parent=QUBOLib.add_solution_record!(index,iid;submission=f.submission,bitstring="11",feasibility_status="feasible")
                (;f...,iid=Int(iid),parent=Int(parent),raw=FI.load_source(PINNED,index,Int(iid)))
            finally;close(index);end
            @test alias.iid!=f.iid
            @test FI.source_hash(PINNED,f.raw)==FI.source_hash(PINNED,alias.raw)
            first,_=capture(joinpath(root,"first"),f)
            second,_=capture(joinpath(root,"second"),alias)
            dbsha=FI.sha(f.db);h5sha=FI.sha(f.h5)
            stage_aliases(name,runs)=FI.stage_import(;source_database=f.db,source_archive=f.h5,output=joinpath(root,name),runs,
                artifact_tree=repeat("d",40),run_id="same-alias-run",expected_database_sha256=dbsha,
                expected_archive_sha256=h5sha,verifier=PINNED,expected_instance_count=2)
            report=stage_aliases("both",[first,second])
            @test report["distinct_instances"]==2
            @test report["preprocessing_records_added"]==2
            @test report["solutions_added"]==2
            @test report["exact_global_proofs_added"]==2
            index=open_index(joinpath(root,"both"))
            try
                rows=FI.query(index.db,"SELECT instance,metadata FROM Instances ORDER BY instance")
                entries=[only(JSON.parse(row.metadata)["preprocessing_runs"]) for row in eachrow(rows)]
                @test [entry["key"]["instance_id"] for entry in entries]==[f.iid,alias.iid]
                @test entries[1]["key"]["source_sha256"]==entries[2]["key"]["source_sha256"]
                @test entries[1]["key_sha256"]!=entries[2]["key_sha256"]
                solutions=FI.query(index.db,"SELECT instance,solution,proven_optimal,metadata FROM SolutionRecords WHERE solution IS NOT NULL ORDER BY instance")
                @test solutions.instance==[f.iid,alias.iid]
                @test solutions.proven_optimal==[1,1]
                for (i,iid) in enumerate((f.iid,alias.iid))
                    sol=QUBOLib.load_solution(index,iid,solutions.solution[i])
                    @test Symbol(QUBOTools.domain(sol))===domain
                    @test QUBOTools.state(sol[1])==(domain===:spin ? [-1,-1] : [0,0])
                    @test QUBOTools.metadata(sol)["source"]["instance_id"]==iid
                    @test JSON.parse(solutions.metadata[i])["predecessor_record"]==(i==1 ? f.parent : alias.parent)
                end
            finally;close(index);end
            # A repeat of either catalogue instance still invalidates the whole
            # import, including the already inserted distinct alias.
            @test_throws ArgumentError stage_aliases("duplicate",[first,second,first])
            @test isfile(joinpath(root,"duplicate","failed-import.json"))
            index=open_index(joinpath(root,"duplicate"))
            try
                @test isempty(FI.query(index.db,"SELECT * FROM Solutions").solution)
                @test isempty(keys(index.h5["solutions"]))
                @test all(value->!haskey(JSON.parse(value),"preprocessing_runs"),FI.query(index.db,"SELECT metadata FROM Instances").metadata)
            finally;close(index);end
            @test FI.sha(f.db)==dbsha && FI.sha(f.h5)==h5sha
        end
    end
end
