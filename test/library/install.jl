function _with_install_artifact(
    callback;
    source_parts = ("artifact-parent", "qubolib"),
    materialize = true,
)
    mktempdir() do root
        source = joinpath(root, source_parts...)
        if materialize
            mkpath(source)
            write(joinpath(source, "index.db"), "fixture database\n")
            write(joinpath(source, "archive.h5"), "fixture archive\n")
        end

        depot = mkpath(joinpath(root, "depot", "artifacts"))
        open(joinpath(depot, "Overrides.toml"), "w") do io
            QUBOLib.TOML.print(io, Dict(
                string(Base.PkgId(QUBOLib).uuid) => Dict("qubolib" => source),
            ))
        end

        original_depots = copy(DEPOT_PATH)
        pushfirst!(DEPOT_PATH, dirname(depot))
        QUBOLib.Pkg.Artifacts.load_overrides(; force = true)
        try
            if materialize
                @test realpath(QUBOLib.library_path()) == realpath(source)
            else
                @test QUBOLib._library_artifact_path() == source
            end
            callback(root, source)
        finally
            empty!(DEPOT_PATH)
            append!(DEPOT_PATH, original_depots)
            QUBOLib.Pkg.Artifacts.load_overrides(; force = true)
        end
    end
end

function _with_install_downloads_forbidden(callback)
    downloads = QUBOLib.Pkg.PlatformEngines.Downloads
    original_downloader = downloads.DOWNLOADER[]
    original_hook = downloads.EASY_HOOK[]
    attempts = Ref(0)
    reject_download = (easy, info) -> begin
        attempts[] += 1
        error("Artifact installation must not download in this fixture")
    end
    downloader = downloads.Downloader(; grace = 0)
    downloader.easy_hook = reject_download
    downloads.EASY_HOOK[] = reject_download
    downloads.default_downloader!(downloader)
    try
        # Downloads runs this hook before adding the transfer to libcurl.
        callback(attempts)
    finally
        downloads.default_downloader!(original_downloader)
        downloads.EASY_HOOK[] = original_hook
    end
end

function _install_fixture_snapshot(source)
    snapshot = Dict{String,Union{Nothing,Vector{UInt8}}}()
    for (root, dirs, files) in walkdir(source)
        for name in dirs
            snapshot[relpath(joinpath(root, name), source)] = nothing
        end
        for name in files
            snapshot[relpath(joinpath(root, name), source)] = read(joinpath(root, name))
        end
    end
    return snapshot
end

function test_library_install()
    @testset "→ Install preserves the packaged artifact" begin
        _with_install_downloads_forbidden() do attempts
            _with_install_artifact(; materialize = false) do root, source
                @test !ispath(source)

                working = joinpath(root, "empty-install")
                QUBOLib.install(working; clear = true)
                @test isdir(joinpath(working, "qubolib"))
                @test isempty(readdir(joinpath(working, "qubolib")))
                @test !ispath(source)

                working = joinpath(root, "empty-access")
                QUBOLib.access(; path = working, clear = true) do index
                    @test isopen(index)
                end
                @test QUBOLib.is_installed(working)
                @test !ispath(source)
                @test attempts[] == 0
            end
        end

        _with_install_artifact() do root, source
            before = _install_fixture_snapshot(source)
            for clear in (false, true)
                for path in (dirname(source), source, joinpath(source, "missing", "child"))
                    @test_throws ArgumentError QUBOLib.install(path; clear)
                    @test _install_fixture_snapshot(source) == before
                end
                cd(root) do
                    @test_throws ArgumentError QUBOLib.install(relpath(source, root); clear)
                end
                @test !ispath(joinpath(source, "missing"))
                # The source already looks installed at its parent. access must
                # reject it before load_index could migrate the artifact's DB.
                @test_throws ArgumentError QUBOLib.access(; path = dirname(source), clear)
                @test _install_fixture_snapshot(source) == before
            end

            # A sibling sharing a string prefix remains a valid working directory.
            working = joinpath(dirname(source), "qubolib-sibling")
            QUBOLib.install(working)
            @test read(joinpath(working, "qubolib", "index.db")) == read(joinpath(source, "index.db"))
            @test read(joinpath(working, "qubolib", "archive.h5")) == read(joinpath(source, "archive.h5"))
            @test _install_fixture_snapshot(source) == before
            QUBOLib.install(working; clear = true)
            @test isempty(readdir(joinpath(working, "qubolib")))
            @test _install_fixture_snapshot(source) == before
        end

        _with_install_artifact(; source_parts = ("qubolib", "artifact")) do root, source
            before = _install_fixture_snapshot(source)
            for clear in (false, true)
                @test_throws ArgumentError QUBOLib.install(root; clear)
                @test _install_fixture_snapshot(source) == before
            end
        end

        _with_install_artifact() do root, source
            before = _install_fixture_snapshot(source)
            external = mkpath(joinpath(root, "external"))
            aliased_destination = mkpath(joinpath(root, "aliased-destination"))
            nested = mkpath(joinpath(source, "nested"))
            source_alias = joinpath(root, "source-alias")
            try
                symlink(source, source_alias; dir_target = true)
            catch err
                Sys.iswindows() && err isa Base.IOError || rethrow()
                @test_skip false # Windows may deny unprivileged symlinks.
                return
            end
            symlink(nested, joinpath(external, "through"); dir_target = true)
            symlink(source, joinpath(aliased_destination, "qubolib"); dir_target = true)
            symlink(joinpath(source, "not-created"), joinpath(external, "dangling"); dir_target = true)
            symlink(joinpath(external, "cycle"), joinpath(external, "cycle"); dir_target = true)
            before = _install_fixture_snapshot(source)

            for clear in (false, true)
                for path in (
                    source_alias,
                    joinpath(source_alias, "new", "child"),
                    aliased_destination,
                    joinpath(external, "through", ".."),
                    joinpath(external, "missing", "..", "through", ".."),
                    joinpath(external, "dangling"),
                    joinpath(external, "cycle"),
                )
                    @test_throws ArgumentError QUBOLib.install(path; clear)
                    @test _install_fixture_snapshot(source) == before
                end
                @test !ispath(joinpath(external, "missing"))
                @test islink(joinpath(aliased_destination, "qubolib"))
            end
        end

        _with_install_artifact() do root, source
            before = _install_fixture_snapshot(source)
            working = mkpath(joinpath(root, "working"))
            external = mkpath(joinpath(root, "external-copy"))
            try
                symlink(external, joinpath(working, "qubolib"); dir_target = true)
            catch err
                Sys.iswindows() && err isa Base.IOError || rethrow()
                @test_skip false
                return
            end
            QUBOLib.install(working)
            @test read(joinpath(external, "index.db")) == read(joinpath(source, "index.db"))
            @test islink(joinpath(working, "qubolib"))
            QUBOLib.install(working; clear = true)
            @test !islink(joinpath(working, "qubolib"))
            @test isempty(readdir(joinpath(working, "qubolib")))
            @test read(joinpath(external, "archive.h5")) == read(joinpath(source, "archive.h5"))
            @test _install_fixture_snapshot(source) == before
        end
    end
    return nothing
end
