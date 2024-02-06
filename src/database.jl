function _load_database(path::AbstractString)
    if !isfile(path)
        return nothing
    else
        return SQLite.DB(path)
    end
end

function _create_database(path::AbstractString)
    # Remove file if it exists
    rm(path; force=true)

    db = SQLite.DB(path)

    # Enable Foreign keys
    DBInterface.execute(db, "PRAGMA foreign_keys = ON;")

    # Collections
    DBInterface.execute(db, "DROP TABLE IF EXISTS collections;")
    DBInterface.execute(
        db,
        """
        CREATE TABLE collections (
            collection  TEXT PRIMARY KEY, -- Collection identifier
            author      TEXT            , -- Author
            description TEXT            , -- Description
            date        DATETIME        , -- Date of creation
            url         TEXT              -- URL
        );
        """
    )

    # Instances
    DBInterface.execute(db, "DROP TABLE IF EXISTS instances;")
    DBInterface.execute(
        db,
        """
        CREATE TABLE instances (
            instance          INTEGER PRIMARY KEY, -- Instance identifier
            collection        TEXT    NOT NULL   , -- Collection identifier
            dimension         INTEGER NOT NULL   , -- Number of variables
            min               REAL               , -- Minimum coefficient value
            max               REAL               , -- Maximum coefficient value
            abs_min           REAL               , -- Minimum absolute coefficient value
            abs_max           REAL               , -- Maximum absolute coefficient value
            linear_min        REAL               , -- Minimum linear coefficient
            linear_max        REAL               , -- Maximum linear coefficient
            quadratic_min     REAL               , -- Minimum quadratic coefficient
            quadratic_max     REAL               , -- Maximum quadratic coefficient
            density           REAL               , -- Coefficient density
            linear_density    REAL               , -- Linear coefficient density
            quadratic_density REAL               , -- Quadratic coefficient density

            FOREIGN KEY (collection) REFERENCES collections (collection)
        );
        """
    )

    # Solutions
    DBInterface.execute(db, "DROP TABLE IF EXISTS solutions;")
    DBInterface.execute(
        db,
        """
        CREATE TABLE solutions (
            solution INTEGER PRIMARY KEY, -- Solution identifier
            instance TEXT    NOT NULL   , -- Instance identifier
            vector   TEXT    NOT NULL   , -- Solution state
            
            FOREIGN KEY (instance) REFERENCES instances (instance)
        );
        """
    )

    return db
end
