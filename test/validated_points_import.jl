using Test, SHA, JSON, SQLite, HDF5
import QUBOLib, QUBOTools
include(joinpath(@__DIR__, "..", "scripts", "import_validated_points.jl"))
const PI = ValidatedPointImport
const FI = PI.FI
const DBI = QUBOLib.DBInterface
const HELPER_PATH = get(ENV, "FOLLOWUP_WITNESS_TOOLS", "")
const HELPER_HASH = get(ENV, "FOLLOWUP_WITNESS_SHA256", "")
isempty(HELPER_PATH) && error("Set FOLLOWUP_WITNESS_TOOLS to the reviewed native source helper")
const PINNED = FI.PinnedWitnessVerifier(HELPER_PATH, HELPER_HASH)

table_snapshot(index) = Dict(table => [Tuple(r) for r in eachrow(FI.query(index.db,"SELECT * FROM $table"))]
    for table in ("Collections","Instances","Solutions","Solvers","Submissions","SolutionRecords"))

function point_fixture(root; domain=:bool, sense=:max)
    parent = joinpath(root, "parent"); mkdir(parent)
    dbpath = joinpath(parent, "index.db"); h5path = joinpath(parent, "archive.h5")
    index = QUBOLib.LibraryIndex(QUBOLib.create_database(dbpath), QUBOLib.create_archive(h5path), parent)
    raw = Any[]; ids = Int[]; metadata = String[]
    for i in 1:2
        model = QUBOTools.Model(Dict(1=>0.1, 2=>-0.3), Dict((1,2)=>0.5); sense, domain, scale=3.0, offset=1.0)
        legacy = Dict("preprocessing"=>Dict("strong"=>Dict("n"=>2)),
            "preprocessing_runs"=>[Dict("prior"=>"preserve exactly", "mode"=>"weak")], "other"=>i)
        iid = Int(QUBOLib.add_instance!(index, model; name="tiny-$i", metadata=legacy))
        push!(ids, iid); push!(raw, FI.load_source(PINNED,index,iid))
        push!(metadata, only(FI.query(index.db,"SELECT metadata FROM Instances WHERE instance=?",(iid,)).metadata))
    end
    QUBOLib.add_solver!(index, "fixture", Dict())
    old_sample = QUBOTools.Sample{Float64,Int}(FI.native_state(first(raw),[0,0]), Float64(FI.exact_objective(first(raw),[0,0])), 1)
    old_sol = QUBOTools.SampleSet{Float64,Int}([old_sample],Dict{String,Any}("solver"=>"fixture","status"=>"feasible");sense,domain)
    QUBOLib.add_solution!(index, first(ids), old_sol;proven_optimal=false,source_feasible=nothing)
    before_records = [Tuple(r) for r in eachrow(FI.query(index.db,"SELECT * FROM SolutionRecords"))]
    before_tables = table_snapshot(index)
    groups = Set(String.(keys(index.h5["solutions"])))
    close(index)
    evidence=joinpath(root,"evidence");mkdir(evidence);mkdir(joinpath(evidence,"states"))
    points=Any[]
    for (i,iid) in enumerate(ids)
        text=i==1 ? "10" : "01";path="states/$iid.bits"
        write(joinpath(evidence,path),text*"\n")
        push!(points,Dict{String,Any}("instance_id"=>iid,"collection"=>"standalone","name"=>"tiny-$i",
            "domain"=>String(domain),"sense"=>String(sense),"state_encoding"=>FI.state_encoding(domain),
            "state_path"=>path,"state_file_sha256"=>FI.sha(joinpath(evidence,path)),
            "state_sha256"=>bytes2hex(sha256(text)),"native_source_sha256"=>FI.source_hash(PINNED,raw[i]),
            "original_objective_exact"=>FI.exact_string(FI.exact_objective(raw[i],Int[c=='1' for c in text])),
            "global_optimal"=>false,"native_source_feasibility"=>"unknown","provenance"=>Dict("fixture"=>true)))
    end
    bundle=Dict{String,Any}("schema"=>PI.SCHEMA,"import_id"=>"fixture-points", "points"=>points,
        "parent_snapshot"=>Dict("database_sha256"=>FI.sha(dbpath),"archive_sha256"=>FI.sha(h5path)),
        "ancestor_snapshot"=>Dict("artifact_tree"=>repeat("a",40),"database_sha256"=>repeat("b",64),"archive_sha256"=>repeat("c",64)),
        "provenance"=>Dict("fixture"=>true))
    path=joinpath(evidence,"points.json");FI.write_new_json(path,bundle)
    return (db=dbpath,h5=h5path,ids=ids,raw=raw,metadata=metadata,groups=groups,
            before_records=before_records,before_tables=before_tables,bundle=bundle,path=path,root=root)
end

function rewrite_bundle(f)
    open(f.path,"w") do io;println(io,FI.canonical_json(f.bundle));end
end
function import_fixture(f;name="staged",kwargs...)
    PI.stage_points(;source_database=f.db,source_archive=f.h5,
        expected_database_sha256=FI.sha(f.db),expected_archive_sha256=FI.sha(f.h5),
        bundle_path=f.path,expected_bundle_sha256=FI.sha(f.path),output=joinpath(f.root,name),verifier=PINNED,kwargs...)
end
function read_index(path)
    QUBOLib.LibraryIndex(SQLite.DB(joinpath(path,"index.db")),h5open(joinpath(path,"archive.h5"),"r"),path)
end

