using Test
using Statistics

import QUBOLib
import QUBOTools

include("synthesis.jl")

function main()
    @testset "♣ QUBOLib.jl «$(QUBOLib.__VERSION__)» Test Suite ♣" verbose = true begin
        test_synthesis()
    end

    return nothing
end

main() # Here we go!
