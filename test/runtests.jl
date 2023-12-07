using Test
using QUBOLib

include("curation.jl")

function main()
    @testset "♣ QUBOLib.jl «$(QUBOLib.__VERSION__)» Test Suite ♣" verbose = true begin
        test_curation()
    end

    return nothing
end

main() # Here we go!
