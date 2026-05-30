# Introduction

## Mathematical Definitions

All instances have been recast into the binary, minimization form:

```math
\begin{array}{rll}
    \displaystyle
    \min_{\mathbf{x}} & \alpha \left[ \mathbf{x}' \mathbf{Q} \, \mathbf{x} + \mathbf{\ell}' \mathbf{x} + \beta \right] \\
    \textrm{s.t.}     & \mathbf{x} \in \mathbb{B}^{n} \\
\end{array}
```

where ``\mathbf{Q} \in \mathbb{R}^{n \times n}`` is an upper triangular matrix, ``\mathbf{\ell} \in \mathbb{R}^{n}`` is a vector, ``\alpha, \beta \in \mathbb{R}`` are scalars, and ``\mathbb{B}^{n}`` is the set of binary vectors of length ``n``.

## Benchmarking Physics-Inspired Optimization Solvers

QUBOLib is meant to make QUBO solver comparisons reproducible at the
benchmarking boundary: every solver output is compared as a full bitstring in
the imported QUBO variable order, and the comparison value is the locally
evaluated QUBO objective. This is useful for physics-inspired and heuristic
optimizers because the same instance can be attacked by simulated annealers,
quantum annealers, tensor-network heuristics, classical MIP solvers, or
source-domain codes while still being scored against one canonical QUBO model.

The library stores benchmark data in four related layers:

- `Instances` are the canonical QUBO models stored in the SQLite/HDF5 library.
  Their metadata is useful for selecting benchmark sets by collection,
  dimension, density, source name, problem class, or formulation.
- `Submissions` describe provenance for a run or reference source: who produced
  it, when, with which method, hardware, runtime, reporting context, source
  path, and supporting metadata.
- `SolutionRecords` store submitted or reference QUBO-space bitstrings, their
  computed `qubo_value`, optional `source_value`, validation and feasibility
  status, optimality claims, and links to submission provenance.
- `BestSolutions` is the curated incumbent view. It selects the current
  best-known valid incumbent record for each instance and is the comparison
  target exposed through `QUBOLib.best_solution_record` and
  `QUBOLib.load_best_solution`.

The canonical benchmark comparator is `qubo_value`: the value obtained by
evaluating the full bitstring against the QUBO model stored in QUBOLib. A
solution may originate from a source-domain solver, a classical MIP solve, a
QOBLIB reference solution, or another external workflow. It can still be used
for QUBO benchmarking once its state is mapped into the imported QUBO variable
order and validated against the stored QUBO model. `source_value` is provenance
only. It may differ from `qubo_value` because of source objective sign, offsets,
penalties, auxiliary variables, or formulation conventions, so benchmark tables
and gap calculations should use `qubo_value`.

### Incumbent comparison workflow

The usual workflow is:

1. Query the SQLite index for instances with the metadata needed by an
   experiment.
2. Load each QUBO model with `QUBOLib.load_instance`.
3. Convert the solver output to a binary vector or bitstring in the same
   variable order.
4. Evaluate the candidate with `QUBOTools.value`.
5. Load the incumbent record with `QUBOLib.best_solution_record`, and optionally
   load its stored sample set with `QUBOLib.load_best_solution`.
6. Compare the candidate value to the incumbent record's `qubo_value`.
7. Inspect `QUBOLib.list_solution_records` and the linked `Submissions` row when
   reporting provenance, feasibility, validation, or attribution.

The self-contained example below creates a tiny local benchmark library so the
workflow is exercised as part of the documentation build. In normal use, open
the packaged artifact with `QUBOLib.access()` and start from the SQL query. The
example selects one instance that has an incumbent, evaluates a candidate
bitstring, compares it with the incumbent `qubo_value`, and inspects the related
provenance. It uses SQLite.jl, DataFrames.jl, and QUBOTools.jl directly, so add
them to the active Julia project before running similar scripts.

