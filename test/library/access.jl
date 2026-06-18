function test_library_access()
    @testset "→ Library access" begin
        mktempdir() do path
            model = QUBOLib.Synthesis.generate(QUBOLib.Synthesis.Wishart(8, 3))

            QUBOLib.access(; path, clear = true) do index
                instance = QUBOLib.add_instance!(index, model)
                loaded   = QUBOLib.load_instance(index, instance)

                @test QUBOTools.dimension(loaded) == QUBOTools.dimension(model)
                @test QUBOTools.density(loaded) ≈ QUBOTools.density(model)
                @test !isempty(QUBOTools.solution(model))
                @test QUBOLib.add_solution!(index, instance, QUBOTools.solution(model)) > 0
            end
        end
    end

    @testset "Solution records" begin
        mktempdir() do path
            model = QUBOTools.Model(
                Dict(1 => 1.0, 2 => 2.0, 3 => 4.0),
                Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5),
            )

            QUBOLib.access(; path, clear = true) do index
                instance = QUBOLib.add_instance!(index, model)

                late_submission = QUBOLib.add_submission!(
                    index;
                    submitter = "late",
                    date = "2026-01-02",
                )
                early_submission = QUBOLib.add_submission!(
                    index;
                    submitter = "early",
                    date = "2026-01-01",
                )

                invalid = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "000",
                    validation_status = "invalid",
                )
                infeasible = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "000",
                    feasibility_status = "infeasible",
                )
                unknown = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "000",
                )
                worse = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "100",
                    feasibility_status = "feasible",
                )
                late = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = late_submission,
                    bitstring = "000",
                    feasibility_status = "feasible",
                )
                early = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    submission = early_submission,
                    bitstring = "000",
                    source_objective = 1.25,
                    dual_bound = 0.75,
                    source_feasible = true,
                    feasibility_status = "feasible",
                )

                records = QUBOLib.list_solution_records(index, instance)

                @test size(records, 1) == 6
                @test Set(records[!, :record]) ==
                      Set([invalid, infeasible, unknown, worse, late, early])
                @test only(records[records.record .== unknown, :feasibility_status]) ==
                      "unknown"
                @test only(records[records.record .== early, :source_objective]) ≈
                      1.25
                @test only(records[records.record .== early, :dual_bound]) ≈ 0.75
                @test Bool(only(records[records.record .== early, :source_feasible]))

                best = QUBOLib.best_solution_record(index, instance)

                @test best[:record] == early
                @test best[:qubo_value] ≈ 0.0
                @test QUBOLib.load_best_solution(index, instance) === nothing

                sol = QUBOTools.SampleSet{Float64,Int}(
                    model,
                    [[0, 0, 0]];
                    metadata = Dict{String,Any}("status" => "optimal"),
                )
                solution = QUBOLib.add_solution!(index, instance, sol)
                loaded = QUBOLib.load_solution(index, instance, solution)

                @test !isempty(loaded)
                @test QUBOTools.state(loaded[1]) == [0, 0, 0]

                best = QUBOLib.best_solution_record(index, instance)
                loaded_best = QUBOLib.load_best_solution(index, instance)

                @test best[:solution] == solution
                @test QUBOTools.state(loaded_best[1]) == [0, 0, 0]
                @test QUBOTools.value(loaded_best, 1) ≈ QUBOTools.value(sol, 1)
                @test QUBOLib.JSON.parse(best[:metadata]) == QUBOTools.metadata(loaded_best)
            end
        end
    end

    @testset "Source formulations" begin
        mktempdir() do path
            model = QUBOTools.Model(
                Dict(1 => 1.0, 2 => 2.0),
                Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5),
            )
            source_text = """
            Minimize
             obj: x + 2 y
            Subject To
             c1: x + y <= 1
            Bounds
             0 <= x <= 1
             0 <= y <= 1
            Binary
             x y
            End
            """
            source_encoding = Dict{String,Any}(
                "variables" => Dict{String,Any}(
                    "x" => Dict{String,Any}(
                        "terms" => [Dict{String,Any}("index" => 1)],
                    ),
                    "y" => Dict{String,Any}(
                        "terms" => [Dict{String,Any}("index" => 2)],
                    ),
                ),
            )

            QUBOLib.access(; path, clear = true) do index
                instance = QUBOLib.add_instance!(
                    index,
                    model;
                    name = "source.lp",
                    source_format = "lp",
                    source_text,
                    source_encoding,
                )

                source_group =
                    QUBOLib.archive(index)["instances"][string(instance)]["source"]

                @test QUBOLib.HDF5.attrs(source_group)["source_format"] == "lp"
                @test read(source_group["content"]) == source_text
                @test QUBOLib.JSON.parse(read(source_group["encoding"])) ==
                      source_encoding

                source = QUBOLib.source_model(index, instance)
                variable_names = sort(QUBOLib.JuMP.name.(QUBOLib.JuMP.all_variables(source)))

                @test variable_names == ["x", "y"]

                assignment = QUBOLib.project_solution(index, instance, "10")

                @test assignment == Dict("x" => 1.0, "y" => 0.0)

                feasible = QUBOLib.evaluate_source(index, instance, "10")

                @test feasible.objective ≈ 1.0
                @test feasible.feasible
                @test isempty(feasible.violations)

                infeasible = QUBOLib.evaluate_source(index, instance, "11")

                @test infeasible.objective ≈ 3.0
                @test !infeasible.feasible
                @test length(infeasible.violations) == 1
                @test only(infeasible.violations).violation ≈ 1.0
            end
        end
    end

    @testset "Collection and instance metadata" begin
        mktempdir() do path
            model = QUBOTools.Model(
                Dict(1 => 1.0, 2 => -2.0),
                Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5),
            )

            QUBOLib.access(; path, clear = true) do index
                QUBOLib.add_collection!(
                    index,
                    "metadata-test",
                    Dict{String,Any}(
                        "name"         => "Metadata Test",
                        "author"       => ["QUBOLib"],
                        "license"      => "Apache-2.0",
                        "data_license" => "CC-BY-4.0",
                        "citation"     => "example citation",
                        "metadata"     => Dict{String,Any}("source" => "fixture"),
                    ),
                )

                instance = QUBOLib.add_instance!(
                    index,
                    model,
                    "metadata-test";
                    name              = "fixture.qs.xz",
                    source_name       = "QOBLIB",
                    problem_class     = "Fixture",
                    formulation       = "binary_unconstrained",
                    source_path       = "fixture/fixture.qs.xz",
                    source_commit     = "abc123",
                    original_filename = "fixture.qs.xz",
                    source_url        = "https://example.test/fixture.qs.xz",
                    metadata          = Dict{String,Any}("source_name" => "QOBLIB"),
                )

                collections =
                    QUBOLib.DBInterface.execute(
                        QUBOLib.database(index),
                        "SELECT license, data_license, citation, metadata FROM Collections WHERE collection = ?;",
                        ("metadata-test",),
                    ) |> QUBOLib.DataFrame

                instances =
                    QUBOLib.DBInterface.execute(
                        QUBOLib.database(index),
                        """
                        SELECT source_name, problem_class, formulation, source_path,
                               source_commit, original_filename, source_url, metadata
                        FROM Instances
                        WHERE instance = ?;
                        """,
                        (instance,),
                    ) |> QUBOLib.DataFrame

                @test only(collections[!, :license]) == "Apache-2.0"
                @test only(collections[!, :data_license]) == "CC-BY-4.0"
                @test only(collections[!, :citation]) == "example citation"
                @test QUBOLib.JSON.parse(only(collections[!, :metadata]))["source"] ==
                      "fixture"

                @test only(instances[!, :source_name]) == "QOBLIB"
                @test only(instances[!, :problem_class]) == "Fixture"
                @test only(instances[!, :formulation]) == "binary_unconstrained"
                @test only(instances[!, :source_path]) == "fixture/fixture.qs.xz"
                @test only(instances[!, :source_commit]) == "abc123"
                @test only(instances[!, :original_filename]) == "fixture.qs.xz"
                @test only(instances[!, :source_url]) ==
                      "https://example.test/fixture.qs.xz"
                @test QUBOLib.JSON.parse(only(instances[!, :metadata]))["source_name"] ==
                      "QOBLIB"
            end
        end
    end

    @testset "Callback transactions" begin
        mktempdir() do path
            @test_throws ErrorException QUBOLib.access(; path, clear = true) do index
                QUBOLib.add_collection!(
                    index,
                    "rolled-back",
                    Dict{String,Any}(
                        "name" => "Rolled Back",
                        "author" => ["QUBOLib"],
                    ),
                )

                error("abort transaction")
            end

            QUBOLib.access(; path) do index
                collections =
                    QUBOLib.DBInterface.execute(
                        QUBOLib.database(index),
                        "SELECT collection FROM Collections WHERE collection = ?;",
                        ("rolled-back",),
                    ) |> QUBOLib.DataFrame

                @test isempty(collections)
            end
        end

        mktempdir() do path
            QUBOLib.access(; path, clear = true) do index
                QUBOLib.add_collection!(
                    index,
                    "closed-savepoint",
                    Dict{String,Any}(
                        "name" => "Closed Savepoint",
                        "author" => ["QUBOLib"],
                    ),
                )

                close(index)
            end

            QUBOLib.access(; path) do index
                collections =
                    QUBOLib.DBInterface.execute(
                        QUBOLib.database(index),
                        "SELECT collection FROM Collections WHERE collection = ?;",
                        ("closed-savepoint",),
                    ) |> QUBOLib.DataFrame

                @test size(collections, 1) == 1
            end
        end
    end

    @testset "Best solution sense" begin
        mktempdir() do path
            model = QUBOTools.Model(
                Dict(1 => 1.0, 2 => 2.0),
                Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5);
                sense = :max,
            )

            QUBOLib.access(; path, clear = true) do index
                instance = QUBOLib.add_instance!(index, model)
                low = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    bitstring = "00",
                    feasibility_status = "feasible",
                )
                high = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    bitstring = "10",
                    feasibility_status = "feasible",
                )
                best = QUBOLib.best_solution_record(index, instance)

                @test best[:record] == high
                @test best[:record] != low
            end
        end
    end

    @testset "Legacy index migration" begin
        mktempdir() do path
            _create_legacy_index(path)

            model = QUBOTools.Model(
                Dict(1 => 1.0, 2 => 2.0),
                Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5),
            )

            QUBOLib.access(; path) do index
                instance = QUBOLib.add_instance!(index, model)
                unknown = QUBOLib.add_solution_record!(index, instance; bitstring = "00")
                record = QUBOLib.add_solution_record!(
                    index,
                    instance;
                    bitstring = "00",
                    feasibility_status = "feasible",
                )
                records = QUBOLib.list_solution_records(index, instance)
                best = QUBOLib.best_solution_record(index, instance)
                collection_columns = QUBOLib.DBInterface.execute(
                    QUBOLib.database(index),
                    "PRAGMA table_info(Collections);",
                ) |> QUBOLib.DataFrame
                instance_columns = QUBOLib.DBInterface.execute(
                    QUBOLib.database(index),
                    "PRAGMA table_info(Instances);",
                ) |> QUBOLib.DataFrame
                solution_record_columns = QUBOLib.DBInterface.execute(
                    QUBOLib.database(index),
                    "PRAGMA table_info(SolutionRecords);",
                ) |> QUBOLib.DataFrame

                @test size(records, 1) == 2
                @test Set(records[!, :record]) == Set([unknown, record])
                @test best[:record] == record
                @test all(
                    column in string.(collection_columns[!, :name]) for
                    column in ("license", "data_license", "citation", "metadata")
                )
                @test all(
                    column in string.(instance_columns[!, :name]) for column in (
                        "source_name",
                        "problem_class",
                        "formulation",
                        "source_path",
                        "source_commit",
                        "original_filename",
                        "source_url",
                        "metadata",
                    )
                )
                @test all(
                    column in string.(solution_record_columns[!, :name]) for
                    column in ("source_objective", "dual_bound", "source_feasible")
                )
            end
        end
    end

    return nothing
