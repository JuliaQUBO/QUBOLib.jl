using QUBOLib
using JuMP
using DataFrames
using DBInterface

# Solvers
# using DWave
# using MQLib
# using PySA
# using InfinityQ
# using AIMOpt

function warmup!(config!, model::JuMP.Model)
    Q = 2 * rand(3, 3) .- 1

    JuMP.@variable(model, x[1:3], Bin)
    JuMP.@objective(model, Min, x' * Q * x)

    config!(model)

    JuMP.optimize!(model)

    empty!(model)

    return nothing
end

function run!(
    config!::Function,
    index::LibraryIndex,
    optimizer,
    codes::AbstractVector{U};
    kws...,
) where {U<:Integer}
    model = JuMP.Model(optimizer)

    warmup!(config!, model)

    for code in codes
        try
            run!(index, model, code; kws...)
        catch e
            @error "Failed to run instance '$code': $(sprint(showerror, e))"
        end
    end

    return nothing
end

function run!(index::LibraryIndex, model::JuMP.Model, code::Integer; solver::Union{Symbol,Nothing} = nothing)
    n, L, Q, α, β = QUBOTools.qubo(
        QUBOLib.load_instance(index, code),
        :sparse;
        sense = :min,
    )

    empty!(model)

    x = JuMP.@variable(model, [1:n], Bin)

    JuMP.@objective(model, Min, α * (x' * Q * x + L' * x + β))

    config!(model)

    JuMP.optimize!(model)

    let m = JuMP.unsafe_backend(model)
        if m isa QUBODrivers.AbstractSampler
            sol = QUBOTools.solution(m)

            if !isnothing(solver)
                let data = QUBOTools.metadata(sol)
                    data["solver"] = string(solver)
                end
            end

            QUBOLib.add_solution!(index, code, sol)
        end
    end

    return model
end

function run!(index::LibraryIndex, optimizer, codes::AbstractVector{U}; kws...) where {U<:Integer}
    run!(identity, index, optimizer, codes; kws...)

    return nothing
end

function main()
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

# main() # Here we go!
