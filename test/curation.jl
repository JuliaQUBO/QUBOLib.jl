function test_curation()
    @testset "□ Curation Routines" begin
        let index = QUBOInstances.create_index(
                abspath(@__DIR__, "data", "collections")
            )

            @test index.root_path == abspath(@__DIR__, "data", "collections")

        end
    end

    return nothing
end
