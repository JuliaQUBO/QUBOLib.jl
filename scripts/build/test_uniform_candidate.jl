using Test
include("uniform_candidate.jl")
const U = UniformCandidate
const QL = U.QUBOLib
const QT = U.QUBOTools

function toy_model(; domain=:bool, sense=:min)
    QT.Model{Int,Float64,Int}(Set(1:2), Dict(1=>1.0,2=>-2.0), Dict((1,2)=>3.0);
        domain, sense, scale=2.0, offset=7.0)
end
independent_objective(x) = 2*(7+x[1]-2*x[2]+3*x[1]*x[2])

function runtime_plan()
    project=Base.active_project()
    Dict{String,Any}("schema"=>"qubolib-uniform-candidate-v1", "builder_commit"=>U.git(U.REPO,"rev-parse","HEAD"),
        "julia_version"=>string(VERSION), "project_sha256"=>U.sha(project),
        "manifest_sha256"=>U.sha(joinpath(dirname(project),"Manifest.toml")))
end

@testset "streamed repair retains a noncontiguous native Spin core" begin
    survivors=[2,4,5,6,7]
    model=QT.Model(Dict(i=>(i==1 ? 10.0 : i==3 ? -10.0 : 0.0) for i in 1:7),
        Dict((i,j)=>1.0 for i in survivors for j in survivors if i<j);domain=:spin,sense=:min)
    parent=[1,-1,-1,1,-1,1,-1]
    energy(x)=10*x[1]-10*x[3]+sum(x[i]*x[j] for i in survivors for j in survivors if i<j)
    mktempdir() do root
        QL.access(;path=root,clear=true) do index
            QL.add_collection!(index,"fixture",Dict{String,Any}("name"=>"Repair fixtures","author"=>String[]))
            for name in ("partial-a","partial-b")
                id=QL.add_instance!(index,model,"fixture";name)
                QL.add_solution!(index,id,QT.SampleSet{Float64,Int}(model,[parent]);
                    qubo_value=energy(parent),proven_optimal=false,feasibility_status="feasible",
                    validation_status="validated",incumbent_candidate=true)
            end
        end
        journal=IOBuffer();@test U.enrich_streaming!(root;journal)==2
        records=U.JSON.parse.(filter(!isempty,split(String(take!(journal)),'\n')))
        @test [r["repaired_strong_count"] for r in records]==[1,1]
        QL.access(;path=root) do index
            rows=QL.DBInterface.execute(QL.database(index),"SELECT metadata FROM Instances;") |> QL.DataFrame
            @test all(U.JSON.parse(String(r.metadata))["n_strong"]==5 for r in eachrow(rows))
            repairs=QL.DBInterface.execute(QL.database(index),"SELECT * FROM SolutionRecords WHERE source_path LIKE 'QUBOPreprocessing.jl/strong/reconstruct%';") |> QL.DataFrame
            @test size(repairs,1)==2
            @test length(unique(repairs.submission))==1
            for row in eachrow(repairs)
                state=[c=='1' ? 1 : -1 for c in String(row.bitstring)]
                @test state[survivors]==parent[survivors]
                @test state[[1,3]]==[-1,1]
                @test row.qubo_value==energy(state)==energy(parent)-40
                @test row.proven_optimal==0
            end
        end
    end
end

@testset "locked clean runtime acceptance" begin
    identity=U.runtime_identity(runtime_plan())
    @test identity["builder"]["commit"]==U.git(U.REPO,"rev-parse","HEAD")
    @test identity["qubopreprocessing_tree"]==U.QP_TREE
    bad=runtime_plan();bad["manifest_sha256"]=repeat("0",64)
    @test_throws ArgumentError U.runtime_identity(bad)
    mktempdir() do root
        # A valid runtime plus invalid inputs must refuse before creating the
        # destination (and therefore before importer/preprocessor dispatch).
        plan=runtime_plan();plan["archives"]=Dict{String,String}()
        path=joinpath(root,"plan.toml");open(io->U.TOML.print(io,plan),path,"w")
        dest=joinpath(root,"candidate")
        @test_throws ArgumentError U.build_candidate(path,dest)
        @test !ispath(dest)
    end
end

@testset "uniform-candidate preflight refuses unsafe reuse and incomplete inputs" begin
    mktempdir() do root
        @test_throws ArgumentError U.build_candidate("not-read",root)
        @test isempty(readdir(root))
        @test_throws ArgumentError U.runtime_identity(Dict("schema"=>"unknown"))
        @test_throws ArgumentError U.validate_inputs(Dict("archives"=>Dict()))
        bad = joinpath(root,"bad.zip");write(bad,"corrupted source")
        @test_throws ArgumentError U.validate_inputs(Dict("archives"=>Dict(name=>bad for name in keys(U.MIRRORS))))
        @test_throws ArgumentError U.mirror_root(root,["standard.csv","catalog_tier2.csv"])
        write(joinpath(root,"standard.csv"),"graphname\na.zip\n")
        @test_throws ArgumentError U.validate_mqlib_inventory(root)
        for name in ("catalog_tier2.csv","metrics_standard.csv","results_standard.csv")
            write(joinpath(root,name),"graphname\n")
        end
        @test_throws ArgumentError U.validate_mqlib_inventory(root) # missing model cannot be silently skipped
        write(joinpath(root,"a.txt"),"tiny model fixture")
        @test U.validate_mqlib_inventory(root)==1
        @test U.mirror_root(root,["standard.csv","catalog_tier2.csv"])==root
        @test_throws ArgumentError U.clean_source(U.REPO,repeat("0",40))
        @test_throws ArgumentError U._preprocessing_instance_filter(Set([-1]))
        @test_throws ArgumentError U._preprocessing_instance_filter(Set([true]))
    end
