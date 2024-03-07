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
