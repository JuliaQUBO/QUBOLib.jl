using Test
using Statistics

import QUBOTools
import QUBOLib

include("synthesis.jl")

function main()
    @testset "♣ QUBOLib.jl «$(QUBOLib.__version__())» Test Suite ♣" verbose = true begin
        test_synthesis()
    end

    return nothing
end

main() # Here we go!
