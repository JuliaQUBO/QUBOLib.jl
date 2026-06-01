function _compat_allows(compat::AbstractString, version::VersionNumber)
    return version in QUBOLib.Pkg.Types.semver_spec(compat)
end

function test_project_metadata()
    @testset "Project metadata" begin
        project = QUBOLib.TOML.parsefile(joinpath(pkgdir(QUBOLib), "Project.toml"))

        @test QUBOLib.__version__() == VersionNumber(project["version"])
        @test _compat_allows(project["compat"]["QUBOTools"], v"0.12.1")
    end

    return nothing
end
