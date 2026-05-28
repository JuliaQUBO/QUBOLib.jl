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

    return nothing
end
