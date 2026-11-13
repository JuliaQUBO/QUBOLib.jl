using Test
include("qoblib_toqubo.jl")
using .QOBLIBToQUBO
const G = QOBLIBToQUBO
const QT = G.QT
const QL = G.QUBOLib

function fixture(root; body = nothing)
    id = "birkhoff-0001"
    inputs = mkpath(joinpath(root, "inputs"))
    function file(name, value; text = false)
        path = joinpath(inputs, name)
        write(path, text ? value : G.JSON.json(value))
        return Dict("path" => "inputs/$name", "sha256" => G.sha(path), "bytes" => filesize(path))
    end
    h = Dict("kind" => "header", "schema" => G.POLYNOMIAL_SCHEMA, "n" => 3,
        "domain" => "bool", "sense" => "max", "scale_exact" => "2//1",
        "offset_exact" => "-1//4", "variable_order" => "one_based_internal")
    rows = [h,
        Dict("kind" => "linear", "i" => 1, "coefficient_exact" => "1//2"),
        Dict("kind" => "linear", "i" => 3, "coefficient_exact" => "-2//1"),
        Dict("kind" => "quadratic", "i" => 1, "j" => 3, "coefficient_exact" => "5//4")]
    # Literal bytes follow the independently pinned Study.persist_polynomial
    # writer, not the importer serializer being checked.
    polynomial = isnothing(body) ?
        "{\"kind\":\"header\",\"schema\":\"qoblib-generated-exact-polynomial-v1\",\"n\":3,\"domain\":\"bool\",\"sense\":\"max\",\"scale_exact\":\"2//1\",\"offset_exact\":\"-1//4\",\"variable_order\":\"one_based_internal\"}\n" *
        "{\"kind\":\"linear\",\"i\":1,\"coefficient_exact\":\"1//2\"}\n" *
        "{\"kind\":\"linear\",\"i\":3,\"coefficient_exact\":\"-2//1\"}\n" *
        "{\"kind\":\"quadratic\",\"i\":1,\"j\":3,\"coefficient_exact\":\"5//4\"}\n" : body
    artifacts = Dict{String,Any}(
        "polynomial" => file("original.jsonl", polynomial; text = true),
        "variable_order" => file("order.json", Dict("order" => [
            Dict("internal_index" => i, "moi_variable_index" => 10 + i) for i in 1:3])),
        "domain_transformations" => file("domains.json", Dict("changed_variable_count" => 0,
            "changed_variables" => [], "source_problem_equivalence" => "integer_domain_preserved")),
        "source_order" => file("source-order.json", Dict("source_order" => ["x", "y"])),
        "lp" => file("source.lp", "Minimize\n obj: x\nBinary\n x\nEnd\n"; text = true),
        "environment" => file("environment.json", Dict("toqubo_commit" => G.TOQUBO_COMMIT, "julia_version" => "1.10.12",
            "packages" => Dict("ToQUBO" => Dict("source_tree" => "254322db6dd588ba427624b557fe0d35f0c3ff55")))))
    source_path = "03-birkhoff/models/integer_linear/lp_files/fixture.lp.xz"
    case = Dict("case_id" => id, "auxiliary_row" => 1, "family" => "birkhoff",
        "source_snapshot_commit" => G.QOBLIB_COMMIT, "source_lp_path" => source_path,
        "source_lp_sha256" => repeat("a", 64),
        "source_lp_decompressed_sha256" => artifacts["lp"]["sha256"],
        "source_lp_git_blob_sha1" => repeat("b", 40), "source_formulation" => "integer_linear",
        "source_continuous_to_integer_required" => false,
        "compressed_lp_local_path" => "/PRIVATE/operator/path/that/must/not/be/released")
    artifacts["case_manifest"] = file("case.json", case)
    inventory_paths = Dict(k => "$id/$(G.FILENAMES[k])" for k in
        ("polynomial", "variable_order", "domain_transformations", "source_order"))
    inventory = [merge(Dict("path" => inventory_paths[k]),
        Dict(x => artifacts[k][x] for x in ("sha256", "bytes"))) for k in keys(inventory_paths)]
    raw_metadata = file("reformulation.json", Dict("schema" => "fixture-raw-compiler-metadata"))
    raw_metadata_descriptor = Dict("path" => "$id/reformulation-metadata.json",
        "sha256" => raw_metadata["sha256"], "bytes" => raw_metadata["bytes"])
    push!(inventory, raw_metadata_descriptor)
    metrics = Dict("n" => 3, "l" => 2, "m" => 1)
    audit = Dict("schema" => "qoblib-missing-case-audit-v1", "passed" => true, "accepted" => true,
        "original_validated" => true, "case_id" => id, "auxiliary_row" => 1, "family" => "birkhoff",
        "auditor_sha256" => G.AUDITOR_SHA, "case_manifest_sha256" => artifacts["case_manifest"]["sha256"],
        "environment_sha256" => artifacts["environment"]["sha256"], "result_sha256" => repeat("c", 64),
        "source_snapshot_commit" => G.QOBLIB_COMMIT, "source_lp_path" => source_path,
        "source_lp_compressed_sha256" => case["source_lp_sha256"],
        "source_lp_decompressed_sha256" => artifacts["lp"]["sha256"],
        "inventory" => inventory, "original" => merge(metrics,
            Dict("polynomial_sha256" => artifacts["polynomial"]["sha256"])))
    artifacts["audit"] = file("audit.json", audit)
    entry = Dict("case_id" => id, "auxiliary_row" => 1, "family" => "birkhoff", "model_role" => "original",
        "source_problem_equivalence" => "not_established", "artifacts" => artifacts,
        "audit_inventory_paths" => inventory_paths, "metrics" => metrics,
        "native_result_sha256" => audit["result_sha256"],
        "raw_reformulation_metadata" => raw_metadata_descriptor,
        "generation" => Dict("toqubo_commit" => G.TOQUBO_COMMIT,
            "toqubo_source_tree" => "254322db6dd588ba427624b557fe0d35f0c3ff55", "julia_version" => "1.10.12",
            "source_run_id" => "fixture-source-run", "source_decoding" => "unavailable_no_validated_adapter",
            "numeric_semantics" => "exact represented polynomial of Float64 LP parse; not exact source-decimal arithmetic"),
        "source" => Dict{String,Any}("path" => source_path, "compressed_sha256" => case["source_lp_sha256"],
            "repository" => "ZIB-AOPT/QOBLIB",
            "commit" => G.QOBLIB_COMMIT, "git_blob_sha1" => case["source_lp_git_blob_sha1"],
            "formulation" => case["source_formulation"],
            "url" => "https://github.com/ZIB-AOPT/QOBLIB/blob/$(G.QOBLIB_COMMIT)/$source_path"))
    report = Dict("case_id" => id, "auxiliary_row" => 1, "family" => "birkhoff",
        "source_lp_path" => source_path, "source_lp_sha256" => case["source_lp_sha256"],
        "source_lp_decompressed_sha256" => artifacts["lp"]["sha256"],
        "controller_status" => "audited_ok", "original" => audit["original"],
        "attempt_history" => [Dict("audited_original" => true, "source_run_id" => "fixture-source-run")],
        "reporting_gate" => Dict("accepted" => true, "original_validated" => true,
            "audit_sha256" => artifacts["audit"]["sha256"],
            "case_manifest_sha256" => artifacts["case_manifest"]["sha256"]))
    report_path = joinpath(root, "STUDY-REPORT.jsonl")
    write(report_path, G.JSON.json(report) * "\n")
    source_plan_path = joinpath(root, "SOURCE-PLAN.json")
    write(source_plan_path, G.JSON.json(Dict("models" => [Dict(k => case[k] for k in G.PUBLIC_CASE_KEYS)])))
    function public_file(name, text)
        path = joinpath(root, "redistribution", name)
        mkpath(dirname(path)); write(path, text)
        return Dict("path" => "redistribution/$name", "sha256" => G.sha(path), "bytes" => filesize(path))
    end
    license = public_file("LICENSE.data", "CC-BY-4.0 fixture license text")
    upstream_readme = public_file("README.upstream.md", "Fixture upstream contributors")
    attribution = public_file("upstream/03-birkhoff/README.md", "Fixture provider and reference")
    inventory = public_file("inventory.json", G.JSON.json([Dict("path" => "03-birkhoff/README.md",
        "sha256" => attribution["sha256"], "bytes" => attribution["bytes"])]))
    redistribution = Dict("license" => license, "upstream_readme" => upstream_readme,
        "attribution_inventory" => inventory, "attributions" => [Dict(
            "upstream_path" => "03-birkhoff/README.md", "artifact" => attribution)])
    entry["source"]["attribution_paths"] = ["03-birkhoff/README.md"]
    authority = (report_sha256 = G.sha(report_path), cohort_count = 1, original_count = 1,
        source_plan_sha256 = G.sha(source_plan_path),
        license_sha256 = license["sha256"], upstream_readme_sha256 = upstream_readme["sha256"],
        attribution_inventory_sha256 = inventory["sha256"])
    cohort = Dict{String,Any}(k => report[k] for k in ("case_id", "auxiliary_row", "family", "source_lp_path", "source_lp_sha256"))
    cohort["audited_original_available"] = true
    cohort["final_outcome"] = report["controller_status"]
    manifest = Dict("schema" => G.SCHEMA, "collection" => G.COLLECTION, "collection_version" => "fixture-1",
        "model_role" => "original", "selection_scope" => "all_audited_originals",
        "source_decoding" => "unavailable_no_validated_adapter", "source_problem_equivalence" => "not_established",
        "solution_import" => false, "data_license" => "CC-BY-4.0", "attribution" => "Fixture author",
        "redistribution" => redistribution,
        "changes" => "Test fixture generated polynomial, not an official QS file",
        "source_snapshot_commit" => G.QOBLIB_COMMIT, "toqubo_commit" => G.TOQUBO_COMMIT,
        "toqubo_source_tree" => "254322db6dd588ba427624b557fe0d35f0c3ff55",
        "study_report_sha256" => authority.report_sha256, "study_cohort_count" => 1,
        "source_plan" => Dict("path" => "SOURCE-PLAN.json", "sha256" => authority.source_plan_sha256,
            "bytes" => filesize(source_plan_path)),
        "study_audited_original_count" => 1,
        "study_report" => Dict("path" => "STUDY-REPORT.jsonl", "sha256" => authority.report_sha256,
            "bytes" => filesize(report_path)), "cohort" => [cohort], "models" => [entry])
    path = joinpath(root, "manifest.json")
    G.new_json(path, manifest)
    return (; path, manifest, authority, rows)
