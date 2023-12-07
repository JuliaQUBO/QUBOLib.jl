function test_curation()
    @testset "□ Curation Routines" begin
        ENV["LAST_QUBOLIB_TAG"] = "v1.2.3"

        let index = QUBOLib.create_index(abspath(@__DIR__))

            @test index.root_path == abspath(@__DIR__)
            @test index.list_path == abspath(@__DIR__, "collections")
            @test index.dist_path == abspath(@__DIR__, "dist")

            QUBOLib.curate!(index)
            
            @test haskey(index.fp, "collections")

            QUBOLib.hash!(index)

            @test length(index.tree_hash[]) > 0

            QUBOLib.tag!(index)

            @test index.next_tag[] == "v1.2.4"
        end
    end

    return nothing
end