```@example benchmarking-workflow
using QUBOLib
using SQLite, DataFrames
import QUBOTools

result = mktempdir() do root
    model = QUBOTools.Model(
        Dict(1 => 1.0, 2 => -2.0),
        Dict{Tuple{Int,Int},Float64}((1, 2) => 0.5),
    )

    QUBOLib.access(; path = root, clear = true) do index
        instance_id = QUBOLib.add_instance!(index, model; name = "tiny-benchmark")
        submission = QUBOLib.add_submission!(
            index;
            submitter = "example solver",
            workflow = "QUBO-space heuristic",
            hardware = "local CPU",
        )

        incumbent_solution = QUBOTools.SampleSet{Float64,Int}(
            model,
            [[0, 1]];
            metadata = Dict{String,Any}("status" => "best_known"),
        )
        QUBOLib.add_solution!(
            index,
            instance_id,
            incumbent_solution;
            submission,
            source_value = 123.0,
            validation_status = "validated",
        )

        db = QUBOLib.database(index)

        selected = DBInterface.execute(
            db,
            """
            SELECT i.instance, i.collection, i.name, i.dimension
            FROM Instances AS i
            JOIN BestSolutions AS b
              ON b.instance = i.instance
            ORDER BY i.dimension, i.instance
            LIMIT 1;
            """,
        ) |> DataFrame

        instance = only(selected[!, :instance])
        model = QUBOLib.load_instance(index, instance)

        incumbent_record = QUBOLib.best_solution_record(index, instance)
        incumbent_sample = QUBOLib.load_best_solution(index, instance)

        candidate_state = fill(0, only(selected[!, :dimension]))
        candidate_value = QUBOTools.value(model, candidate_state)

        incumbent_value = incumbent_record[:qubo_value]
        absolute_gap = candidate_value - incumbent_value
        relative_gap = absolute_gap / max(1.0, abs(incumbent_value))

        all_records = QUBOLib.list_solution_records(index, instance)
        provenance = if ismissing(incumbent_record[:submission])
            DataFrame()
        else
            DBInterface.execute(
                db,
                """
                SELECT submitter, date, reference, workflow, hardware, total_runtime
                FROM Submissions
                WHERE submission = ?;
                """,
                (incumbent_record[:submission],),
            ) |> DataFrame
        end

        return (
            candidate_value = candidate_value,
            incumbent_value = incumbent_value,
            incumbent_sample_value = QUBOTools.value(incumbent_sample, 1),
            absolute_gap = absolute_gap,
            relative_gap = relative_gap,
            records = size(all_records, 1),
            submitter = only(provenance[!, :submitter]),
        )
    end
end

result
```

For solver stacks such as QUBODrivers, or for any other package that returns a
QUBO-space state, keep the solver-specific call separate from the QUBOLib
comparison step. Once the solver output has been converted to a binary vector in
the variable order of `model`, the comparison is the same:

```julia
# candidate_state should be a Vector{Int} in the variable order of `model`.
candidate_value = QUBOTools.value(model, candidate_state)
incumbent_record = QUBOLib.best_solution_record(index, instance)
absolute_gap = candidate_value - incumbent_record[:qubo_value]
```

For the minimization QUBOs described above, smaller `qubo_value` values are
better, so a positive absolute gap means the candidate is worse than the current
incumbent. When writing generic reports, check the instance `sense` metadata and
apply the matching sign convention consistently.

`proven_optimal` records whether the incumbent is known or claimed to be
optimal, not whether every future solver comparison should stop there.
`validation_status` records whether the bitstring was evaluated, validated, or
verified against the stored model. `feasibility_status` records whether the
source workflow considered the result feasible, missing, unavailable,
withdrawn, unmapped, or invalid. QUBOLib keeps non-incumbent records so reports
can distinguish a high-quality validated incumbent from a rejected or
unmapped source-domain result.

QOBLIB-derived records should be attributed through their collection,
submission, source path, reference, and metadata fields. Their original
`source_value` is preserved when available, but QUBOLib benchmarking uses the
mapped bitstring and locally evaluated `qubo_value`.

## Table of Contents

1. [Basic Usage](./1-basic.md)