end

announce(name) = (println("Starting: ", name); flush(stdout))

function rewrite_mutable_lineage(candidate, m)
    manifest_path = joinpath(candidate, "IMPORT-MANIFEST.json")
    write(manifest_path, G.JSON.json(m))
    build_path = joinpath(candidate, "BUILD.json")
    build = G.JSON.parsefile(build_path)
    build["manifest_sha256"] = G.sha(manifest_path)
    write(build_path, G.JSON.json(build))
    QL.access(; path = candidate) do index
        rows = QL.DBInterface.execute(QL.database(index), "SELECT metadata FROM Instances WHERE instance=1") |> QL.DataFrame
        meta = G.JSON.parse(only(rows.metadata))
        meta["generated_import"] = m["models"][1]
        QL.DBInterface.execute(QL.database(index), "UPDATE Instances SET metadata=? WHERE instance=1", (G.JSON.json(meta),))
        cr = QL.DBInterface.execute(QL.database(index), "SELECT metadata FROM Collections") |> QL.DataFrame
        collection = G.JSON.parse(only(cr.metadata))
        collection["manifest_sha256"] = G.sha(manifest_path)
        QL.DBInterface.execute(QL.database(index), "UPDATE Collections SET metadata=?", (G.JSON.json(collection),))
    end
