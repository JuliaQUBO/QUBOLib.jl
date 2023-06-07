const QUBO_FORMATS = Dict(
    "qubist" => QUBOTools.Qubist()
)


function load_instance(
    collection::AbstractString,
    instance::AbstractString
)
    filepath = joinpath(collections, collection, "data", instance)
    
    if !isfile(filepath)
        error("Unknown instance '$path'")
    end
    
    metadata = JSON.parsefile(joinpath(collections, collection, "metadata.json"))
    
    format = QUBO_FORMATS[metadata["format"]]

    return return QUBOTools.read_model(filepath, format)
end
