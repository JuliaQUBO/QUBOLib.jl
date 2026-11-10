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

@testset "import-cache advice is explicit and fails closed" begin
    @test isnothing(U.import_cache_backend(Dict()))
    @test isnothing(U.import_cache_backend(Dict("advise_import_cache"=>false,
        "import_cache_python"=>"missing-optional-python")))
    @test isnothing(U.advise_import_cache!("never-opened",nothing))
    @test U.cache_advice_destination("relative/",nothing)=="relative/"
    for value in ("true", 1, nothing)
        @test_throws ArgumentError U.import_cache_backend(Dict("advise_import_cache"=>value))
    end
    mktempdir() do root
        # Exercise the actual builder preflight with a malformed option; no
        # runtime/input validation or import may claim/create the destination.
        path=joinpath(root,"plan.toml")
        write(path,"advise_import_cache = \"true\"\n")
        dest=joinpath(root,"candidate")
        @test_throws ArgumentError U.build_candidate(path,dest)
        @test !ispath(dest)
    end
    if Sys.islinux()
        @test_throws ArgumentError U.import_cache_backend(Dict("advise_import_cache"=>true,
            "import_cache_python"=>"missing-import-cache-python"))
        # Exit zero without backend JSON is not success.
        @test_throws Exception U.import_cache_backend(Dict("advise_import_cache"=>true,
            "import_cache_python"=>"/bin/true"))
        backend=U.import_cache_backend(Dict("advise_import_cache"=>true))
        @test backend["backend"]=="POSIX_FADV_DONTNEED"
        mktempdir() do root
            target=joinpath(root,"candidate")
            @test U.cache_advice_destination(target*"/",backend)==target
            cd(root) do
                @test U.cache_advice_destination("candidate/",backend)==target
            end
            real=joinpath(root,"real");mkdir(real)
            alias=joinpath(root,"alias");symlink(real,alias)
            linked=joinpath(alias,"candidate")
            @test_throws ArgumentError U.cache_advice_destination(linked,backend)
            # A bad parent must be rejected before runtime/input validation;
            # no real mirrors or complete-corpus fixture is needed here.
            plan=joinpath(root,"enabled.toml");write(plan,"advise_import_cache = true\n")
            @test_throws ArgumentError U.build_candidate(plan,linked)
            @test !ispath(linked)
        end
        function cache_fixture_context(root)
            U.new_json(joinpath(root,"run-plan.json"),Dict("state"=>"prepared",
                "plan"=>Dict("schema"=>"qubolib-uniform-candidate-v1","advise_import_cache"=>true),
                "import_cache_backend"=>backend))
            U.new_json(joinpath(root,"original-models.json"),[Dict("fixture_only"=>true)])
        end
        mktempdir() do root
            for name in ("dist/cache/mirror.zip","sources/model.txt")
                path=joinpath(root,name);mkpath(dirname(path));write(path,"private import fixture")
            end
            native=joinpath(QL.library_path(root),"archive.h5")
            mkpath(dirname(native));write(native,"native library fixture")
            cache_fixture_context(root)
            before=U.sha(native)
            fake=copy(backend);fake["python_executable"]="/bin/true"
            @test_throws Exception U.advise_import_cache!(root,fake)
            receipt=U.advise_import_cache!(root,backend)
            @test receipt["file_count"]==2
            @test isnothing(receipt["actual_resident_bytes_released"])
            @test receipt["run_plan_sha256"]==U.sha(joinpath(root,"run-plan.json"))
            @test receipt["original_models_sha256"]==U.sha(joinpath(root,"original-models.json"))
            @test U.sha(native)==before
            @test_throws Exception U.advise_import_cache!(root,backend) # retain prior receipt
        end
        mktempdir() do root
            mkpath(joinpath(root,"dist/cache"));mkpath(joinpath(root,"sources"))
            write(joinpath(root,"dist/cache/mirror.zip"),"private fixture")
            outside=joinpath(root,"outside.txt");write(outside,"shared source")
            symlink(outside,joinpath(root,"sources/linked.txt"))
            cache_fixture_context(root)
            @test_throws Exception U.advise_import_cache!(root,backend)
            @test !ispath(joinpath(root,"terminal.json"))
        end
    end
end