@testset "Native Bool/Spin feasible points preserve prior catalogue" begin
    for domain in (:bool,:spin),sense in (:min,:max)
        mktempdir() do root
            f=point_fixture(root;domain,sense);old_db=FI.sha(f.db);old_h5=FI.sha(f.h5)
            report=import_fixture(f)
            @test report["solutions_added"]==2
            @test report["distinct_instances"]==2
            @test report["exact_global_proofs_added"]==0
            @test report["preprocessing_records_added"]==0
            @test report["native_source_feasibility"]=="unknown"
            @test report["verifier"]["sha256"]==HELPER_HASH
            @test (FI.sha(f.db),FI.sha(f.h5))==(old_db,old_h5)
            index=read_index(joinpath(root,"staged"))
            try
                @test collect(FI.query(index.db,"SELECT metadata FROM Instances ORDER BY instance").metadata)==f.metadata
                prior=[Tuple(r) for r in eachrow(FI.query(index.db,"SELECT * FROM SolutionRecords WHERE record<=?",(length(f.before_records),)))]
                @test isequal(prior,f.before_records)
                for (table,oldrows) in f.before_tables
                    newrows=table_snapshot(index)[table]
                    @test all(old -> any(new -> isequal(old,new),newrows),oldrows)
                end
                @test f.groups ⊆ Set(String.(keys(index.h5["solutions"])))
                rows=FI.query(index.db,"SELECT * FROM SolutionRecords WHERE record>? ORDER BY record",(length(f.before_records),))
                @test all(==(false),rows.proven_optimal)
                @test all(ismissing,rows.source_feasible)
                @test all(ismissing,rows.source_value)
                @test all(ismissing,rows.source_objective)
                @test all(==("verified"),rows.validation_status)
                for (i,row) in enumerate(eachrow(rows))
                    meta=JSON.parse(row.metadata)
                    @test meta["global_optimal"]===false
                    @test meta["native_source_feasibility"]=="unknown"
                    @test meta["original_objective_exact"]==f.bundle["points"][i]["original_objective_exact"]
                    @test row.bitstring==(i==1 ? "10" : "01")
                    sol=QUBOLib.load_solution(index,Int(row.solution))
                    @test QUBOTools.state(sol,1)==FI.native_state(f.raw[i],i==1 ? [1,0] : [0,1])
                    @test Symbol(QUBOTools.domain(sol))==domain
                end
            finally;close(index);end
            @test_throws ArgumentError import_fixture(f)
        end
    end
end

@testset "Point input identities and authoritative scope cannot be forged" begin
    for (field,value) in (("global_optimal",true),("native_source_feasibility","verified"),
                          ("native_source_sha256",repeat("0",64)),("state_sha256",repeat("0",64)),
                          ("state_file_sha256",repeat("0",64)),("original_objective_exact","1/1"),
                          ("original_objective_exact","2/2"),("domain","spin"),("state_encoding","wrong"),
                          ("collection","wrong"),("name","wrong"),("sense","min"))
        mktempdir() do root
            f=point_fixture(root);f.bundle["points"][1][field]=value;rewrite_bundle(f)
            @test_throws ArgumentError import_fixture(f)
            @test FI.sha(f.db)==f.bundle["parent_snapshot"]["database_sha256"]
            @test FI.sha(f.h5)==f.bundle["parent_snapshot"]["archive_sha256"]
        end
    end
    mktempdir() do root
        f=point_fixture(root);f.bundle["points"][2]["instance_id"]=first(f.ids);rewrite_bundle(f)
        @test_throws ArgumentError import_fixture(f)
        @test !ispath(joinpath(root,"staged"))
    end
    mktempdir() do root
        f=point_fixture(root);f.bundle["points"][1]["state_path"]="../parent/index.db";rewrite_bundle(f)
        @test_throws ArgumentError import_fixture(f)
        @test !ispath(joinpath(root,"staged"))
    end
    mktempdir() do root
        f=point_fixture(root);f.bundle["parent_snapshot"]["database_sha256"]=repeat("0",64);rewrite_bundle(f)
        @test_throws ArgumentError import_fixture(f)
        @test !ispath(joinpath(root,"staged"))
    end
end

@testset "Fresh copies, external hash pins and rollback" begin
    mktempdir() do root
        f=point_fixture(root)
        @test_throws ArgumentError PI.load_bundle(f.path,repeat("0",64),FI.sha(f.db),FI.sha(f.h5))
        @test_throws ArgumentError PI.stage_points(;source_database=f.db,source_archive=f.h5,
            expected_database_sha256=FI.sha(f.db),expected_archive_sha256=FI.sha(f.h5),
            bundle_path=f.path,expected_bundle_sha256=FI.sha(f.path),output=joinpath(dirname(f.db),"inside"),verifier=PINNED)
        @test !ispath(joinpath(dirname(f.db),"inside"))
        f.bundle["points"][2]["original_objective_exact"]="1/1";rewrite_bundle(f)
        @test_throws ArgumentError import_fixture(f)
        failed=JSON.parsefile(joinpath(root,"staged","failed-import.json"))
        @test failed["outcome"]=="failed_rolled_back"
        index=read_index(joinpath(root,"staged"))
        try
            @test isequal(table_snapshot(index),f.before_tables)
            @test Set(String.(keys(index.h5["solutions"])))==f.groups
            @test collect(FI.query(index.db,"SELECT metadata FROM Instances ORDER BY instance").metadata)==f.metadata
        finally;close(index);end
    end
    mktempdir() do root
        f=point_fixture(root)
        @test_throws ErrorException import_fixture(f;apply_hook=(i,item)->error("fixture interrupted after insertion"))
        @test JSON.parsefile(joinpath(root,"staged","failed-import.json"))["staged_copy_not_publishable"]===true
    end
end
