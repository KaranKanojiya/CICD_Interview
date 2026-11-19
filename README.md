# CI/CD Interview Prep: Jenkins, GitHub Actions, Spinnaker, Harness, Releases

One small Spring Boot service with the same delivery pipeline written four ways, plus a tested release process (Conventional Commits → semver → annotated tag → GitHub Release) and 70 interview questions.

> **Runs locally:** app tests, release scripts (10-assertion self-test), workflow lint, and a real Jenkins (Docker, configured as code) running the full pipeline. **Reference only:** Spinnaker and Harness pipelines (need their platforms), syntax-checked.

## Quick start

Needs JDK 21; Docker for the Jenkins lab.

```bash
./gradlew test                          # app: /api/version reports version + commit baked in at build time
bash scripts/test-release-scripts.sh    # proves the versioning and tagging rules in a throwaway repo
./scripts/release.sh --dry-run          # next version + release notes for this repo

./jenkins/up.sh                         # Jenkins on http://localhost:8081, everything from casc.yaml + jobs.groovy
./jenkins/run-pipeline.sh               # runs the Jenkinsfile end to end, prints SUCCESS/FAILURE
./jenkins/down.sh
```

## What's where

| Path | Topic |
|---|---|
| `src/`, `build.gradle` | Spring Boot app; version comes from `-PreleaseVersion`, commit from `-PgitCommit`, exposed at `/api/version` |
| `scripts/next-version.sh` | Conventional Commits since the last tag → next semver (`feat` minor, `fix`/`perf` patch, `!`/`BREAKING CHANGE` major) |
| `scripts/release.sh` | Changelog, `chore(release)` commit, annotated tag; refuses dirty trees and non-main branches; never pushes |
| `.github/workflows/ci.yml` | PR/main CI: build, tests, reports, image build with cache |
| `.github/workflows/release.yml` | On tag: guard annotated + on main, build that version, checksum, provenance attestations, GHCR image, GitHub Release |
| `Jenkinsfile` | Declarative pipeline: version, build/test + JUnit, parallel gates, archive, optional image, staging deploy + smoke test, approval, prod |
| `jenkins/shared-library/vars/` | `semver`, `deployApp`, `smokeTest`, `stopApp` global steps |
| `jenkins/` | Dockerized Jenkins: plugins baked in, JCasC (`casc.yaml`), Job DSL seed (`jobs.groovy`), helper scripts |
| `spinnaker/pipeline.json` | Docker trigger → staging → smoke → canary + Kayenta → manual judgment → prod |
| `harness/pipeline.yaml` | CI stage → staging rolling + smoke → approval → prod canary + Continuous Verification → rolling; rollback steps |
| `deploy/k8s/` | Stable and canary manifests the CD tools deploy |

## Docs

- [docs/INTERVIEW_QUESTIONS.md](docs/INTERVIEW_QUESTIONS.md) — 70 Q&A: fundamentals, release/versioning, GitHub Actions, Jenkins, Spinnaker, Harness, deployment strategies, security, scenarios, rapid fire
- [docs/RELEASE_STRATEGY.md](docs/RELEASE_STRATEGY.md) — semver, tags, GitHub Releases, branching models, hotfixes, build once/promote, rollback vs roll forward
- [docs/DEPLOYMENT_STRATEGIES.md](docs/DEPLOYMENT_STRATEGIES.md) — recreate, rolling, blue/green, canary, shadow, flags, DB migrations
- [docs/TOOL_COMPARISON.md](docs/TOOL_COMPARISON.md) — Jenkins vs Actions vs Spinnaker vs Harness vs Argo CD, push vs pull, Actions ↔ Jenkins map
- [docs/PIPELINE_SECURITY.md](docs/PIPELINE_SECURITY.md) — secrets, OIDC, Actions pitfalls, Jenkins hardening, SLSA/provenance/SBOM
- [docs/PRODUCTION_STORIES.md](docs/PRODUCTION_STORIES.md) — template to turn your own pipeline work into answers
- [docs/TALKING_ABOUT_THIS_PROJECT.md](docs/TALKING_ABOUT_THIS_PROJECT.md) — how to present this lab next to your work experience: pitch, answers, self-check
- [docs/SETUP_MAC.md](docs/SETUP_MAC.md) — install, Jenkins lab, real GitHub release, troubleshooting
- [spinnaker/README.md](spinnaker/README.md), [harness/README.md](harness/README.md) — architecture and vocabulary

## The same pipeline, four tools

| Step | GitHub Actions | Jenkins | Spinnaker | Harness |
|---|---|---|---|---|
| Trigger | tag push | SCM / API | Docker registry tag | Git tag / artifact |
| Build + test | `./gradlew build` | `sh` + `junit` | (from CI) | CI stage `Run` |
| Artifact | jar + image to GHCR, attestations | `archiveArtifacts` fingerprinted | expected artifact | `BuildAndPushDockerRegistry` |
| Staging | — | `deployApp` + `smokeTest` | `deployManifest` + webhook | `K8sRollingDeploy` + `Http` |
| Gate | environment reviewers | `input` | Manual Judgment | `HarnessApproval` |
| Prod | — | promote archived jar | canary + Kayenta → rolling | canary + Verify → rolling |
| Rollback | redeploy previous tag | redeploy previous build | rollback stage / old server group | `rollbackSteps` |

## Related prep projects

Kubernetes (probes, rolling updates, HPA), AWS, Kafka, GraphQL and code review live in sibling folders of this workspace.
