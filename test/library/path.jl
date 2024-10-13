raw"""
    test_path()

Test path-related functions:
- `QUBOLib.library_path`
- `QUBOLib.root_path`
- `QUBOLib.dist_path`
- `QUBOLib.build_path`
- `QUBOLib.cache_path`
"""
function test_path()
    @testset "→ Paths" begin
        mktempdir() do path
            @test abspath(QUBOLib.library_path(path)) == abspath(path, "qubolib") # path/qubolib

            @test abspath(QUBOLib.dist_path(path)) == abspath(path, "dist")           # path/dist
            @test abspath(QUBOLib.build_path(path)) == abspath(path, "dist", "build") # path/dist/build
            @test abspath(QUBOLib.cache_path(path)) == abspath(path, "dist", "cache") # path/dist/cache
            @test abspath(QUBOLib.cache_path(path, "collection")) == abspath(path, "dist", "cache", "collection") # path/dist/cache/collection
            @test abspath(QUBOLib.cache_data_path(path, "collection")) == abspath(path, "dist", "cache", "collection", "data") # path/dist/cache/collection
        end
    end

    return nothing
end
