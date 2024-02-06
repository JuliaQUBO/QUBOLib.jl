function run(instances, optimizers)
    for instance in instances
        for optimizer in optimizers
            println("Running $(instance) with $(optimizer)")
        end
    end
end
