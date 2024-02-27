using QUBOLib
using JuMP
using DataFrames
using DBInterface

# Solvers
using DWave
using MQLib
using PySA
using InfinityQ

function main()
    QUBOLib.logo()

    QUBOLib.load_index(QUBOLib.root_path(); create = false) do index
        df = DBInterface.execute(
            QUBOLib.database(index),
            "SELECT instance FROM Instances WHERE linear_density > 0.8;"
        ) |> DataFrame

        codes = collect(Int, df[!, :instance])

        @info "Running DWave Neal"
        QUBOLib.run!(index, DWave.Neal.Optimizer, codes; solver = Symbol("dwave-neal"))

        @info "Running MQLib"
        QUBOLib.run!(index, MQLib.Optimizer, codes; solver = :mqlib) do model
            JuMP.set_Attribute(model, "heuristic", "ALKHAMIS1998")
        end

        @info "Running PySA"
        QUBOLib.run!(index, PySA.Optimizer, codes; solver = :pysa)

        @info "Running InfinityQ"
        QUBOLib.run!(index, InfinityQ.Optimizer, codes; solver = :infinityq)
    end

    return nothing
end

main() # Here we go!
