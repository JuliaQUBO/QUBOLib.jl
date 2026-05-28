function test_readme()
    @testset "-> README" begin
        readme = read(joinpath(QUBOLib.root_path(), "README.md"), String)

        @test occursin("Retrieving instances", readme)
        @test occursin("Artifacts.toml", readme)
        @test occursin("QUBOLib.access", readme)
        @test occursin("QUBOLib.load_instance", readme)
        @test occursin("delete the local `qubolib`", readme)
        @test occursin("Pkg.add([\"SQLite\", \"DataFrames\"])", readme)
        @test !occursin("`clear = true` to recreate it from the packaged artifact", readme)
    end

    return nothing
end
