using QUBOLib
using JuMP
using DataFrames
using DBInterface

# Solvers
using DWave
using MQLib
using PySA
using InfinityQ
using AIMOpt

function main()
    QUBOLib.logo()

    QUBOLib.load_index(QUBOLib.root_path(); create = false) do index
        df = DBInterface.execute(
            QUBOLib.database(index),
            "SELECT instance FROM Instances WHERE dimension < 100 AND quadratic_density < 0.5;"
        ) |> DataFrame

        codes = collect(Int, df[!, :instance])

        @info "Running DWave Neal"
        QUBOLib.run!(index, DWave.Neal.Optimizer, codes; solver = Symbol("dwave-neal"))

        @info "Running DWave (Quantum)"
        QUBOLib.run!(index, DWave.Optimizer, codes; solver = :dwave)

        @info "Running MQLib"
        QUBOLib.run!(index, MQLib.Optimizer, codes; solver = :mqlib) do model
            JuMP.set_silent(model)
            JuMP.set_attribute(model, "heuristic", "ALKHAMIS1998")
        end

        @info "Running PySA"
        QUBOLib.run!(index, PySA.Optimizer, codes; solver = :pysa) do model
            JuMP.set_silent(model)
        end

        @info "Running InfinityQ"
        QUBOLib.run!(index, InfinityQ.Optimizer, codes; solver = :infinityq)

        @info "Running AIMOpt"
        QUBOLib.run!(index, AIMOpt.Optimizer, codes; solver = :aimopt)
    end

    return nothing
end

main() # Here we go!
