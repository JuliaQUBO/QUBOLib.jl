using DWave

function main()
    QUBOLib.access(; path = QUBOLib.root_path(), create = false) do index
        df = DBInterface.execute(
            QUBOLib.database(index),
            "SELECT instance FROM Instances WHERE dimension < 100 AND quadratic_density < 0.5;"
        ) |> DataFrame

        codes = collect(Int, df[!, :instance])

        @info "Running DWave Neal"
        QUBOLib.run!(index, DWave.Neal.Optimizer, codes; solver = "dwave-neal")

        @info "Running DWave (Quantum)"
        QUBOLib.run!(index, DWave.Optimizer, codes; solver = "dwave")
    end

    return nothing
end
