function generate(problem::AbstractProblem)
    return generate(Random.GLOBAL_RNG, problem)
end

function _synthesis_metadata(problem::AbstractString, parameters::Dict{String,Any})
    metadata = Dict{String,Any}(
        "origin"    => "QUBOLib.jl",
        "synthesis" => Dict{String,Any}(
            "problem"    => String(problem),
            "parameters" => parameters,
        ),
    )

    let report = QUBOLib.JSONSchema.validate(metadata, QUBOLib.SYNTHESIS_METADATA_SCHEMA)
        if !isnothing(report)
            error("Invalid synthesis metadata:\n$report")
        end
    end

    return metadata
end
