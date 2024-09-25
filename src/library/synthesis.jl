module Synthesis

import Random
import QUBOTools
import ..QUBOLib
import ..QUBOLib: AbstractProblem, generate
import PseudoBooleanOptimization as PBO

include("synthesis/abstract.jl")
include("synthesis/nae3sat.jl")
include("synthesis/sherrington_kirkpatrick.jl")
include("synthesis/wishart.jl")
include("synthesis/xorsat.jl")

end # module Synthesis
