# Release strategy: versions, tags, GitHub Releases

How this repo releases, why, and the alternatives interviewers ask you to compare. Everything here is runnable: `scripts/next-version.sh`, `scripts/release.sh`, `.github/workflows/release.yml`.

## The flow in this repo

```
commit (Conventional Commits) ──> main ──> ./scripts/release.sh
                                              │  computes next semver from commits since the last tag
                                              │  prepends CHANGELOG.md, commits "chore(release): vX.Y.Z"
                                              │  creates ANNOTATED tag vX.Y.Z (message = release notes)
                                              ▼
                     git push origin main --follow-tags
                                              │
                                              ▼
                     release.yml (on: push tags v*.*.*)
                       guard: tag is annotated and on main
                       build + test with -PreleaseVersion=X.Y.Z  (version comes from the tag, not a file)
                       jar + sha256, provenance attestation
                       image ghcr.io/<owner>/<repo>:X.Y.Z and :X.Y, image attestation
                       gh release create vX.Y.Z  (notes = tag annotation, assets = jar + checksum)
```

Try it locally without pushing anything:

```bash
./scripts/next-version.sh          # prints the next version, exit 2 if nothing release-worthy
./scripts/release.sh --dry-run     # shows version + notes, changes nothing
bash scripts/test-release-scripts.sh   # 10 assertions in a throwaway repo
```

## Semantic Versioning (MAJOR.MINOR.PATCH)

| Change | Bump | Conventional Commit that triggers it |
|---|---|---|
| Incompatible API change | MAJOR | `feat!: ...`, `fix(api)!: ...`, or a `BREAKING CHANGE:` footer |
| New backwards-compatible feature | MINOR | `feat: ...` |
| Backwards-compatible bug fix | PATCH | `fix: ...`, `perf: ...` |
| No release | none | `chore:`, `docs:`, `test:`, `ci:`, `refactor:`, `build:`, `style:` |

- Pre-releases sort before the release: `1.4.0-rc.1 < 1.4.0`. Jenkins builds here use `X.Y.Z-build.N` so CI artifacts never collide with a real release.
- `0.y.z` means "anything may change"; many teams start at `0.1.0` and go to `1.0.0` when the API is public.
- **Build metadata** (`+sha.abc123`) is ignored for precedence; useful for traceability, not ordering.
- Alternatives: **CalVer** (`2026.11.1`, used by Ubuntu, pip) for products where "how old is it" matters more than compatibility; **build numbers** for apps nobody depends on as a library.

## Git tags

| | Lightweight | Annotated |
|---|---|---|
| What it is | A ref pointing at a commit | A full object: tagger, date, message, optional signature |
| Create | `git tag v1.2.0` | `git tag -a v1.2.0 -m "Release v1.2.0"` |
| `git describe` default | ignored | used |
| `git push --follow-tags` | not pushed | pushed |
| Use for | local bookmarks | **releases** |

Commands you should know cold:

```bash
git tag -a v1.2.0 -m "Release v1.2.0"            # annotated
git tag -s v1.2.0 -m "Release v1.2.0"            # signed (GPG/SSH); verify with git tag -v v1.2.0
git push origin v1.2.0                           # push one tag
git push origin main --follow-tags               # push branch + annotated tags reachable from it
git describe --tags --abbrev=0                   # latest tag reachable from HEAD
git log v1.1.0..v1.2.0 --oneline                 # what's in this release
git tag -l 'v1.*' --sort=-v:refname              # list, newest first by version
git tag -l --format='%(contents:body)' v1.2.0    # read the annotation (release notes)
git push origin :refs/tags/v1.2.0                # delete remote tag - avoid after release
```

**Never move or re-use a published tag.** Consumers, caches and provenance all assume `v1.2.0` means one commit forever. If a release is bad, ship `v1.2.1`. Protect `v*` tags with a **tag ruleset** (repository rulesets replaced the legacy tag protection rules in 2024) so only the release workflow or maintainers can create them and nobody can delete or update them.