end

function expect_rejected(mutate, baseline, destination, authority)
    cp(baseline, destination)
    rm(joinpath(destination, "ACCEPTED.json"))
    mutate(destination)
    @test_throws ArgumentError G.audit(destination; authority)
    @test !isfile(joinpath(destination, "ACCEPTED.json"))
end

announce("exact represented saved polynomial")
@testset "Exact represented saved polynomial" begin
    mktempdir() do root
        f = fixture(root)
        @test f.manifest["models"][1]["source"] isa Dict{String,Any}
        @test f.manifest["models"][1]["source"]["attribution_paths"] == ["03-birkhoff/README.md"]
        @test f.manifest["cohort"][1]["audited_original_available"] === true
        poly = joinpath(root, f.manifest["models"][1]["artifacts"]["polynomial"]["path"])
        model, h, fingerprint = G.read_polynomial(poly)
        @test QT.dimension(model) == 3 # index 2 is isolated and must survive
        @test G.model_identity(model)["sha256"] == fingerprint
        @test G.saved_polynomial_identity(model) == Dict("sha256" => G.sha(poly), "bytes" => filesize(poly))
        for x1 in 0:1, x2 in 0:1, x3 in 0:1
            @test QT.value(model, [x1, x2, x3]) == 2 * (-1/4 + x1/2 - 2x3 + 5x1*x3/4)
        end
        @test string(Symbol(QT.sense(model))) == "max"
        # Formatting is a transport detail; the semantic fingerprint is stable.
        reformatted = joinpath(root, "formatted.jsonl")
        write(reformatted, join([" " * G.JSON.json(row) * " " for row in f.rows], "\n") * "\n")
        @test G.sha(reformatted) != G.sha(poly)
        @test last(G.read_polynomial(reformatted)) == fingerprint
        @test G.exact_float("9007199254740992//1") == 2.0^53
        for bad in ("1//3", "9007199254740993//1", "1//" * string(BigInt(2)^1075),
                    "2//4", "NaN", "1.0", "-0//1", "1//1\n")
            @test_throws ArgumentError G.exact_float(bad)
        end
        @test_throws ArgumentError G.validate_manifest(f.path) # production CLI stays study-pinned
        for mutate in (
            rows -> push!(rows, rows[2]),
            rows -> (rows[4]["j"] = 1),
            rows -> (rows[2]["i"] = 0),
            rows -> (rows[2]["coefficient_exact"] = "0//1"),
            rows -> (rows[1]["offset_exact"] = "1//3"),
            rows -> (rows[1]["scale_exact"] = "0//1"),
            rows -> (rows[1]["domain"] = "spin"),
        )
            rows = deepcopy(f.rows); mutate(rows)
            write(reformatted, join(G.JSON.json.(rows), "\n") * "\n")
            @test_throws ArgumentError G.read_polynomial(reformatted)
        end
        @test_throws ArgumentError G.read_polynomial(poly; max_variables = 2)
        @test_throws ArgumentError G.read_polynomial(poly; max_interactions = 0)
    end
