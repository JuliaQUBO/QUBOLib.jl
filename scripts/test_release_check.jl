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
        @test !isempty(failures()) # Recorded access is not yet verified.
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
