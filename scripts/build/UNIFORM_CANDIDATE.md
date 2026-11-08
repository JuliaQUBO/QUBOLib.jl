# Build a fresh uniform candidate

`uniform_candidate.jl` is the explicit clean-build route for benchmark issue #6.
It imports the original collections and runs the reviewed live preprocessing
component on every stored native Bool/Spin model. It uses registered
QUBOPreprocessing **0.2.1**, tree `5050a4197600cd99d6809b9c9ee9efe4f76a8b70`,
with the existing five-second soft preparation policy. It does not select a
published artifact or create a release.

Run only on Dantzig, from a clean committed builder in an isolated locked build
environment containing that checkout. Keep one Julia/native-library thread per
worker and place the process under the common resource launcher with verified
memory, swap and finite wall limits. Measure representative peak memory and
costs before choosing a full-build allocation. The command itself is serial;
there is no implicit worker pool or restart.

Prepare a frozen TOML plan outside the source checkout:

```toml
schema = "qubolib-uniform-candidate-v1"
builder_commit = "<full committed builder SHA>"
julia_version = "1.10.12"
project_sha256 = "<actual external build Project SHA256>"
manifest_sha256 = "<actual external build Manifest SHA256>"
qoblib_source = "/path/to/clean/QOBLIB/checkout"

[archives]
"arXiv-1903-10928-3r3x" = "/path/to/arXiv-1903-10928-3r3x.zip"
"arXiv-1903-10928-5r5x" = "/path/to/arXiv-1903-10928-5r5x.zip"
"arXiv-2103-08464-3r3x" = "/path/to/arXiv-2103-08464-3r3x.zip"
qplib = "/path/to/qplib.zip"
minlplib = "/path/to/minlplib.zip"
mqlib = "/path/to/mqlib.zip"
```

The QOBLIB checkout must be clean at the importer's exact source commit. All six
mirror hashes must match the checked-in importer pins. MINLPLib is read from its
verified mirror, without fetching live website replacements. The MQLib Tier-2
catalogue, result catalogues and all selected models must be present. Incomplete
collection imports fail the exact seven-collection/9,294-instance inventory gate.

```sh
julia --project=/path/to/locked-build-environment \
    scripts/build/uniform_candidate.jl /path/to/frozen-plan.toml /new/candidate
```

Every input is enriched, captured and repaired before its model/traces are
released; all inputs share the same pair of preprocessing submissions. The
original objective fingerprints, native domains and senses must remain equal.
Pipeline-only provenance, both mode reports, clean builder and identical package
and environment identities are checked before acceptance. Certification and
perturbation flags remain individual result properties: uniform provenance does
not turn an unverified result into a proof.

The destination must not exist. Any failed attempt remains available for
diagnosis, with no successful terminal receipt. Resume is deliberately unsupported;
restart in a new directory rather than skip a partly imported collection or append
another preprocessing history. The per-instance journal is progress evidence,
not a resume checkpoint or proof of completeness.

A successful directory contains the original-model identity inventory, journal,
producer plan, final `qubolib.tar.gz` and `terminal.json` with the verified builder,
member/archive SHA256 hashes and Git artifact tree. The archive contains only
`archive.h5` and `index.db`. Published DATASET/Artifacts metadata and old releases
remain untouched. Human review and the release/rights/publication checks in
`RELEASE.md` remain separate requirements before publishing the candidate.

Tiny integration/refusal checks:

```sh
julia --project=/path/to/locked-build-environment scripts/build/test_uniform_candidate.jl
julia --project=/path/to/locked-build-environment --load scripts/build/runtests.jl --eval 'test_main()'
```