end

announce("retained provenance and no inherited evidence")
@testset "Audit rebinds retained provenance to immutable receipts" begin
    mktempdir() do root
        inputs = mkpath(joinpath(root, "inputs-root"))
        f = fixture(inputs)
        baseline = joinpath(root, "baseline")
        G.build(f.path, baseline; authority = f.authority)
        # Coordinate mutable descriptors, BUILD and SQL metadata. The retained
        # independent receipt/report stay immutable and must reject each change.
        for key in ("lp", "environment", "domain_transformations", "variable_order", "source_order")
            expect_rejected(baseline, joinpath(root, "changed-$key"), f.authority) do candidate
                m = G.JSON.parsefile(joinpath(candidate, "IMPORT-MANIFEST.json"))
                entry = m["models"][1]
                path = joinpath(candidate, "qubolib/generated-provenance/birkhoff-0001", G.FILENAMES[key])
                if key == "lp"
                    write(path, read(path, String) * "\\ changed source\n")
                else
                    value = G.JSON.parsefile(path)
                    if key == "environment"
                        value["julia_version"] = "0.0.0"
                        entry["generation"]["julia_version"] = "0.0.0"
                    elseif key == "domain_transformations"
                        value["changed_variable_count"] = 1
                    elseif key == "variable_order"
                        value["order"][1]["moi_variable_index"] = 1000
                    else
                        value["source_order"] = ["different"]
                    end
                    write(path, G.JSON.json(value))
                end
                entry["artifacts"][key]["sha256"] = G.sha(path)
                entry["artifacts"][key]["bytes"] = filesize(path)
                rewrite_mutable_lineage(candidate, m)
            end
        end
        expect_rejected(baseline, joinpath(root, "changed-source-identity"), f.authority) do candidate
            m = G.JSON.parsefile(joinpath(candidate, "IMPORT-MANIFEST.json"))
            m["models"][1]["source"]["git_blob_sha1"] = repeat("d", 40)
            rewrite_mutable_lineage(candidate, m)
        end
        for key in G.PUBLIC_CASE_KEYS
            expect_rejected(baseline, joinpath(root, "projection-$key"), f.authority) do candidate
                path = joinpath(candidate, "qubolib/generated-provenance/birkhoff-0001/case-provenance.json")
                value = G.JSON.parsefile(path)
                old = value["source"][key]
                value["source"][key] = old isa Bool ? !old : old isa Integer ? old + 1 : old * "-tampered"
                write(path, G.JSON.json(value))
            end
        end
        expect_rejected(baseline, joinpath(root, "private-projection-field"), f.authority) do candidate
            path = joinpath(candidate, "qubolib/generated-provenance/birkhoff-0001/case-provenance.json")
            value = G.JSON.parsefile(path)
            value["private_operator_path"] = "/PRIVATE/path"
            write(path, G.JSON.json(value))
        end
        for kind in ("model_metadata", "solution", "hidden_solution", "extra_instance", "extra_attribute", "sql_solver", "sql_submission", "sql_table", "collection_metadata")
            expect_rejected(baseline, joinpath(root, kind), f.authority) do candidate
                QL.access(; path = candidate) do index
                    h5 = QL.archive(index)
                    if kind == "model_metadata"
                        group = h5["instances"]["1"]["model"]
                        QL.HDF5.delete_object(group, "metadata")
                        group["metadata"] = G.JSON.json(Dict("optimal" => true))
                    elseif kind == "solution"
                        group = h5["instances"]["1"]
                        model = QL.load_instance(index, 1)
                        solution = QT.SampleSet{Float64,Int}(model, [[0, 0, 0]];
                            metadata = Dict{String,Any}("status" => "optimal"))
                        QL.HDF5.delete_object(group, "solution")
                        QL._write_qubin_solution(group, solution)
                    elseif kind == "hidden_solution"
                        QL.HDF5.create_group(h5["solutions"], "private-witness")
                    elseif kind == "extra_instance"
                        QL.HDF5.create_group(h5["instances"], "999")
                    elseif kind == "extra_attribute"
                        QL.HDF5.attrs(h5["instances"]["1"])["private_witness"] = "101"
                    elseif kind == "sql_solver"
                        QL.DBInterface.execute(QL.database(index), "INSERT INTO Solvers(solver) VALUES ('unreviewed')")
                    elseif kind == "sql_submission"
                        QL.DBInterface.execute(QL.database(index), "INSERT INTO Submissions(submitter) VALUES ('unreviewed')")
                    elseif kind == "sql_table"
                        QL.DBInterface.execute(QL.database(index), "CREATE TABLE PrivateWitness(bits TEXT)")
                    else
                        QL.DBInterface.execute(QL.database(index), "UPDATE Collections SET metadata='{}'")
                    end
                end
            end
        end
    end
