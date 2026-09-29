module ReleaseCheckTests
using Test
include("release_check.jl")

function test_dataset_publication_gate()
    @testset "Dataset publication gate" begin
        zenodo = TOML.parsefile(joinpath(ROOT, "DATASET.toml"))["zenodo"]
        collections = (all_provenance_verified = true, all_rights_verified = true)
        failures(z = zenodo, c = collections) = begin
            errors = String[]
            check_zenodo_metadata!(errors, String[], z, c; require_publishable = true)
            errors
        end
        # Test an explicit blocked fixture, independent of the live release state.
        blocked = merge(
            zenodo,
            Dict(
                "status" => "blocked",
                "blocking_reasons" => ["Draft verification is incomplete."],
                "active_manager_count" => 0,
                "manager_access_status" => "not-recorded",
                "byte_identity_status" => "not-verified",
                "related_identifiers_status" => "not-recorded",
            ),
        )
        @test !isempty(failures(blocked))
        ready = merge(
            zenodo,
            Dict(
                "status" => "ready",
                "blocking_reasons" => String[],
                "active_manager_count" => 1,
                "manager_access_status" => "verified",
                "byte_identity_status" => "verified",
                "related_identifiers_status" => "verified",
            ),
        )
        @test isempty(failures(ready))
        published = merge(
            ready,
            Dict(
                "status" => "published",
                "concept_doi" => "10.5281/zenodo.1",
                "version_doi" => "10.5281/zenodo.2",
            ),
        )
        @test isempty(failures(published))
        for key in ("concept_doi", "version_doi")
            missing_doi = copy(published)
            delete!(missing_doi, key)
            @test !isempty(failures(missing_doi))
            @test !isempty(failures(merge(published, Dict(key => "not-a-doi"))))
        end
        for (key, value) in (
            "manager_policy_evidence_url" => "",
            "designated_owner" => "another-owner",
            "required_active_managers" => 0,
            "active_manager_count" => 0,
            "manager_access_status" => "not-recorded",
            "byte_identity_status" => "not-verified",
            "related_identifiers_status" => "not-recorded",
        )
            @test !isempty(failures(merge(ready, Dict(key => value))))
        end
        @test !isempty(
            failures(ready, (all_provenance_verified = true, all_rights_verified = false)),
        )
        @test !isempty(
            failures(ready, (all_provenance_verified = false, all_rights_verified = true)),
        )
        @test isempty(
            failures(
                merge(
                    ready,
                    Dict(
                        "required_active_managers" => 2,
                        "active_manager_count" => 2,
                        "manager_policy_evidence_url" => "",
                        "designated_owner" => "",
                    ),
                ),
            ),
        )
    end
end
end

ReleaseCheckTests.test_dataset_publication_gate()
