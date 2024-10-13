# Database Design

In this section we discuss the decisions and specifications behind the construction of the database.

## Models and Solutions

The HDF5 file format is used to store the data. The data is stored in a hierarchical structure, which is a natural fit for the data. The data is stored in a tree-like structure, with the root group being the top level. The root group contains the following groups:

- `instances`: Contains the instances of the data.
- `solutions`: Contains the solutions to the instances.

## Collections

One of the core ideas behind [`QUBOLib`](https://github.com/JuliaQUBO/QUBOLib.jl) is to deploy other QUBO instance libraries in a bundle.