end

announce("audit missing/linked store prechecks")
@testset "Audit refuses incomplete stores without installing or overwriting" begin
    mktempdir() do root
        f = fixture(mkpath(joinpath(root, "inputs-root")))
        baseline = joinpath(root, "baseline")
        G.build(f.path, baseline; authority = f.authority)
        for missing in ("index.db", "archive.h5")
            candidate = joinpath(root, "missing-$missing")
            cp(baseline, candidate)
            store = joinpath(candidate, "qubolib")
            rm(joinpath(store, missing))
            other = missing == "index.db" ? "archive.h5" : "index.db"
            original = G.sha(joinpath(store, other))
            @test_throws ArgumentError G.audit(candidate; authority = f.authority)
            @test !ispath(joinpath(store, missing))
            @test G.sha(joinpath(store, other)) == original
        end
        linked = joinpath(root, "linked-store")
        cp(baseline, linked)
        archive = joinpath(linked, "qubolib/archive.h5")
        rm(archive)
        symlink(joinpath(baseline, "qubolib/archive.h5"), archive)
        @test_throws ArgumentError G.audit(linked; authority = f.authority)
        unaudited = joinpath(root, "no-acceptance")
        cp(baseline, unaudited)
        rm(joinpath(unaudited, "ACCEPTED.json"))
        @test_throws ArgumentError G.pack(unaudited, joinpath(root, "no-acceptance-release"); authority = f.authority)
        @test !ispath(joinpath(unaudited, "ACCEPTED.json"))
        wrong = joinpath(root, "wrong-extraction")
        cp(joinpath(baseline, "qubolib"), wrong)
        original = G.sha(joinpath(wrong, "archive.h5"))
        @test_throws ArgumentError G.audit(wrong; authority = f.authority)
        @test !ispath(joinpath(wrong, "qubolib"))
        @test G.sha(joinpath(wrong, "archive.h5")) == original
    end
