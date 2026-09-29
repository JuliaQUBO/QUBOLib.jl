# Release Checklist

This repository has two release streams:

- Julia package releases, tagged as `vX.Y.Z` and registered in General.
- QUBOLib data artifact releases, tagged as `vX.Y.Z-data+N`, normally published
  by the `Deployment` workflow. A locally audited candidate can instead be
  published unchanged after human review, as described below.

## Package Release

1. Open a release PR that bumps `version` in `Project.toml`.
2. Add a `CHANGELOG.md` section for `vX.Y.Z`.
3. Update `CITATION.cff` so `version` and `date-released` describe the target
   package release.
4. Update `docs/Project.toml` self-compat for `QUBOLib` so it includes the
   target release line.
   - For `0.Y.Z`, include `0.Y`.
   - For `0.0.Z`, include `0.0.Z`.
   - For `X.Y.Z` with `X > 0`, include `X`.
5. Run the static package-release preflight:

   ```bash
   julia --project=. scripts/release_check.jl
   ```

6. Confirm that `Artifacts.toml` selects the intended dataset version and
   matches `[artifact]` in `DATASET.toml`. For a preserved version, verify its
   Zenodo version DOI, file identity, and dataset reference in `CITATION.cff`;
   a Julia package version and a data-release version are different identifiers.
   Run the package tests and documentation build:

   ```bash
   julia --project=. -e 'import Pkg; Pkg.test()'
   julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
   julia --project=docs docs/make.jl --skip-deploy
   ```

7. Merge the release PR after CI is green.
8. Trigger Registrator on the merge commit using `release-notes-template.md`:

   ```bash
   gh api repos/JuliaQUBO/QUBOLib.jl/commits/<merge-sha>/comments -f body="$(cat release-notes-template.md)"
   ```

   The release notes for a pre-1.0 minor release should include a
   `Breaking changes` or `Changelog` section. General may label pre-1.0 minor
   releases as `BREAKING`, and AutoMerge requires one of those words in the
   release notes when that label is present.

9. Confirm the General registry PR merges:

   ```bash
   gh pr checks <general-pr-number> --repo JuliaRegistries/General --watch
   gh pr view <general-pr-number> --repo JuliaRegistries/General --json state,mergedAt,mergeCommit,url
   ```

10. Let TagBot create the package tag and GitHub release. If the package tag was
   created manually before TagBot ran, create the GitHub release manually too:

   ```bash
   gh release create vX.Y.Z --title "QUBOLib vX.Y.Z" --notes-file /path/to/notes.md --target <merge-commit>
   ```

11. Verify that `vX.Y.Z` points at the registered merge commit:

   ```bash
   git ls-remote --tags origin refs/tags/vX.Y.Z 'refs/tags/vX.Y.Z^{}'
   gh release view vX.Y.Z --repo JuliaQUBO/QUBOLib.jl
   ```

12. Verify `Pkg.add` from a fresh depot and project:

    ```bash
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/depot" "$tmp/proj"
    JULIA_DEPOT_PATH="$tmp/depot" julia --startup-file=no --project="$tmp/proj" -e 'using Pkg; Pkg.add("QUBOLib"); deps = Pkg.dependencies(); versions = [(pkg.name, pkg.version) for pkg in values(deps) if pkg.name == "QUBOLib"]; @show versions'
    ```

## Data Artifact Release

The GitHub data release and a Zenodo dataset version must contain the same
`qubolib.tar.gz` bytes. Rebuilding an equivalent index is not sufficient.

### Promote a reviewed candidate

Record the selected release under `[artifact]` in `DATASET.toml`; keep any
unpublished successor separate under `[candidate_artifact]`. Review the importer
and candidate inventory before publication. Use a new `-data+N` tag; never
reuse an existing tag or replace a published release asset.

1. Retain the locally built `qubolib.tar.gz` and verify its size, SHA-256, and
   extracted tree hash against `[candidate_artifact]`. If those bytes are lost,
   rebuild and repeat the audit; do not assume the old hashes still apply.
2. After human approval, publish those exact bytes to a new GitHub data release
   with an explicit reviewed target commit. Include the upstream cutoff,
   conversion notes, inventory, and hashes in the release notes. Do not run the
   ordinary `Deployment` workflow to promote this file: it rebuilds the corpus
   and replaces the source mirror release.
3. Download the new GitHub asset and verify it again. In a follow-up PR, promote
   its metadata into `[artifact]`, update the QOBLIB collection source/license
   links, update `Artifacts.toml` and `DATASET.md`, and remove the candidate
   section. Update the importer/docs consistency tests to use the selected
   collection pin instead of the removed candidate section. Confirm that the
   public download works and run the package tests and release preflight.
