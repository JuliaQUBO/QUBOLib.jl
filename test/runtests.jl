using Test
using Statistics

import QUBOTools
import QUBOLib

include("synthesis.jl")
include("project.jl")
include("library/path.jl")
include("library/access.jl")
include("readme.jl")
include("docs.jl")

function main()
    @testset "♣ QUBOLib.jl «$(QUBOLib.__version__())» Test Suite ♣" verbose = true begin
        test_path()
        test_project_metadata()
        test_library_access()
        test_synthesis()
        test_readme()
        test_docs()
    end

    return nothing
end

main() # Here we go!
