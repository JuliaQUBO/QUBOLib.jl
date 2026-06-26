# Changelog

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
