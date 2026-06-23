function test_synthesis()
    @testset "→ Synthesis" verbose = true begin
        test_wishart()
        test_sherrington_kirkpatrick()
    end

    return nothing
end

function test_wishart()
    @testset "⋅ Wishart" begin
        let n = 100
            m = 10

            model = QUBOLib.Synthesis.generate(QUBOLib.Synthesis.Wishart(n, m))

            @test QUBOTools.dimension(model) == n
            @test QUBOTools.density(model) ≈ 1.0 atol = 1E-8
            test_synthesis_model_metadata(
                model,
                "Wishart",
                Dict{String,Any}(
                    "n"          => n,
                    "m"          => m,
                    "discretize" => false,
                    "precision"  => 0,
                ),
            )
            
            let sol = QUBOTools.solution(model)
                @test length(sol) > 0
                test_synthesis_solution_metadata(sol)
            end
        end
    end

    return nothing
end

function test_sherrington_kirkpatrick()
    @testset "⋅ Sherrington-Kirkpatrick" begin
        let n = 100
            μ = 5.0
            σ = 1E-3
        
            model = QUBOLib.Synthesis.generate(QUBOLib.Synthesis.SK(n, μ, σ))
            
            @test QUBOTools.dimension(model) == n
            @test QUBOTools.density(model) ≈ 1.0 atol = 1E-8

            @test mean(last, QUBOTools.linear_terms(model))    ≈ 2μ * (1 - n) atol = 10σ
            @test mean(last, QUBOTools.quadratic_terms(model)) ≈ 4μ           atol = 10σ
            test_synthesis_model_metadata(
                model,
                "Sherrington-Kirkpatrick",
                Dict{String,Any}(
                    "n"     => n,
                    "mu"    => μ,
                    "sigma" => σ,
                ),
            )
        end
    end

    return nothing
end

function test_synthesis_model_metadata(model, problem::AbstractString, parameters::Dict{String,Any})
    metadata = QUBOTools.metadata(model)

    @test metadata["origin"] == "QUBOLib.jl"
    @test metadata["synthesis"]["problem"] == problem
    @test metadata["synthesis"]["parameters"] == parameters
    @test isnothing(QUBOLib.JSONSchema.validate(metadata, QUBOLib.SYNTHESIS_METADATA_SCHEMA))
    @test QUBOLib.JSON.parse(QUBOLib.JSON.json(metadata))["synthesis"]["parameters"] == parameters

    invalid_wishart_metadata = Dict{String,Any}(
        "origin"    => "QUBOLib.jl",
        "synthesis" => Dict{String,Any}(
            "problem"    => "Wishart",
            "parameters" => Dict{String,Any}(
                "n" => 8,
                "m" => 3,
            ),
        ),
    )

    @test !isnothing(
        QUBOLib.JSONSchema.validate(invalid_wishart_metadata, QUBOLib.SYNTHESIS_METADATA_SCHEMA)
    )

    return nothing
end

function test_synthesis_solution_metadata(sol)
    metadata = QUBOTools.metadata(sol)

    @test !haskey(metadata, "time")
    @test QUBOLib.JSON.json(metadata) isa String

    return nothing
end
