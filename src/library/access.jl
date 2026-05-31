const BEST_SOLUTIONS_VIEW_SQL = """
CREATE VIEW BestSolutions AS
SELECT *
FROM (
  SELECT
    r.*,
    ROW_NUMBER() OVER (
      PARTITION BY r.instance
      ORDER BY
        CASE
          WHEN lower(i.sense) = 'max' THEN -r.qubo_value
          ELSE r.qubo_value
        END ASC,
        r.proven_optimal DESC,
        CASE lower(r.validation_status)
          WHEN 'verified' THEN 3
          WHEN 'validated' THEN 2
          WHEN 'evaluated' THEN 1
          ELSE 0
        END DESC,
        CASE WHEN s.date IS NULL THEN 1 ELSE 0 END ASC,
        s.date ASC,
        r.record ASC
    ) AS incumbent_rank
  FROM SolutionRecords AS r
  JOIN Instances AS i
    ON i.instance = r.instance
  LEFT JOIN Submissions AS s
    ON s.submission = r.submission
  WHERE r.bitstring IS NOT NULL
    AND length(r.bitstring) = i.dimension
    AND r.bitstring NOT GLOB '*[^01]*'
    AND r.qubo_value IS NOT NULL
    AND r.qubo_value > -1.7976931348623157e308
    AND r.qubo_value <  1.7976931348623157e308
    AND lower(coalesce(r.validation_status, '')) IN ('evaluated', 'validated', 'verified')
    AND r.incumbent_candidate = TRUE
    AND lower(coalesce(r.feasibility_status, '')) IN ('feasible', 'validated', 'verified')
)
WHERE incumbent_rank = 1
"""

function access(callback::Any; path::AbstractString = pwd(), clear::Bool = false)
    index = access(; path, clear)

    @assert isopen(index)

    try
        # TODO: Start transaction here
        return callback(index)
    catch err
        # TODO: Implement some transaction rollback functionality!
        rethrow(err)
    finally
        # TODO: Close transaction here
        close(index)
    end
end

function access(; path::AbstractString = pwd(), clear::Bool = false)
    if !is_installed(path) || clear
        install(path; clear)
    end

    return load_index(path)
end

function is_installed(path::AbstractString)::Bool
    lib_path = library_path(path)

    return isdir(lib_path) && isfile(database_path(lib_path)) && isfile(archive_path(lib_path))
end

function install(path::AbstractString; clear::Bool = false)
    lib_path = library_path(path)

    if clear
        rm(lib_path; force = true, recursive = true)

        mkpath(lib_path)
    else
        mkpath(lib_path)

        for src_name in readdir(library_path())
            src_path = abspath(library_path(), src_name)
            dst_path = abspath(lib_path, src_name)

            cp(
                src_path,
                dst_path;
                force           = true,
                follow_symlinks = true,
            )

            chmod(dst_path, 0o644)
        end
    end

    return nothing
end

function load_index(path::AbstractString)
    lib_path = library_path(path)

    @assert isdir(lib_path)

    db = load_database(database_path(lib_path))
    h5 = load_archive(archive_path(lib_path))

    if isnothing(db) && isnothing(h5)
        # In this case, we have to create both
        return create_index(path)
    elseif isnothing(db) || isnothing(h5)
        error("QUBOLib Installation is compromised: Try running `access` with the `clear` argument set to `true`.")

        return nothing
    else
        return LibraryIndex(db, h5, lib_path)
    end
end

function create_index(path::AbstractString)
    # When building, $path is assumed to be pointing to dist/ or any other root path
    lib_path = library_path(path)

    @assert isdir(lib_path)

    db = create_database(database_path(lib_path))
    h5 = create_archive(archive_path(lib_path))

    return LibraryIndex(db, h5, lib_path)
end

function load_database(path::AbstractString)::Union{SQLite.DB,Nothing}
    if !isfile(path)
        return nothing
    else
        db = SQLite.DB(path)

        migrate_database!(db)

        return db
    end
end

function each_stmt(src::AbstractString)
    return Iterators.filter(!isempty, Iterators.map(strip, eachsplit(src, ';')))
end

function create_database(path::AbstractString)
    rm(path; force = true) # Remove file if it exists

    db = SQLite.DB(path)

    open(QUBOLIB_SQL_PATH) do file
        for stmt in each_stmt(read(file, String))
            DBInterface.execute(db, stmt)
        end
    end

    migrate_database!(db)

    return db
end

function _table_exists(db::SQLite.DB, table::AbstractString)::Bool
    df = DBInterface.execute(
        db,
        """
        SELECT COUNT(*) AS n
        FROM sqlite_master
        WHERE type IN ('table', 'view') AND name = ?;
        """,
        (String(table),),
    ) |> DataFrame

    return only(df[!, :n]) > 0
end

function _column_exists(db::SQLite.DB, table::AbstractString, column::AbstractString)::Bool
    df = DBInterface.execute(db, "PRAGMA table_info($(String(table)));") |> DataFrame

    return String(column) in string.(df[!, :name])
end

function _add_column_unless_exists!(
    db::SQLite.DB,
    table::AbstractString,
    column::AbstractString,
    definition::AbstractString,
)
    if _table_exists(db, table) && !_column_exists(db, table, column)
        DBInterface.execute(
            db,
            "ALTER TABLE $(String(table)) ADD COLUMN $(String(column)) $(String(definition));",
        )
    end

    return nothing