end

announce("strict identifiers and explicit pilot receipts")
@testset "Strict end anchors and explicit selection scope" begin
    mktempdir() do root
        f = fixture(root)
        @test_throws ArgumentError G.descriptor_path(root,
            merge(f.manifest["models"][1]["artifacts"]["lp"], Dict("sha256" => f.manifest["models"][1]["artifacts"]["lp"]["sha256"] * "\n")))
        m = G.validate_manifest(f.path; authority = f.authority)
        invalid = deepcopy(m["models"][1])
        invalid["case_id"] *= "\n"
        @test_throws ArgumentError G.validate_entry(root, m, invalid)
        f.manifest["collection_version"] = "fixture-1\n"
        write(f.path, G.JSON.json(f.manifest))
        @test_throws ArgumentError G.validate_manifest(f.path; authority = f.authority)
        f.manifest["collection_version"] = "fixture-1"
        f.manifest["selection_scope"] = "pilot"
        write(f.path, G.JSON.json(f.manifest))
        candidate = joinpath(root, "pilot-candidate")
        G.build(f.path, candidate; authority = f.authority)
        @test G.JSON.parsefile(joinpath(candidate, "ACCEPTED.json"))["selection_scope"] == "pilot"
        release = joinpath(root, "pilot-release")
        G.pack(candidate, release; authority = f.authority)
        receipt = G.JSON.parsefile(joinpath(release, "RELEASE-CANDIDATE.json"))
        @test receipt["selection_scope"] == "pilot"
        @test receipt["study_audited_original_count"] == 1
    end
end

