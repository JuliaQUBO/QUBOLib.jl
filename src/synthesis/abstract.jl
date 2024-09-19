function QUBOLib.generate(problem::QUBOLib.AbstractProblem)
    return QUBOLib.generate(Random.GLOBAL_RNG, problem)
end
