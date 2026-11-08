using Test
include("audit_uniform_candidate.jl")
const A = UniformCandidateAudit
const U = A.U
const Q = A.Q
const T = A.T

function runtime_plan()
    project=Base.active_project()
    Dict("schema"=>"qubolib-uniform-candidate-v1","builder_commit"=>U.git(U.REPO,"rev-parse","HEAD"),
        "julia_version"=>string(VERSION),"project_sha256"=>U.sha(project),
        "manifest_sha256"=>U.sha(joinpath(dirname(project),"Manifest.toml")))
end

function toy_model(domain,sense)
    T.Model{Int,Float64,Int}(Set(1:2),Dict(1=>1.0,2=>-2.0),Dict((1,2)=>3.0);
        domain,sense,scale=2.0,offset=7.0)
end

@testset "complete inventory and journal refuse ambiguous coverage" begin
    mktempdir() do directory
        original=merge(Dict("instance"=>1,"collection"=>"fixture","name"=>"a"),U._qubopreprocessing_model_identity(toy_model(:bool,:min)))
        values=[original,merge(original,Dict("instance"=>2,"name"=>"b"))]
        @test length(A.expected_originals(values;counts=Dict("fixture"=>2)))==2
        @test_throws ArgumentError A.expected_originals(values)
        for mutate in (v->(v[2]["instance"]=1),v->(v[2]["name"]="a"),v->(v[1]["instance"]=true),v->(v[1]["sha256"]="bad"))
            bad=deepcopy(values);mutate(bad)
            @test_throws ArgumentError A.expected_originals(bad;counts=Dict("fixture"=>2))
        end
        journal=joinpath(directory,"journal.jsonl")
        rows=[Dict("instance"=>i,"status"=>"enriched","exact_count"=>0,"repaired_strong_count"=>0,"repaired_weak_count"=>0) for i in 1:2]
        save(v)=write(journal,join(U.JSON.json.(v),'\n')*"\n")
        save(rows);@test length(A.enrichment_journal(journal,Set([1,2])))==2
        for bad in ([rows[1]],reverse(rows),[rows[1],rows[1]],vcat(rows,[merge(rows[1],Dict("instance"=>3))]),[merge(rows[1],Dict("exact_count"=>true)),rows[2]],[merge(rows[1],Dict("repaired_weak_count"=>-1)),rows[2]])
            save(bad);@test_throws ArgumentError A.enrichment_journal(journal,Set([1,2]))
        end
        write(journal,U.JSON.json(rows[1]));@test_throws ArgumentError A.enrichment_journal(journal,Set([1,2]))
        write(journal,"{\n");@test_throws Exception A.enrichment_journal(journal,Set([1,2]))
    end
end

