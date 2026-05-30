function test_docs()
    @testset "-> Website docs" begin
        docs_home = read(joinpath(QUBOLib.root_path(), "docs", "src", "index.md"), String)
        intro = read(joinpath(QUBOLib.root_path(), "docs", "src", "manual", "0-intro.md"), String)
        basic = read(joinpath(QUBOLib.root_path(), "docs", "src", "manual", "1-basic.md"), String)
        advanced = read(joinpath(QUBOLib.root_path(), "docs", "src", "manual", "2-advanced.md"), String)

        @test occursin("Retrieving instances", docs_home)
        @test occursin("Julia artifact", docs_home)
        @test occursin("QUBOLib.access", docs_home)
        @test occursin("QUBOLib.load_instance", docs_home)
        @test occursin("delete the local `qubolib`", docs_home)
        @test occursin("Pkg.add([\"SQLite\", \"DataFrames\"])", docs_home)
        @test occursin("donate challenging QUBOs", docs_home)

        math_heading = findfirst("## Mathematical Definitions", intro)
        benchmark_heading =
            findfirst("## Benchmarking Physics-Inspired Optimization Solvers", intro)

        @test !isnothing(math_heading)
        @test !isnothing(benchmark_heading)
        @test first(math_heading) < first(benchmark_heading)
        @test occursin("Benchmarking Physics-Inspired Optimization Solvers", intro)
        @test occursin("Instances", intro)
        @test occursin("Submissions", intro)
        @test occursin("SolutionRecords", intro)
        @test occursin("BestSolutions", intro)
        @test occursin("QUBOLib.load_instance", intro)
        @test occursin("QUBOTools.value", intro)
        @test occursin("QUBOLib.load_best_solution", intro)
        @test occursin("QUBOLib.best_solution_record", intro)
        @test occursin("QUBOLib.list_solution_records", intro)
        @test occursin("canonical benchmark comparator is `qubo_value`", intro)
        @test occursin("`source_value` is provenance", intro)
        @test occursin("solver stacks such as QUBODrivers", intro)
        @test occursin("```@example benchmarking-workflow", intro)
        @test occursin("zero-fill", intro)
        @test occursin("one-fill", intro)

        @test occursin("Opening the library index", basic)
        @test occursin("Loading an instance", basic)
        @test occursin("QUBOLib.database", basic)
        @test occursin("QUBOLib.load_instance", basic)
        @test occursin("Pkg.add([\"SQLite\", \"DataFrames\"])", basic)

        @test occursin("Adding a new collection", advanced)
        @test occursin("QUBOLib.add_collection!", advanced)
        @test occursin("QUBOLib.add_instance!", advanced)
        @test occursin("Pkg.add(\"QUBOTools\")", advanced)
        @test occursin("`clear = true` deletes any existing local QUBOLib data", advanced)
        @test occursin("Collection metadata", advanced)
        @test occursin("Packaged artifact workflow", advanced)
        @test occursin("donate", advanced)
    end

    return nothing
end
