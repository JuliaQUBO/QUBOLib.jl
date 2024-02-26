PRAGMA foreign_keys = ON;

CREATE TABLE Collections
(
  collection  TEXT    PRIMARY KEY,
  name        TEXT    NOT NULL   ,
  author      TEXT    NULL       ,
  year        INTEGER NULL       ,
  description TEXT    NULL       ,
  url         TEXT    NULL
);

CREATE TABLE Instances
(
  instance          INTEGER PRIMARY KEY,
  collection        TEXT    NOT NULL   ,
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
  instance INTEGER NOT NULL,
  solver   TEXT    NULL    ,
  value    REAL    NOT NULL,
  optimal  BOOLEAN NOT NULL,
  FOREIGN KEY (instance) REFERENCES Instances (instance) ON DELETE CASCADE,
  FOREIGN KEY (solver) REFERENCES Solvers (solver)
);

CREATE TABLE Solvers
(
  solver  TEXT    NOT NULL,
  quantum BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (solver)
);
