function create_database(path::AbstractString)
    rm(path; force=true) # remove file if it exists

    db = SQLite.DB(path)

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
            dimension  INTEGER NOT NULL,    -- Number of variables
            collection TEXT    NOT NULL,    -- Collection identifier
            min                REAL,        -- Minimum value
            max                REAL,        -- Maximum value
            linear_min         REAL,        -- Minimum linear coefficient
            linear_max         REAL,        -- Maximum linear coefficient
            quadratic_min      REAL,        -- Minimum quadratic coefficient
            quadratic_max      REAL,        -- Maximum quadratic coefficient
            density            REAL,        -- Coefficient density
            linear_density     REAL,        -- Linear coefficient density
            quadratic_density  REAL,        -- Quadratic coefficient density
            FOREIGN KEY (collection) REFERENCES collections (collection)
        );
        """
    )

    return db
end

function create_archive(path::AbstractString)
    rm(path; force=true) # remove file if it exists

    fp = HDF5.h5open(path, "w")

    HDF5.create_group(fp, "collections")

    return fp
end

struct InstanceIndex
    db::SQLite.DB
    fp::HDF5.File
    root_path::String
    dist_path::String
    list_path::String
end

function create_index(
    root_path::AbstractString,
    dist_path::AbstractString=abspath(root_path, "dist")
)
    mkpath(dist_path) # create dist directory if it doesn't exist

    db = create_database(joinpath(dist_path, "index.sqlite"))
    fp = create_archive(joinpath(dist_path, "archive.h5"))

    list_path = abspath(root_path, "collections")

    @assert isdir(list_path) "'$list_path' is not a directory"

    return InstanceIndex(db, fp, abspath(root_path), abspath(dist_path), list_path)
end

function _list_collections(path::AbstractString)
    return basename.(filter(isdir, readdir(path; join=true)))
end

function _list_collections(index::InstanceIndex)
    return _list_collections(index.list_path)
end

function _list_instances(path::AbstractString, collection::AbstractString)
    data_path = joinpath(path, collection, "data")

    @assert isdir(data_path) "'$data_path' is not a directory"

    return readdir(data_path; join=false)
end

function _list_instances(index::InstanceIndex, collection::AbstractString)
    return _list_instances(index.list_path, collection)
end

const _METADATA_SCHEMA = JSONSchema.Schema(JSON.parsefile(joinpath(@__DIR__, "metadata.schema.json")))

function _get_metadata(path::AbstractString, collection::AbstractString; validate::Bool=true)
    metapath = joinpath(path, collection, "metadata.json")
    metadata = JSON.parsefile(metapath)

    if validate
        report = JSONSchema.validate(_METADATA_SCHEMA, metadata)

        if !isnothing(report)
            error(
                """
                Invalid collection metadata for $(collection):
                $(report)
                """
            )
        end
    end

    return metadata
end

function _get_metadata(index::InstanceIndex, collection::AbstractString; validate::Bool=true)
    return _get_metadata(index.list_path, collection; validate=validate)
end

function _get_instance_model(path::AbstractString, collection::AbstractString, instance::AbstractString; on_read_error::Function=msg -> @warn(msg))
    model_path = abspath(path, collection, "data", instance)

    return try
        QUBOTools.read_model(model_path)
    catch
        on_read_error("Failed to read model at '$model_path'")

        nothing
    end
end

function _get_instance_model(index::InstanceIndex, collection::AbstractString, instance::AbstractString; on_read_error::Function=msg -> @warn(msg))
    return _get_instance_model(index.list_path, collection, instance; on_read_error)
end
