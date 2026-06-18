# Release Checklist

This repository has two release streams:

- Julia package releases, tagged as `vX.Y.Z` and registered in General.
- QUBOLib data artifact releases, tagged as `vX.Y.Z-data+N` and published by the `Deployment` workflow.

## Package Release

1. Open a release PR that bumps `version` in `Project.toml`.
2. Run the package tests and documentation build.
3. Merge the release PR after CI is green.
4. Trigger Registrator on the merge commit, including release notes:

   ```markdown
   @JuliaRegistrator register

   Release notes:

   - ...
   ```

5. Confirm the General registry PR merges.
6. Let TagBot create the package tag and GitHub release. If the package tag was
   created manually before TagBot ran, create the GitHub release manually too:

   ```bash
   gh release create vX.Y.Z --title "QUBOLib vX.Y.Z" --notes-file /path/to/notes.md --target <merge-commit>
   ```

7. Verify that `vX.Y.Z` points at the registered merge commit:

   ```bash
   git ls-remote --tags origin refs/tags/vX.Y.Z 'refs/tags/vX.Y.Z^{}'
   gh release view vX.Y.Z --repo JuliaQUBO/QUBOLib.jl
   ```

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
  migrated in place when opened through `QUBOLib.access`.
- Instances may include an optional HDF5 source group at
  `/instances/{id}/source`. LP-backed source groups store `content`, an
  `encoding` JSON blob, a `source_format = "lp"` attribute, and source
  provenance attributes such as upstream repository, commit, path, URL,
  SHA-256 hash, byte size, and storage policy. QOBLIB LP source text is stored
  only when the blob is at most 1,000,000 bytes; larger blobs keep provenance
  and hash metadata without a `content` dataset.