@testset "uniform CLI dispatches before legacy working-directory build" begin
    script=joinpath(@__DIR__,"uniform_candidate.jl")
    project=dirname(Base.active_project())
    function cli(root,args)
        output,errors=IOBuffer(),IOBuffer()
        command=`$(Base.julia_cmd()) --startup-file=no --threads=1 --project=$project $script $args`
        process=run(pipeline(ignorestatus(Cmd(command;dir=root)),stdout=output,stderr=errors))
        return success(process),String(take!(output)),String(take!(errors))
    end
    mktempdir() do root
        # Keep this regression safe on the broken revision: its legacy main
        # sees cached empty collections and returns without fetching inputs.
        QL.access(;path=root,clear=true) do index
            for code in keys(U.COUNTS)
                QL.add_collection!(index,code,Dict{String,Any}("name"=>code,"author"=>String[]))
            end
            @test all(QL.has_collection(index,code) for code in keys(U.COUNTS))
            rows=QL.DBInterface.execute(QL.database(index),"SELECT count(*) AS n FROM Instances;") |> QL.DataFrame
            @test rows[1,:n]==0
        end
        members=Dict(name=>U.sha(joinpath(QL.library_path(root),name)) for name in ("archive.h5","index.db"))
        succeeded,output,errors=cli(root,String[])
        @test !succeeded
        @test occursin("Usage: uniform_candidate.jl",errors)
        @test !occursin("Building QUBOLib",errors)
        @test members==Dict(name=>U.sha(joinpath(QL.library_path(root),name)) for name in keys(members))
        # Do not run the legacy CLI in an empty directory if dispatch regresses.
        if !succeeded && occursin("Usage: uniform_candidate.jl",errors)
            mktempdir() do empty_root
                missing=joinpath(empty_root,"entrypoint-test-missing.toml")
                destination=joinpath(empty_root,"candidate")
                succeeded,output,errors=cli(empty_root,[missing,destination])
                @test !succeeded
                @test occursin("entrypoint-test-missing.toml",errors)
                @test !occursin("Building QUBOLib",errors)
                @test !ispath(destination)
                @test !ispath(QL.library_path(empty_root))
                @test isempty(readdir(empty_root))
                invalid=joinpath(empty_root,"invalid-option.toml")
                write(invalid,"advise_import_cache = \"true\"\n")
                succeeded,output,errors=cli(empty_root,[invalid,destination])
                @test !succeeded
                @test occursin("advise_import_cache must be a Boolean",errors)
                @test !ispath(destination)
                @test !ispath(QL.library_path(empty_root))
                if Sys.islinux()
                    enabled=joinpath(empty_root,"enabled.toml")
                    write(enabled,"advise_import_cache = true\n")
                    real=joinpath(empty_root,"real");mkdir(real)
                    alias=joinpath(empty_root,"alias");symlink(real,alias)
                    linked=joinpath(alias,"candidate")
                    succeeded,output,errors=cli(empty_root,[enabled,linked])
                    @test !succeeded
                    @test occursin("symlink-free parent",errors)
                    @test !ispath(linked)
                end
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

@testset "pinned MINLPLib mirror preserves required and optional point inventory" begin
    # The real pinned mirror has all 29 models and 42 solutions, while source
    # metadata also lists 26 historical intermediate points absent from it.
    @test length(U.minlplib_mirror_required_files())==71
    @test count(name->endswith(name,".sol"),U.minlplib_mirror_required_files())==42
    mktempdir() do root
        instances=[(name="example",best_point="p3",points=["p3","p2","p1"])]
        required=U.minlplib_mirror_required_files(instances)
        @test required==["example.p1.sol","example.p3.sol","example.pip"]
        for name in required;write(joinpath(root,name),"fixture");end
        @test U.mirror_root(root,required)==root
        inventory=U.minlplib_mirror_inventory(root;instances)
        @test inventory["models"]==1
        @test inventory["mirrored_solution_files"]==["example.p1.sol","example.p3.sol"]
        @test inventory["missing_optional_solution_files"]==["example.p2.sol"]
        for name in required
            mv(joinpath(root,name),joinpath(root,"held"))
            @test_throws ArgumentError U.minlplib_mirror_inventory(root;instances)
            mv(joinpath(root,"held"),joinpath(root,name))
        end
        write(joinpath(root,"example.p2.sol"),"fixture")
        full_inventory=U.minlplib_mirror_inventory(root;instances)
        @test full_inventory["mirrored_solution_files"]==["example.p1.sol","example.p2.sol","example.p3.sol"]
        @test isempty(full_inventory["missing_optional_solution_files"])
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
