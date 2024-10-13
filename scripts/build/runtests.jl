using Test

include("build.jl")

function test_tags()
    @testset "▶ Tags" begin
        @test next_data_tag("v0.1.0") == "v0.1.0-data+1"
        @test next_data_tag("v1.2.3-data+2") == "v1.2.3-data+3"
    end

    return nothing
end

function test_main()
    @testset "♦ QUBOLib.jl/scripts/build test suite ♦" verbose = true begin
        test_tags()
    end

    return nothing
end
