using Test
using Statistics

import QUBOTools
import QUBOLib

include("synthesis.jl")
include("library/path.jl")
include("library/access.jl")

function main()
    @testset "♣ QUBOLib.jl «$(QUBOLib.__version__())» Test Suite ♣" verbose = true begin
        test_path()
        test_library_access()
        test_synthesis()
    end

    return nothing
end

main() # Here we go!
