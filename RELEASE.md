# Release Checklist

This repository has two release streams:

- Julia package releases, tagged as `vX.Y.Z` and registered in General.
- QUBOLib data artifact releases, tagged as `vX.Y.Z-data+N` and published by the `Deployment` workflow.

## Package Release

1. Open a release PR that bumps `version` in `Project.toml`.
2. Run the package tests and documentation build.
3. Merge the release PR after CI is green.
4. Tag the merge commit:

   ```bash
   git tag -a vX.Y.Z -m "QUBOLib vX.Y.Z" <merge-commit>
   git push origin vX.Y.Z
   ```

5. Trigger Registrator on the merge commit:

   ```text
   @JuliaRegistrator register
   ```

6. Confirm the General registry PR merges.
7. Confirm TagBot creates the GitHub release, or create it manually if TagBot opens an intervention issue.

## TagBot Setup

TagBot uses `secrets.SSH_KEY` in `.github/workflows/TagBot.yml`. The matching
public key must be installed as a write-enabled deploy key for this repository.
This is needed when TagBot must create package tags that also trigger other
workflows, such as documentation deployment.

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
