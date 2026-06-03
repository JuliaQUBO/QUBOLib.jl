# Changelog

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
