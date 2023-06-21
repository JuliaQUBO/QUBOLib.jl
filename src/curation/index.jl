function _setup_index!(path::AbstractString; verbose::Bool = false)
    verbose && @info "Setting up Index Database"

    db_path = joinpath(path, "index.sqlite")

    rm(db_path; force = true)

    db = SQLite.DB(db_path)

    DBInterface.execute(db, "PRAGMA foreign_keys = ON;")

    DBInterface.execute(db, "DROP TABLE IF EXISTS problems;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE problems (
            problem TEXT PRIMARY KEY, -- Problem identifier
            name    TEXT NOT NULL     -- Problem name
        );
        """
    )

    DBInterface.execute(db, "DROP TABLE IF EXISTS collections;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE collections (
            collection TEXT    PRIMARY KEY, -- Collection identifier
            problem    TEXT    NOT NULL,    -- Problem type
            size       INTEGER NOT NULL,    -- Number of instances 
            FOREIGN KEY (problem) REFERENCES problems (problem)
        );
        """
    )

    DBInterface.execute(db, "DROP TABLE IF EXISTS instances;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE instances (
            instance   TEXT    PRIMARY KEY, -- Instance identifier
            size       INTEGER NOT NULL,    -- Number of variables
            format     TEXT    NOT NULL,    -- File format
            collection TEXT    NOT NULL,    -- Collection identifier
            density            REAL,
            linear_density     REAL,
            quadratic_density  REAL,
            FOREIGN KEY (collection) REFERENCES collections (collection)
        );
        """
    )

    return nothing
end

function _build_index!(path::AbstractString; verbose::Bool = false)
    verbose && @info "Building Index Database"

    db_path = joinpath(path, "index.sqlite")

    db = SQLite.DB(db_path)

    DBInterface.execute(
        db,
        """
        INSERT INTO problems (problem, name)
        VALUES
            ('3R3X', '3-Regular 3-XORSAT'),
            ('5R5X', '5-Regular 5-XORSAT'),
            ('QUBO', 'Quadratic Unconstrained Binary Optimization');
        """    
    )

    for collection in _list_collections(path)
        coll_data = _metadata(path, collection)

        problem = get(coll_data, "problem", "QUBO")

        DBInterface.execute(
            db,
            """
            INSERT INTO collections (collection, problem, size)
            VALUES
                (?, ?, 0);
            """,
            [collection, problem]
        )

        for instance in _list_instances(path, collection)
            inst_path = joinpath(path, collection, "data", instance)

            inst_format = try
                QUBOTools.infer_format(inst_path)
            catch
                continue
            end

            model = try
                QUBOTools.read_model(inst_path, inst_format)
            catch
                continue
            end

            inst_size              = QUBOTools.domain_size(model)
            inst_density           = QUBOTools.density(model)
            inst_linear_density    = QUBOTools.linear_density(model)
            inst_quadratic_density = QUBOTools.quadratic_density(model)

            DBInterface.execute(
                db,
                """
                INSERT INTO instances
                    (instance, size, format, collection, density, linear_density, quadratic_density)
                VALUES
                    (?, ?, ?, ?, ?, ?, ?);
                """,
                [
                    instance,
                    inst_size,
                    inst_format,
                    collection,
                    inst_density,
                    inst_linear_density,
                    inst_quadratic_density,
                ]
            )
        end

        DBInterface.execute(
            db,
            """
            UPDATE collections
            SET size = (SELECT COUNT(*) FROM instances WHERE collection == ?)
            WHERE collection = ?;
            """,
            [collection, collection]
        )
    end

    return nothing
end

function _index!(path::AbstractString; verbose::Bool = false)
    _setup_index!(path; verbose)
    _build_index!(path; verbose)

    return nothing
end