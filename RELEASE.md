# Release Checklist

This repository has two release streams:

- Julia package releases, tagged as `vX.Y.Z` and registered in General.
- QUBOLib data artifact releases, tagged as `vX.Y.Z-data+N` and published by the `Deployment` workflow.

## Package Release

1. Open a release PR that bumps `version` in `Project.toml`.
2. Add a `CHANGELOG.md` section for `vX.Y.Z`.
3. Update `docs/Project.toml` self-compat for `QUBOLib` so it includes the
   target release line.
   - For `0.Y.Z`, include `0.Y`.
   - For `0.0.Z`, include `0.0.Z`.
   - For `X.Y.Z` with `X > 0`, include `X`.
4. Run the static package-release preflight:

   ```bash
   julia --project=. scripts/release_check.jl
   ```

5. Run the package tests and documentation build:

   ```bash
   julia --project=. -e 'import Pkg; Pkg.test()'
   julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
   julia --project=docs docs/make.jl --skip-deploy
   ```

6. Merge the release PR after CI is green.
7. Trigger Registrator on the merge commit using `release-notes-template.md`:

   ```bash
   gh api repos/JuliaQUBO/QUBOLib.jl/commits/<merge-sha>/comments -f body="$(cat release-notes-template.md)"
   ```

   The release notes for a pre-1.0 minor release should include a
   `Breaking changes` or `Changelog` section. General may label pre-1.0 minor
   releases as `BREAKING`, and AutoMerge requires one of those words in the
   release notes when that label is present.

8. Confirm the General registry PR merges:

   ```bash
   gh pr checks <general-pr-number> --repo JuliaRegistries/General --watch
   gh pr view <general-pr-number> --repo JuliaRegistries/General --json state,mergedAt,mergeCommit,url
   ```

9. Let TagBot create the package tag and GitHub release. If the package tag was
   created manually before TagBot ran, create the GitHub release manually too:

   ```bash
   gh release create vX.Y.Z --title "QUBOLib vX.Y.Z" --notes-file /path/to/notes.md --target <merge-commit>
   ```

7. Verify that `vX.Y.Z` points at the registered merge commit:

   ```bash
   git ls-remote --tags origin refs/tags/vX.Y.Z 'refs/tags/vX.Y.Z^{}'
   gh release view vX.Y.Z --repo JuliaQUBO/QUBOLib.jl
   ```

10. Verify `Pkg.add` from a fresh depot and project:

    ```bash
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/depot" "$tmp/proj"
    JULIA_DEPOT_PATH="$tmp/depot" julia --startup-file=no --project="$tmp/proj" -e 'using Pkg; Pkg.add("QUBOLib"); deps = Pkg.dependencies(); versions = [(pkg.name, pkg.version) for pkg in values(deps) if pkg.name == "QUBOLib"]; @show versions'
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