end

function _create_legacy_index(path::AbstractString)
    lib_path = QUBOLib.library_path(path)

    mkpath(lib_path)

    db = QUBOLib.SQLite.DB(QUBOLib.database_path(lib_path))

    try
        for stmt in QUBOLib.each_stmt(_legacy_schema())
            QUBOLib.DBInterface.execute(db, stmt)
        end
    finally
        close(db)
    end

    h5 = QUBOLib.HDF5.h5open(QUBOLib.archive_path(lib_path), "w")

    try
        QUBOLib.HDF5.create_group(h5, "instances")
        QUBOLib.HDF5.create_group(h5, "solutions")
    finally
        close(h5)
    end

    return nothing
end

function _legacy_schema()
    return """
    PRAGMA foreign_keys = ON;

    CREATE TABLE Collections
    (
      collection  TEXT    PRIMARY KEY,
      name        TEXT    NOT NULL   ,
      author      TEXT        NULL   ,
      year        INTEGER     NULL   ,
      description TEXT        NULL   ,
      url         TEXT        NULL
    );

    INSERT INTO Collections
      (collection, name, author, year, description, url)
    VALUES
      (
        'standalone',
        'Standalone',
        NULL,
        NULL,
        'Standalone instances',
        NULL
      );

    CREATE TABLE Instances
    (
      instance          INTEGER PRIMARY KEY,
      collection        TEXT    NOT NULL   ,
      name              TEXT        NULL   ,
      dimension         INTEGER NOT NULL   ,
      min               REAL    NOT NULL   ,
      max               REAL    NOT NULL   ,
      abs_min           REAL    NOT NULL   ,
      abs_max           REAL    NOT NULL   ,
      linear_min        REAL    NOT NULL   ,
      linear_max        REAL    NOT NULL   ,
      quadratic_min     REAL    NOT NULL   ,
      quadratic_max     REAL    NOT NULL   ,
      density           REAL    NOT NULL   ,
      linear_density    REAL    NOT NULL   ,
      quadratic_density REAL    NOT NULL   ,
      FOREIGN KEY (collection) REFERENCES Collections (collection) ON DELETE CASCADE
    );

    CREATE TABLE Solutions
    (
      solution INTEGER PRIMARY KEY,
      instance INTEGER NOT NULL   ,
      solver   TEXT        NULL   ,
      value    REAL    NOT NULL   ,
      optimal  BOOLEAN NOT NULL   ,
      FOREIGN KEY (instance) REFERENCES Instances (instance) ON DELETE CASCADE,
      FOREIGN KEY (solver)   REFERENCES Solvers (solver)
    );

    CREATE TABLE Solvers
    (
      solver      TEXT PRIMARY KEY,
      version     TEXT        NULL,
      description TEXT        NULL
    );
    """
end