end

@testset "native Bool/Spin enrichment streams one input with one shared submission pair" begin
    mktempdir() do root
        ids = Int[]
        before = QL.access(;path=root,clear=true) do index
            QL.add_collection!(index,"fixture",Dict{String,Any}("name"=>"Independent native fixtures","author"=>String[]))
            for (domain,sense,name) in ((:bool,:min,"bool-min"),(:spin,:max,"spin-max"))
                model=toy_model(;domain,sense)
                id=QL.add_instance!(index,model,"fixture";name)
                push!(ids,id)
                state=domain==:bool ? [0,0] : [-1,1]
                sample=QT.SampleSet{Float64,Int}(model,[state])
                QL.add_solution!(index,id,sample;qubo_value=independent_objective(state),
                    proven_optimal=false,feasibility_status="feasible",validation_status="validated",incumbent_candidate=true)
            end
            @test U.validate_inventory(index;expected=Dict("fixture"=>2))==Dict("fixture"=>2)
            @test_throws ArgumentError U.validate_inventory(index)
            @test_throws ArgumentError U.enrich_preprocessing!(index,U.QUBOPreprocessing;instance_ids=Set([999]))
            @test_throws ArgumentError U.enrich_preprocessing!(index,U.QUBOPreprocessing;
                instance_ids=Set([ids[1]]),repair_instance_ids=Set([ids[2]]))
            U.raw_inventory(index)
        end
        journal=IOBuffer()
        @test U.enrich_streaming!(root;journal)==2
        records=U.JSON.parse.(filter(!isempty,split(String(take!(journal)),'\n')))
        @test [r["instance"] for r in records]==ids
        @test [r["exact_count"] for r in records]==[1,1]
        @test [r["repaired_strong_count"] for r in records]==[1,1]
        @test [r["repaired_weak_count"] for r in records]==[0,0]
        QL.access(;path=root) do index
            @test U.raw_inventory(index)==before
            rows=QL.DBInterface.execute(QL.database(index),"SELECT metadata FROM Instances ORDER BY instance;") |> QL.DataFrame
            for row in eachrow(rows)
                meta=U.JSON.parse(String(row.metadata))
                @test !haskey(meta,"preprocessing_runs")
                @test meta["preprocessing"]["provenance"]["result_source"]=="pipeline"
                @test haskey(meta["preprocessing"],"strong_run") && haskey(meta["preprocessing"],"weak_run")
            end
            submissions=QL.DBInterface.execute(QL.database(index),"SELECT count(*) AS n FROM Submissions;") |> QL.DataFrame
            @test submissions[1,:n]==2 # not one pair per instance
            derived=QL.DBInterface.execute(QL.database(index),"SELECT instance,qubo_value,proven_optimal FROM SolutionRecords WHERE proven_optimal=1;") |> QL.DataFrame
            @test size(derived,1)==4 # two exact captures and two improving repairs
            for row in eachrow(derived)
                @test row.instance in ids
                alphabet=row.instance==ids[1] ? (0,1) : (-1,1)
                values=[independent_objective([a,b]) for a in alphabet for b in alphabet]
                @test row.qubo_value==(row.instance==ids[1] ? minimum(values) : maximum(values))
            end
            shared=QL.DBInterface.execute(QL.database(index),"SELECT submission,count(*) AS n FROM SolutionRecords WHERE submission IS NOT NULL GROUP BY submission;") |> QL.DataFrame
            @test sort(Int.(shared.n))==[2,2]
            identity=U.runtime_identity(runtime_plan())
            @test U.audit_enrichment(index,identity;originals=Dict(item["instance"]=>item for item in before))==2
            id=first(ids)
            original=String(rows[1,:metadata])
            for mutate in (m->delete!(m["preprocessing"],"weak_run"),
                m->(m["preprocessing"]["provenance"]["manifest_sha256"]=repeat("0",64)),
                m->(m["preprocessing"]["provenance"]["result_source"]="summary_tsv"),
                m->(m["preprocessing_runs"]=Any[]),
                m->(m["preprocessing"]["input"]["sha256"]=repeat("0",64)))
                changed=U.JSON.parse(original);mutate(changed)
                QL.DBInterface.execute(QL.database(index),"UPDATE Instances SET metadata=? WHERE instance=?;",(U.JSON.json(changed),id))
                @test_throws Exception U.audit_enrichment(index,identity;originals=Dict(item["instance"]=>item for item in before))
            end
            QL.DBInterface.execute(QL.database(index),"UPDATE Instances SET metadata=? WHERE instance=?;",(original,id))
            @test_throws ArgumentError U.require_unenriched(index)
        end
        @test_throws ArgumentError U.enrich_streaming!(root;journal=IOBuffer())
    end
end
