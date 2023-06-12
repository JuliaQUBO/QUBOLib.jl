function _setup_index!(path::AbstractString; verbose::Bool = false)
    db_path = joinpath(path, "index.sqlite")

    db = SQLite.DB(db_path)

    DBInterface.execute(db, "PRAGMA foreign_keys = ON;")

    DBInterface.execute(db, "DROP TABLE IF EXISTS problems;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE problems (
            code TEXT PRIMARY KEY, -- Problem identifier
            name TEXT NOT NULL     -- Problem name
        );
        """
    )

    DBInterface.execute(db, "DROP TABLE IF EXISTS collections;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE collections (
            code TEXT    PRIMARY KEY, -- Collection identifier
            size INTEGER NOT NULL     -- Number of instances 
        );
        """
    )

    DBInterface.execute(db, "DROP TABLE IF EXISTS instances;")

    DBInterface.execute(
        db,
        """
        CREATE TABLE instances (
            code       TEXT    PRIMARY KEY, -- Instance identifier
            size       INTEGER NOT NULL,    -- Number of variables
            format     TEXT    NOT NULL,    -- File format
            problem    TEXT    NOT NULL,    -- Problem type
            collection TEXT    NOT NULL,    -- Collection identifier
            density            REAL,
            linear_density     REAL,
            quadratic_density  REAL,
            FOREIGN KEY (problem)    REFERENCES problems (code),
            FOREIGN KEY (collection) REFERENCES collections (code)
        );
        """
    )

    return nothing
end

function _build_index!(path::AbstractString)
    db_path = joinpath(path, "index.sqlite")

    db = SQLite.DB(db_path)

    DBInterface.execute(
        db,
        """
        INSERT INTO problems (code, name)
        VALUES
            ('3R3X', '3-Regular 3-XORSAT'),
            ('5R5X', '5-Regular 5-XORSAT'),
            ('QUBO', 'Quadratic Unconstrained Binary Optimization');
        """    
    )

    for collection in _list_collections(path)
        DBInterface.execute(
            db,
            """
            INSERT INTO collections (code, size)
            VALUES
                (?, 0);
            """,
            [collection]
        )

        coll_data = _metadata(path, collection)

        problem = get(coll_data, "problem", "QUBO")

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
                    (code, size, format, problem, collection, density, linear_density, quadratic_density)
                VALUES
                    (?, ?, ?, ?, ?, ?, ?, ?);
                """,
                [
                    instance,
                    inst_size,
                    inst_format,
                    problem,
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
            WHERE code = ?;
            """,
            [collection, collection]
        )
    end
end

function _index!(path::AbstractString; verbose::Bool = false)
    _setup_index!(path; verbose)
    _build_index!(path; verbose)

    return nothing
end