@testset "native stored outputs and corruption guards" begin
    mktempdir() do directory
        candidate=joinpath(directory,"candidate")
        originals=Q.access(;path=candidate,clear=true) do index
            Q.add_collection!(index,"fixture",Dict{String,Any}("name"=>"Native audit fixtures","author"=>String[]))
            for (domain,sense,name,state) in ((:bool,:min,"bool-min",[0,0]),(:spin,:max,"spin-max",[-1,1]))
                model=toy_model(domain,sense);id=Q.add_instance!(index,model,"fixture";name)
                Q.add_solution!(index,id,T.SampleSet{Float64,Int}(model,[state]);proven_optimal=false,
                    qubo_value=Float64(T.value(model,state)),validation_status="validated",feasibility_status="feasible",incumbent_candidate=true)
            end
            U.raw_inventory(index)
        end
        journal_path=joinpath(directory,"enrichment.jsonl")
        open(journal_path,"w") do io;@test U.enrich_streaming!(candidate;journal=io)==2;end
        expected=A.expected_originals(originals;counts=Dict("fixture"=>2))
        journal=A.enrichment_journal(journal_path,Set(keys(expected)))
        identity=U.runtime_identity(runtime_plan());serial=Ref(0)
        @test A.tools_identity()["tree"]==A.QT_TREE
        function audit()
            serial[]+=1;reports=Any[];before=A.member_hashes(Q.library_path(candidate))
            result=A.with_readonly_index(candidate,joinpath(directory,"copy-$(serial[])")) do index
                A.audit_records(index,expected,journal,identity,r->push!(reports,r);counts=Dict("fixture"=>2))
            end
            @test before==A.member_hashes(Q.library_path(candidate))
            return result,reports
        end
        result,reports=audit()
        @test result["counts"]==Dict("originals"=>2,"exact"=>2,"repair_strong"=>2,"repair_weak"=>0)
        @test all(length(r["derived_records"])==2 for r in reports)
        @test all(d["source_objective"]===nothing && d["source_feasible"]===nothing for r in reports for d in r["derived_records"])
        @test all(d["source_evaluation_status"]=="no_stored_source_formulation" for r in reports for d in r["derived_records"])
        id=first(originals)["instance"]
        original_meta=Q.access(index->String(only(eachrow(A.rows(index,"SELECT metadata FROM Instances WHERE instance=?;",(id,)))).metadata);path=candidate)
        function metadata!(value)
            Q.access(;path=candidate) do index
                Q.DBInterface.execute(Q.database(index),"UPDATE Instances SET metadata=? WHERE instance=?;",(U.JSON.json(value),id))
            end
        end
        for mutate in (m->(m["preprocessing"]["input"]["sha256"]=repeat("0",64)),
                       m->(m["preprocessing"]["provenance"]["pipeline_source_sha256"]=repeat("0",64)),
                       m->(m["preprocessing"]["weak_run"]["policy"]["preparation_target_s"]=1.0),
                       m->(m["preprocessing"]["strong_run"]["normalization"]["export_perturbed"]=1),
                       m->(m["preprocessing_runs"]=Any[]))
            changed=U.JSON.parse(original_meta);mutate(changed);metadata!(changed)
            @test_throws ArgumentError audit()
        end
        metadata!(U.JSON.parse(original_meta));audit()
        Q.access(;path=candidate) do index
            Q.DBInterface.execute(Q.database(index),"UPDATE Instances SET name='changed' WHERE instance=?;",(id,))
        end
        @test_throws ArgumentError audit()
        Q.access(;path=candidate) do index
            Q.DBInterface.execute(Q.database(index),"UPDATE Instances SET name=? WHERE instance=?;",(first(originals)["name"],id))
        end
        derived=Q.access(index->A.rows(index,"SELECT * FROM SolutionRecords WHERE submission IS NOT NULL AND instance=? ORDER BY record;",(id,));path=candidate)
        exact=first(eachrow(derived));repair=last(eachrow(derived))
        Q.access(;path=candidate) do index
            Q.DBInterface.execute(Q.database(index),"UPDATE SolutionRecords SET qubo_value=qubo_value+1 WHERE record=?;",(Int(exact.record),))
        end
        @test_throws ArgumentError audit()
        Q.access(;path=candidate) do index
            Q.DBInterface.execute(Q.database(index),"UPDATE SolutionRecords SET qubo_value=? WHERE record=?;",(exact.qubo_value,Int(exact.record)))
        end
        function solution_metadata!(row,metadata)
            Q.access(;path=candidate) do index
                sol=Q.load_solution(index,Int(row.instance),Int(row.solution))
                empty!(T.metadata(sol));merge!(T.metadata(sol),deepcopy(metadata))
                parent=Q.archive(index)["solutions"];Q.HDF5.delete_object(parent,string(row.solution))
                group=Q.HDF5.create_group(parent,string(row.solution));Q._write_solution(group,sol,Q._qubin_format())
                Q.DBInterface.execute(Q.database(index),"UPDATE SolutionRecords SET metadata=? WHERE record=?;",(U.JSON.json(metadata),Int(row.record)))
            end
        end
        repair_meta=U.JSON.parse(String(repair.metadata))
        other_parent=Q.access(index->only(eachrow(A.rows(index,"SELECT record FROM SolutionRecords WHERE instance!=? AND submission IS NULL LIMIT 1;",(id,)))).record;path=candidate)
        for mutate in (m->(m["hamming_distance"]+=1),m->(m["qubo_improvement"]+=1),m->(m["parent_record"]=Int(other_parent)))
            changed=deepcopy(repair_meta);mutate(changed);solution_metadata!(repair,changed)
            @test_throws ArgumentError audit()
        end
        solution_metadata!(repair,repair_meta);audit()
        wrong=deepcopy(journal);wrong[Int(id)]["exact_count"]=0
        serial[]+=1
        @test_throws ArgumentError A.with_readonly_index(candidate,joinpath(directory,"wrong-count-$(serial[])")) do index
            A.audit_records(index,expected,wrong,identity,r->nothing;counts=Dict("fixture"=>2))
        end
        # A read-only attempt must refuse an output directory inside its input.
        unsafe=joinpath(Q.library_path(candidate),"audit-output")
        @test_throws ArgumentError A.audit_candidate("not-read",candidate,"not-read",unsafe)
        @test !ispath(unsafe)

        library=Q.library_path(candidate);tar_path=joinpath(candidate,"qubolib.tar");archive=joinpath(candidate,"qubolib.tar.gz")
        function pack(path)
            isfile(tar_path) && rm(tar_path)
            U.Tar.create(path,tar_path)
            open(archive,"w") do io;run(pipeline(`gzip -n -c $tar_path`;stdout=io));end
        end
        pack(library)
        receipt=Dict("members"=>A.member_hashes(library),"artifact_tree"=>bytes2hex(U.Pkg.GitTools.tree_hash(library)),"archive_sha256"=>U.sha(archive),"archive_bytes"=>filesize(archive))
        @test A.verify_artifact(candidate,receipt)["artifact_tree"]==receipt["artifact_tree"]
        stale=joinpath(directory,"stale");mkdir(stale)
        for name in ("archive.h5","index.db");cp(joinpath(library,name),joinpath(stale,name));end
        open(joinpath(stale,"index.db"),"a") do io;write(io,"stale");end
        pack(stale);receipt["archive_sha256"]=U.sha(archive);receipt["archive_bytes"]=filesize(archive)
        @test_throws ArgumentError A.verify_artifact(candidate,receipt)
        write(joinpath(stale,"extra.txt"),"unlisted");pack(stale)
        receipt["archive_sha256"]=U.sha(archive);receipt["archive_bytes"]=filesize(archive)
        @test_throws ArgumentError A.verify_artifact(candidate,receipt)
    end
end