end

function _schema_sql(
    db::SQLite.DB,
    type::AbstractString,
    name::AbstractString,
)::Union{String,Nothing}
    df = DBInterface.execute(
        db,
        """
        SELECT sql
        FROM sqlite_master
        WHERE type = ? AND name = ?;
        """,
        (String(type), String(name)),
    ) |> DataFrame

    isempty(df) && return nothing

    sql = only(df[!, :sql])

    return ismissing(sql) ? nothing : String(sql)
end

function _normalize_schema_sql(sql::AbstractString)::String
    return join(split(strip(replace(String(sql), r";\s*$" => ""))), " ")
end

function _ensure_best_solutions_view!(db::SQLite.DB)
    current_sql = _schema_sql(db, "view", "BestSolutions")
    expected_sql = BEST_SOLUTIONS_VIEW_SQL

    if isnothing(current_sql) ||
       _normalize_schema_sql(current_sql) != _normalize_schema_sql(expected_sql)
        DBInterface.execute(db, "DROP VIEW IF EXISTS BestSolutions;")
        DBInterface.execute(db, expected_sql)
    end

    return nothing
end

function migrate_database!(db::SQLite.DB)
    DBInterface.execute(db, "PRAGMA foreign_keys = ON;")

    _add_column_unless_exists!(db, "Collections", "license", "TEXT NULL")
    _add_column_unless_exists!(db, "Collections", "data_license", "TEXT NULL")
    _add_column_unless_exists!(db, "Collections", "citation", "TEXT NULL")
    _add_column_unless_exists!(db, "Collections", "metadata", "TEXT NULL")

    _add_column_unless_exists!(db, "Instances", "sense", "TEXT NOT NULL DEFAULT 'min'")
    _add_column_unless_exists!(db, "Instances", "domain", "TEXT NOT NULL DEFAULT 'bool'")
    _add_column_unless_exists!(db, "Instances", "source_name", "TEXT NULL")
    _add_column_unless_exists!(db, "Instances", "problem_class", "TEXT NULL")
    _add_column_unless_exists!(db, "Instances", "formulation", "TEXT NULL")
    _add_column_unless_exists!(db, "Instances", "source_path", "TEXT NULL")
    _add_column_unless_exists!(db, "Instances", "source_commit", "TEXT NULL")
    _add_column_unless_exists!(db, "Instances", "original_filename", "TEXT NULL")
    _add_column_unless_exists!(db, "Instances", "source_url", "TEXT NULL")
    _add_column_unless_exists!(db, "Instances", "metadata", "TEXT NULL")

    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS Submissions
        (
          submission        INTEGER PRIMARY KEY,
          submitter         TEXT        NULL,
          date              TEXT        NULL,
          reference         TEXT        NULL,
          modeling_approach TEXT        NULL,
          workflow          TEXT        NULL,
          algorithm_type    TEXT        NULL,
          runs              INTEGER     NULL,
          feasible_runs     INTEGER     NULL,
          successful_runs   INTEGER     NULL,
          success_threshold REAL        NULL,
          hardware          TEXT        NULL,
          total_runtime     REAL        NULL,
          cpu_runtime       REAL        NULL,
          gpu_runtime       REAL        NULL,
          qpu_runtime       REAL        NULL,
          other_runtime     REAL        NULL,
          remarks           TEXT        NULL,
          source_path       TEXT        NULL,
          metadata          TEXT        NULL
        );
        """,
    )

    DBInterface.execute(
        db,
        """
        CREATE TABLE IF NOT EXISTS SolutionRecords
        (
          record              INTEGER PRIMARY KEY,
          instance            INTEGER NOT NULL,
          submission          INTEGER     NULL,
          solution            INTEGER     NULL,
          bitstring           TEXT        NULL,
          qubo_value          REAL        NULL,
          source_value        REAL        NULL,
          objective_bound     REAL        NULL,
          proven_optimal      BOOLEAN NOT NULL DEFAULT FALSE,
          feasibility_status  TEXT        NULL,
          validation_status   TEXT        NULL,
          incumbent_candidate BOOLEAN NOT NULL DEFAULT TRUE,
          source_path         TEXT        NULL,
          metadata            TEXT        NULL,
          FOREIGN KEY (instance)   REFERENCES Instances   (instance)   ON DELETE CASCADE,
          FOREIGN KEY (submission) REFERENCES Submissions (submission) ON DELETE SET NULL,
          FOREIGN KEY (solution)   REFERENCES Solutions   (solution)   ON DELETE SET NULL
        );
        """,
    )

    _ensure_best_solutions_view!(db)

    return nothing
end

function load_archive(
    path::AbstractString;
    mode::AbstractString = "cw",
)::Union{HDF5.File,Nothing}
    if !isfile(path)
        return nothing
    else
        return HDF5.h5open(path, mode)
    end
end

function create_archive(path::AbstractString)
    rm(path; force = true) # remove file if it exists

    h5 = HDF5.h5open(path, "w")

    HDF5.create_group(h5, "instances")
    HDF5.create_group(h5, "solutions")

    return h5
end
