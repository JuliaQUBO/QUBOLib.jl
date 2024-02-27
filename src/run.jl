function warmup!(model::JuMP.Model)
    Q = 2 * rand(3, 3) .- 1

    JuMP.@variable(model, x[1:3], Bin)
    JuMP.@objective(model, Min, x' * Q * x)
    JuMP.optimize!(model)

    empty!(model)

    return nothing
end

function run!(
    config!::Function,
    index::LibraryIndex,
    optimizer,
    codes::AbstractVector{U};
    solver::Union{Symbol,Nothing} = nothing,
) where {U<:Integer}
    model = JuMP.Model(optimizer)

    warmup!(model)

    for i in codes
        n, L, Q, α, β = QUBOTools.qubo(
            QUBOLib.load_instance(index, i),
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

                QUBOLib.add_solution!(index, i, sol)
            end
        end
    end

    return nothing
end

function run!(index::LibraryIndex, optimizer, codes::AbstractVector{U}; kws...) where {U<:Integer}
    run!(identity, index, optimizer, codes; kws...)

    return nothing
end
