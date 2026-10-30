# Changelog

## Unreleased

## v0.2.6 - 2026-10-30

- Publish data release `v0.2.4-data+7` (Zenodo `10.5281/zenodo.23824873` under
  concept DOI `10.5281/zenodo.23027943`), adding the `mqlib` standard benchmark
  collection of 210 instances (`71` Stanford `G-set` Max-Cut, `60` `Beasley`
  QUBO, `45` `GKA` QUBO, `30` `spin-glass` Max-Cut, and `4` DIMACS `torus`
  Max-Cut, plus `21` deferred dense synthetic `Palubeckis` inventory entries),
  210 validated heuristic bitstring solutions, and 37 heuristic solver
  submissions from `MQLib/MQLib` commit
  `585496274af5abb0849d0d47e135496b4688680b` (#92, #93).
- Enrich all 6,502 instances across all 7 collections with
  `QUBOPreprocessing.jl` `v0.1.4` reduction metadata (`n_strong`, `m_strong`,
  `n_weak`, `m_weak`) and coercive local-field diagnostics (`coercive_fields`,
  `field_alignment`), solving 15 additional MQLib standard instances
  (`be50.1..10`, `gka.1a`, `gka.2a`, `gka.4a`, `gka.7c`, `gka.8a`) completely
  to zero residual variables (22 exact zero-residual ground states total) and
  repairing the `BURER2002` heuristic bitstring on `G70` ($n=10{,}000$,
  improving the Max-Cut objective from `9,492` to `9,500`; 32 repaired solution
  records total) (#92, #93).
- Add `Format(:mqlib_maxcut)`, `Format(:mqlib_qubo_maxcut)`,
  `Format(:mqlib_qubo)`, `load_mqlib!`, `build_mqlib!`, and `deploy_mqlib!` in
  `scripts/build/sources/mqlib.jl`.

## v0.2.5 - 2026-10-29

- Publish data release `v0.2.4-data+6` (Zenodo `10.5281/zenodo.23757887` under
  concept DOI `10.5281/zenodo.23027943`), applying the `0.5` quadratic scaling
  specification fix and cross-referenced `MINLPLib`/`BiqMac` optimality bounds
  to the 23 `QPLIB` instances (#88, #89), adding the `minlplib` collection of
  29 pure binary unconstrained QUBO instances (`42` solution records) (#88,
  #89), and enriching all 6,292 instances across all 6 collections with
  `QUBOPreprocessing.jl` `v0.1.2` (`integerize_scale = true`) reduction
  metadata (`n_strong`, `m_strong`, `n_weak`, `m_weak`), coercive local-field
  diagnostics (`coercive_fields`, `field_alignment`), 7 exact zero-residual
  ground states, and 31 repaired solution records (#86, #87, #90, #91).
- Publish data release `v0.2.4-data+5` (Zenodo `10.5281/zenodo.23745448` under
  concept DOI `10.5281/zenodo.23027943`), enriching all 6,263 instances with
  certified `QUBOPreprocessing.jl` `v0.1.2` reduction metadata (`n_strong`,
  `m_strong`, `n_weak`, `m_weak`) and adding 5 exact zero-residual ground
  states plus 33 repaired solution records (#85).
- Fix `DBInterface.execute` queries in `src/library/solvers.jl`.
- Pin the data importer to QOBLIB `16a166ee67c24c112551c803aab5394743b815b5`,
  including the merged Parallel ILS submission and later benchmark updates.
- Map canonical portfolio positions to the published QUBO ordering and match
  scientific-notation filenames to the upstream metrics table.
- Stage the next data artifact separately from the selected download for human
  review, and apply the documented Zenodo designated-owner exception.
- Run importer regression tests in CI.

## v0.2.4 - 2026-06-26

### Maintenance

- Expanded `QUBOTools` compatibility to include `0.16`.

## v0.2.3 - 2026-06-24

### Added

- Added schema-backed metadata validation for synthesized Wishart,
  Sherrington-Kirkpatrick, and NAE3SAT instances.

### Maintenance

- Expanded `PseudoBooleanOptimization` compatibility to include `0.3`.
- Expanded `QUBOTools` compatibility to include `0.15`.

## v0.2.2 - 2026-06-23

### Maintenance

- Expanded `QUBOTools` compatibility to include `0.14`.

## v0.2.1 - 2026-06-22

### Fixed

- Fixed mirror data release publishing.

### Maintenance

- Hardened TagBot workflow permissions for package release automation.
- Added release process guardrails, including a static package-release
  preflight script and Registrator release-note template.

## v0.2.0 - 2026-06-18

### Breaking changes

- No intentional API-breaking changes are documented. This is a pre-1.0 minor
  release because QOBLIB provenance, source-model metadata, and solution-record
  schema behavior changed.

### Added / Changed / Maintenance

- Added QOBLIB source-model provenance and source-objective evaluation support.
- Added nullable `source_objective`, `dual_bound`, and `source_feasible`
  fields to solution records, with migration support for existing artifacts.
- Updated QOBLIB documentation for canonical QS/QUBO ingestion and LP-only
  source-class provenance.

## v0.1.3 - 2026-06-03

- Added package and data release maintenance documentation.
- Documented the TagBot SSH deploy-key setup and safe manual recovery path for historical releases.
- Updated README installation and maintenance links for the registered package.
- Added public action/path API entries to the generated documentation.
- Wrapped callback-style `QUBOLib.access` calls in a SQLite savepoint so callback errors roll back transient database changes.

## v0.1.2 - 2026-06-03

- Registered QUBOLib `0.1.2` in General.
- Added dependency maintenance automation through Dependabot.
- Added TagBot automation for Julia package tags and releases.
- Updated GitHub Actions dependencies.
- Expanded compatibility for `JSON` and `QUBOTools`, including JSON-safe planted metadata for synthesized Wishart instances.

## v0.1.1 - 2026-06-03

- Registered QUBOLib `0.1.1` in General.
- Prepared package metadata and tests for the registered release flow.

## v0.1.0 - 2024-10-03

- Initial registered package release.
- Provided the QUBOLib SQLite/HDF5 access layer and artifact-backed benchmark library.
