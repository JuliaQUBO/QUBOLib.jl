
CREATE TABLE Collections
(
  collection  TEXT    NOT NULL,
  name        TEXT    NOT NULL,
  author      TEXT    NULL    ,
  year        INTEGER NULL    ,
  description TEXT    NULL    ,
  url         TEXT    NULL    ,
  PRIMARY KEY (collection)
);

CREATE TABLE Instances
(
  instance          INTEGER NOT NULL,
  collection        TEXT    NOT NULL,
  min               REAL    NOT NULL,
  max               REAL    NOT NULL,
  abs_min           REAL    NOT NULL,
  abs_max           REAL    NOT NULL,
  linear_min        REAL    NOT NULL,
  linear_max        REAL    NOT NULL,
  quadratic_min     REAL    NOT NULL,
  quadratic_max     REAL    NOT NULL,
  density           REAL    NOT NULL,
  linear_density    REAL    NOT NULL,
  quadratic_density REAL    NOT NULL,
  PRIMARY KEY (instance)
);

CREATE TABLE Solutions
(
  solution INTEGER NOT NULL,
  instance INTEGER NOT NULL,
  solver   TEXT    NULL    ,
  value    REAL    NOT NULL,
  optimal  BOOLEAN NOT NULL,
  PRIMARY KEY (solution)
);

CREATE TABLE Solvers
(
  solver  TEXT    NOT NULL,
  quantum BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (solver)
);

ALTER TABLE Instances
  ADD CONSTRAINT FK_Collections_TO_Instances
    FOREIGN KEY (collection)
    REFERENCES Collections (collection)
    ON DELETE CASCADE;

ALTER TABLE Solutions
  ADD CONSTRAINT FK_Instances_TO_Solutions
    FOREIGN KEY (instance)
    REFERENCES Instances (instance)
    ON DELETE CASCADE;

ALTER TABLE Solutions
  ADD CONSTRAINT FK_Solvers_TO_Solutions
    FOREIGN KEY (solver)
    REFERENCES Solvers (solver);