announce("immutable Original coordinated tamper regression")
@testset "Immutable Original binding rejects coordinated candidate tampering" begin
    mktempdir() do root
        inputs = mkpath(joinpath(root, "inputs-root"))
        f = fixture(inputs)
        candidate = joinpath(root, "candidate")
        G.build(f.path, candidate; authority = f.authority)
        altered = QL.access(; path = candidate) do index
            values = QL.archive(index)["instances"]["1"]["model"]["form"]["linear"]["v"]
            coefficients = read(values)
            coefficients[1] += 1.0
            write(values, coefficients)
            identity = G.model_identity(QL.load_instance(index, 1))
            rows = QL.DBInterface.execute(QL.database(index), "SELECT metadata FROM Instances WHERE instance=1") |> QL.DataFrame
            metadata = G.JSON.parse(only(rows.metadata))
            metadata["model_identity"] = identity
            QL.DBInterface.execute(QL.database(index), "UPDATE Instances SET metadata=? WHERE instance=1", (G.JSON.json(metadata),))
            identity
        end
        build_path = joinpath(candidate, "BUILD.json")
        build = G.JSON.parsefile(build_path)
        build["records"][1]["identity"] = altered
        write(build_path, G.JSON.json(build))
        rm(joinpath(candidate, "ACCEPTED.json"))
        QL.access(; path = candidate) do index
            rows = QL.DBInterface.execute(QL.database(index), "SELECT metadata FROM Instances WHERE instance=1") |> QL.DataFrame
            @test G.JSON.parse(only(rows.metadata))["model_identity"] == altered
            @test G.model_identity(QL.load_instance(index, 1)) == build["records"][1]["identity"]
        end
        error = try
            G.audit(candidate; authority = f.authority)
            nothing
        catch exception
            exception
        end
        @test error isa ArgumentError
        @test occursin("immutable saved Original", sprint(showerror, error))
        @test !isfile(joinpath(candidate, "ACCEPTED.json"))
    end
end

announce("public artifact inventory and resolved output containment")
@testset "Public artifact inventory and resolved output containment" begin
    mktempdir() do root
        inputs = mkpath(joinpath(root, "inputs-root"))
        f = fixture(inputs)
        candidate = joinpath(root, "candidate")
        G.build(f.path, candidate; authority = f.authority)
        lib = joinpath(candidate, "qubolib")
        @test isnothing(G.check_public_tree(lib, G.public_library_files(f.manifest)))
        for (i, relative) in enumerate(("FETCH-PRIVATE.json", "generated-provenance/birkhoff-0001/raw-witness.json"))
            path = joinpath(lib, relative)
            write(path, "private material must not enter a release")
            release = joinpath(root, "contaminated-release-$i")
            @test_throws ArgumentError G.pack(candidate, release; authority = f.authority)
            @test !ispath(release)
            rm(path)
        end
        path = joinpath(candidate, "redistribution/FETCH-PRIVATE.json")
        write(path, "private fetch metadata")
        @test_throws ArgumentError G.pack(candidate, joinpath(root, "bad-redistribution"); authority = f.authority)
        rm(path)
        empty = joinpath(lib, "unlisted-empty-directory")
        mkdir(empty)
        @test_throws ArgumentError G.pack(candidate, joinpath(root, "bad-empty"); authority = f.authority)
        rm(empty)
        linked = joinpath(lib, "unexpected-link")
        symlink(joinpath(inputs, "manifest.json"), linked)
        @test_throws ArgumentError G.pack(candidate, joinpath(root, "bad-link"); authority = f.authority)
        rm(linked)
        alias = joinpath(root, "candidate-alias")
        symlink(candidate, alias)
        @test_throws ArgumentError G.pack(candidate, joinpath(alias, "release"); authority = f.authority)
        @test !ispath(joinpath(candidate, "release"))
        # Resolve a symlink before '..', not merely after lexical abspath.
        lib_alias = joinpath(root, "library-alias")
        symlink(lib, lib_alias)
        @test_throws ArgumentError G.pack(candidate, joinpath(lib_alias, "..", "nested-release"); authority = f.authority)
        @test !ispath(joinpath(candidate, "nested-release"))
        @test_throws ArgumentError G.pack(candidate, joinpath(alias, "absent", "tail"); authority = f.authority)
        @test !ispath(joinpath(candidate, "absent"))
    end
end

