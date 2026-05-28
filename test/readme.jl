function test_readme()
    @testset "-> README" begin
        readme = read(joinpath(QUBOLib.root_path(), "README.md"), String)

        @test occursin("Retrieving instances", readme)
        @test occursin("Artifacts.toml", readme)
        @test occursin("QUBOLib.access", readme)
        @test occursin("QUBOLib.load_instance", readme)
    end

    return nothing
end
