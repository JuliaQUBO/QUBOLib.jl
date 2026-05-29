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

INSERT INTO Collections
  (collection, name, author, year, description, url)
VALUES
  (
    'qubolib',
    'QUBOLib',
    'Pedro Maciel Xavier and David E. Bernal Neira',
    '2024',
    'QUBOLib Synthetic Instances',
    'https://juliaqubo.github.io/QUBOLib.jl'
  );

CREATE TABLE Instances
(
  instance          INTEGER PRIMARY KEY,
  collection        TEXT    NOT NULL   ,
  name              TEXT        NULL   ,
  dimension         INTEGER NOT NULL   ,
  sense             TEXT    NOT NULL DEFAULT 'min',
  domain            TEXT    NOT NULL DEFAULT 'bool',
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

CREATE TABLE Submissions
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

CREATE TABLE SolutionRecords
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
    AND lower(coalesce(r.feasibility_status, '')) NOT IN ('invalid', 'infeasible', 'withdrawn', 'unmapped')
)
WHERE incumbent_rank = 1;
