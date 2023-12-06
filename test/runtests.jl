using Test
using QUBOInstances

include("curation.jl")

function main()
    @testset "♣ QUBOInstances.jl «$(QUBOInstances.__VERSION__)» Test Suite ♣" verbose = true begin
        test_curation()
    end

    return nothing
end

main() # Here we go!