## GitHub Releases

- A Release is GitHub metadata on top of a tag: title, notes, assets (binaries, checksums, SBOMs), pre-release and "latest" flags.
- Create one: UI, `gh release create v1.2.0 --notes-file notes.md --verify-tag dist/*`, the REST API, or an action.
- `--generate-notes` builds notes from merged PRs since the previous release; categories come from `.github/release.yml`.
- **Draft** releases let you upload assets and review notes before publishing. **Immutable releases** (GitHub, 2025) lock the tag and assets once published — turn them on for anything others download.
- Provenance: `actions/attest-build-provenance` signs a SLSA provenance statement for the jar and image; consumers verify with `gh attestation verify cicd-demo-1.2.0.jar --repo <owner>/<repo>`.
- Gotcha: a tag pushed **by a workflow using `GITHUB_TOKEN` does not trigger other workflows** (to prevent loops). If release.sh ran inside Actions, use a GitHub App token or call the release job directly instead of relying on `on: push: tags`.

## Who decides the version?

| Approach | How | Trade-off |
|---|---|---|
| Commits decide (this repo) | Conventional Commits → semver (`semantic-release`, `release-please`, our script) | Fully automatic; needs commit discipline (enforce with commitlint in CI) |
| Release PR | `release-please` opens a PR with the version bump + changelog; merging it tags | Human review of every release; great for libraries |
| Human decides | Maintainer runs `release.sh` or creates the tag | Simple; inconsistent without a checklist |
| Version file | `version=1.2.0` in `gradle.properties`, bumped by PR | Easy to read; merge conflicts, easy to forget |

This repo derives the version from the tag at build time (`-PreleaseVersion`), so there is no version file to forget.

## Branching models and how releases fit

| Model | Releases come from | Fits |
|---|---|---|
| **Trunk-based** (short-lived branches, feature flags) | Tags on `main` | Services deployed many times a day. This repo. |
| **Release branches** (`release/1.4`) | Tags on the release branch; fixes cherry-picked from `main` | Products supporting several versions at once (on-prem, mobile, SDKs) |
| **GitFlow** (`develop`, `release/*`, `hotfix/*`, `main`) | Merges to `main` | Scheduled releases; heavy for continuous delivery, and its author now recommends simpler flows for web apps |
| **GitHub flow** | Deploy from the PR branch or right after merge | Small teams, continuous deployment |

**Hotfix with trunk-based:** fix on `main` → tag `v1.4.1` → pipeline promotes. If `main` already has unreleased work you can't ship, branch `release/1.4` from `v1.4.0`, cherry-pick the fix, tag `v1.4.1` there, and merge or cherry-pick back so the fix isn't lost.

## Build once, promote everywhere

The artifact (jar, image digest) built for the tag is the **same bytes** in staging and prod; environments differ only in configuration. Rebuilding per environment means you tested something other than what you shipped. Jenkins here fingerprints the archived jar; Spinnaker/Harness deploy the same image tag through every stage. Promote by **digest** (`image@sha256:...`) when you can — tags are mutable in most registries.

## Rollback vs roll forward

- **Rollback**: redeploy the previous artifact (`kubectl rollout undo`, Spinnaker "rollback" stage, Harness rollback steps). Fast, but only safe if the database and messages are still compatible with the old version.
- **Roll forward**: ship a fix as a new version. Needed when data has already changed shape.
- Make rollback always possible: **expand/contract** database migrations (add column → write both → backfill → read new → drop old, across releases), backward-compatible event schemas, and feature flags so most "rollbacks" are a flag flip.

## Release checklist (say this in interviews)

1. Version derived automatically; changelog generated; tag annotated (signed if required).
2. Build from the tag, tests green, artifacts checksummed and attested.
3. Same artifact through staging → canary → prod with automated verification.
4. Clear rollback path tested; DB migrations backward compatible.
5. Release notes published; on-call aware; dashboards and alerts watched during rollout.
