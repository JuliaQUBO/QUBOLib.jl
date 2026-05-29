function test_library_access()
    @testset "→ Library access" begin
        mktempdir() do path
            model = QUBOLib.Synthesis.generate(QUBOLib.Synthesis.Wishart(8, 3))

            QUBOLib.access(; path, clear = true) do index
                instance = QUBOLib.add_instance!(index, model)
                loaded   = QUBOLib.load_instance(index, instance)

                @test QUBOTools.dimension(loaded) == QUBOTools.dimension(model)
                @test QUBOTools.density(loaded) ≈ QUBOTools.density(model)
                @test !isempty(QUBOTools.solution(model))
                @test QUBOLib.add_solution!(index, instance, QUBOTools.solution(model)) > 0
            end
        end
    end

    @testset "Solution records" begin
        mktempdir() do path
            model = QUBOTools.Model(
                Dict(1 => 1.0, 2 => 2.0, 3 => 4.0),
                Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5),
            )

            QUBOLib.access(; path, clear = true) do index
                instance = QUBOLib.add_instance!(index, model)

                late_submission = QUBOLib.add_submission!(
                    index;
                    submitter = "late",
                    date = "2026-01-02",
                )
                early_submission = QUBOLib.add_submission!(
                    index;
                    submitter = "early",
                    date = "2026-01-01",
                )

                invalid = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "000",
                    validation_status = "invalid",
                )
                infeasible = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "000",
                    feasibility_status = "infeasible",
                )
                worse = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "100",
                )
                late = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = late_submission,
                    bitstring = "000",
                )
                early = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "000",
                )

                records = QUBOLib.list_solution_records(index, instance)

                @test size(records, 1) == 5
                @test Set(records[!, :record]) == Set([invalid, infeasible, worse, late, early])

                best = QUBOLib.best_solution_record(index, instance)

                @test best[:record] == early
                @test best[:qubo_value] ≈ 0.0
                @test QUBOLib.load_best_solution(index, instance) === nothing

                sol = QUBOTools.SampleSet{Float64,Int}(
                    model,
                    [[0, 0, 0]];
                    metadata = Dict{String,Any}("status" => "optimal"),
                )
                solution = QUBOLib.add_solution!(index, instance, sol)
                loaded = QUBOLib.load_solution(index, instance, solution)

                @test !isempty(loaded)
                @test QUBOTools.state(loaded[1]) == [0, 0, 0]

                best = QUBOLib.best_solution_record(index, instance)
                loaded_best = QUBOLib.load_best_solution(index, instance)

                @test best[:solution] == solution
                @test QUBOTools.state(loaded_best[1]) == [0, 0, 0]
                @test QUBOTools.value(loaded_best, 1) ≈ QUBOTools.value(sol, 1)
            end
        end
    end

    @testset "Best solution sense" begin
        mktempdir() do path
            model = QUBOTools.Model(
                Dict(1 => 1.0, 2 => 2.0),
                Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5);
                sense = :max,
            )

            QUBOLib.access(; path, clear = true) do index
                instance = QUBOLib.add_instance!(index, model)
                low = QUBOLib.add_solution_record!(index, instance; bitstring = "00")
                high = QUBOLib.add_solution_record!(index, instance; bitstring = "10")
                best = QUBOLib.best_solution_record(index, instance)

                @test best[:record] == high
                @test best[:record] != low
            end
        end
    end

    return nothing
end