announce("separate candidate and nonmutating pack roundtrip")
@testset "Separate candidate, provenance and actual HDF5 roundtrip" begin
    mktempdir() do root
        inputs = mkpath(joinpath(root, "inputs-root"))
        f = fixture(inputs)
        candidate = joinpath(root, "candidate")
        G.build(f.path, candidate; authority = f.authority)
        @test G.audit(candidate; authority = f.authority)["instance_count"] == 1
        @test_throws ArgumentError G.build(f.path, candidate; authority = f.authority)
        @test !isfile(joinpath(candidate, "Artifacts.toml"))
        QL.access(; path = candidate) do index
            @test QL.collection_size(index, G.COLLECTION) == 1
            @test !QL.has_collection(index, "qoblib")
            @test !QL.has_collection(index, "standalone")
            @test !QL.has_collection(index, "qubolib")
            @test isempty(QL.list_solution_records(index, 1))
            @test_throws ErrorException QL.project_solution(index, 1, "000")
        end
        evidence = joinpath(candidate, "qubolib/generated-provenance/birkhoff-0001")
        @test !isfile(joinpath(evidence, "case.json"))
        @test !occursin("PRIVATE", read(joinpath(evidence, "case-provenance.json"), String))
        @test G.JSON.parsefile(joinpath(evidence, "case-provenance.json"))["raw_case_manifest_sha256"] ==
            f.manifest["models"][1]["artifacts"]["case_manifest"]["sha256"]
        release = joinpath(root, "release")
        candidate_tree = bytes2hex(G.Pkg.GitTools.tree_hash(candidate))
        archive = G.pack(candidate, release; authority = f.authority)
        @test bytes2hex(G.Pkg.GitTools.tree_hash(candidate)) == candidate_tree
        receipt = G.JSON.parsefile(joinpath(release, "RELEASE-CANDIDATE.json"))
        @test receipt["archive_sha256"] == G.sha(archive)
        @test receipt["default_artifact_changed"] === false
        @test receipt["selection_scope"] == "all_audited_originals"
        @test receipt["study_audited_original_count"] == 1
        second = joinpath(root, "second-release")
        @test isfile(G.pack(candidate, second; authority = f.authority))
        @test G.JSON.parsefile(joinpath(second, "RELEASE-CANDIDATE.json"))["git_tree_sha1"] == receipt["git_tree_sha1"]
        @test bytes2hex(G.Pkg.GitTools.tree_hash(candidate)) == candidate_tree
        extracted = mkpath(joinpath(root, "extracted/qubolib"))
        G.Tar.extract(`gzip -dc $archive`, extracted)
        @test bytes2hex(G.Pkg.GitTools.tree_hash(extracted)) == receipt["git_tree_sha1"]
        @test G.audit(dirname(extracted); authority = f.authority)["passed"] === true
        QL.access(; path = dirname(extracted)) do index
            @test G.model_identity(QL.load_instance(index, 1))["sha256"] ==
                G.JSON.parsefile(joinpath(candidate, "BUILD.json"))["records"][1]["identity"]["sha256"]
        end
        write(joinpath(evidence, "original-variable-order.json"), "{}")
        @test_throws ArgumentError G.audit(candidate; authority = f.authority)
    end
end

announce("fail closed before acceptance")
@testset "Fail closed before acceptance" begin
    mktempdir() do root
        f = fixture(root)
        a = f.manifest["models"][1]["artifacts"]
        @test_throws ArgumentError G.relative_path(root, "../outside")
        symlink(joinpath(root, a["lp"]["path"]), joinpath(root, "linked"))
        @test_throws ArgumentError G.relative_path(root, "linked")
        @test_throws ArgumentError G.descriptor_path(root, merge(a["lp"], Dict("bytes" => 0)))
        write(joinpath(root, a["polynomial"]["path"]), "tampered")
        destination = joinpath(root, "failed")
        @test_throws ArgumentError G.build(f.path, destination; authority = f.authority)
        @test !isfile(joinpath(destination, "ACCEPTED.json"))
        @test isfile(joinpath(destination, "FAILED.json"))
    end
end

announce("unsupported empty coefficient groups")
@testset "Unsupported empty groups fail clearly before SQL storage" begin
    mktempdir() do root
        f = fixture(root)
        for rows in ([f.rows[1], f.rows[2]], [f.rows[1], f.rows[4]], [f.rows[1]])
            path = joinpath(root, "empty-group.jsonl")
            write(path, join(G.JSON.json.(rows), "\n") * "\n")
            error = try
                G.read_polynomial(path)
                nothing
            catch exception
                exception
            end
            @test error isa ArgumentError
            @test occursin("nonempty linear and quadratic", sprint(showerror, error))
        end
    end
end