4. Use that selected release for the first Zenodo version below. Publishing the
   candidate is not part of the importer PR's automated human-review workflow.

### Archive the selected GitHub release

1. Select the GitHub data release to archive and audit its exact asset. Record
   the tag commit, compressed size, SHA-256, Julia artifact tree hash, archive
   members, collection counts, and instance counts in `DATASET.toml`.
2. For every populated collection, record its source snapshot or mirror hash,
   citation, license evidence, and redistribution-rights evidence. Do not infer
   a corpus-wide license from the repository's MIT software license or from one
   collection's terms.
3. Resolve every `zenodo.blocking_reasons` entry. Set each collection's
   `provenance_status` and `rights_status` to `verified` only when the supporting
   evidence is recorded.
4. Create or update the Zenodo draft using David Bernal's personal account.
   Verify his owner/manager access under the
   [designated-owner decision](https://github.com/JuliaQUBO/QUBOLib.jl/issues/70#issuecomment-5153545937).
   Do not share account credentials. Revisit backup management annually or
   whenever maintainership changes. Configure related identifiers for the repository,
   software, GitHub data release, upstream collections, and ecosystem article.
5. Upload the existing GitHub `qubolib.tar.gz` asset to the Zenodo draft without
   rebuilding or recompressing it. Download the draft file and verify byte
   identity against the selected GitHub asset. Record verified access, related
   identifiers, and byte identity in `DATASET.toml`, clear resolved blockers,
   set `zenodo.status = "ready"`, and run the publication gate:

   ```bash
   julia --project=. scripts/release_check.jl --require-dataset-publishable
   ```

   Do not publish while this command fails.

6. Publish the verified draft as the versioned Zenodo record.
7. Download the published Zenodo file, recompute its SHA-256 and artifact tree
   hash, and confirm they match `Artifacts.toml` and `DATASET.toml`.
8. Record the concept DOI, version DOI, verified byte identity, manager access,
   and related identifiers in `DATASET.toml`; set `zenodo.status = "published"`.
   Update `DATASET.md`, the dataset reference in `CITATION.cff`, and README/docs
   citation guidance, then rerun both release checks. Keep the CFF's software
   type, MIT license, and package version separate from the CC BY 4.0 dataset.
9. Verify both DOI.org links resolve to the intended record and record the
   result separately from Zenodo publication status. If registration is still
   pending, retain the direct record URL and leave the preservation issue open;
   do not republish or create a replacement record merely to retry resolution.

## TagBot Setup

TagBot uses `secrets.SSH_KEY` in `.github/workflows/TagBot.yml`. The matching
public key must be installed as a write-enabled deploy key for this repository.
This is needed when TagBot must create package tags that also trigger other
workflows, such as documentation deployment.

Verify the setup before relying on TagBot for a release:

```bash
gh api repos/JuliaQUBO/QUBOLib.jl/actions/secrets/SSH_KEY
gh api repos/JuliaQUBO/QUBOLib.jl/keys
```

If TagBot reports manual intervention for an old registered version whose tag is
missing, create the tag at the registered commit before creating the release.
For the historical `v0.1.0` registration, the registered commit is
`41087be73d756e95a2f6e8a307057af1f0c9fb0a`:

```bash
git tag -a v0.1.0 -m "QUBOLib v0.1.0" 41087be73d756e95a2f6e8a307057af1f0c9fb0a
git push origin v0.1.0
gh release create v0.1.0 --generate-notes --target 41087be73d756e95a2f6e8a307057af1f0c9fb0a
```

Do not run `gh release create v0.1.0` without an explicit target if the tag is
missing; that can create the release tag at the wrong commit.

## Data Artifact Schema Notes

- `SolutionRecords` includes nullable `source_objective`, `dual_bound`, and
  `source_feasible` columns for source-model evaluation. Existing artifacts are
  migrated in place when opened through `QUBOLib.access`. QOBLIB submission
  optimality bounds are written to `dual_bound`; `objective_bound` is retained
  with the same value for backward compatibility.
- Instances may include an optional HDF5 source group at
  `/instances/{id}/source`. LP-backed source groups store `content`, an
  `encoding` JSON blob, a `source_format = "lp"` attribute, and source
  provenance attributes such as upstream repository, commit, path, URL,
  SHA-256 hash, byte size, and storage policy. QOBLIB LP source text is stored
  only when the blob is at most 1,000,000 bytes; larger blobs keep provenance
  and hash metadata without a `content` dataset.
