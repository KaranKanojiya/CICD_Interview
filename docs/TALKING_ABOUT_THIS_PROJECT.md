# Talking about this project in an interview

This repo is a **learning lab**: one small service with the same delivery pipeline written four ways, plus a tested release process. You do some CI/CD work at your job, so keep the two clearly separate: the pipelines you actually changed at work, and the tools you learned here.

[PRODUCTION_STORIES.md](PRODUCTION_STORIES.md) is the template for your work stories. This page covers how to present the project itself.

## Where it fits in your story

| Kind | What it is | How to bring it up |
|---|---|---|
| Work experience | The pipeline and rollout work your resume lists (for example Jenkins pipeline changes and feature-flag rollouts environment by environment) | Lead with these for "tell me about your deployment process". Name what the platform team owned |
| **Learning lab (this repo)** | Jenkins configured as code, GitHub Actions, a scripted release process, and reference Spinnaker and Harness pipelines | "To understand the tools beyond what I use day to day, I built…" |

## The pitch

**30 seconds**

> "I built a CI/CD lab: one Spring Boot service with the same delivery pipeline written for GitHub Actions, Jenkins, Spinnaker and Harness, plus a release process that derives the next semantic version from Conventional Commits, creates an annotated tag and publishes a GitHub Release with provenance. Jenkins runs locally in Docker, fully configured as code, and executes the pipeline end to end. The Spinnaker and Harness pipelines are reference only, because they need their platforms, and I say so."

**2 minutes (if they say "tell me more")**

1. **Why:** "Every team uses a different CD tool. Writing the same pipeline four ways showed me what's common (build once, promote the same artifact, gates, rollback) and what each tool adds."
2. **Structure:** the app reports the version and commit baked in at build time; release scripts with a self-test; two GitHub workflows; a Jenkinsfile with a shared library; Spinnaker and Harness pipeline definitions; Kubernetes manifests for stable and canary.
3. **The part I'm proudest of:** pick one and go deep:
   - *Release process:* `feat` bumps minor, `fix` bumps patch, `!` or `BREAKING CHANGE` bumps major; the release script refuses dirty trees and non-main branches and never pushes; a self-test proves these rules in a throwaway repo.
   - *Jenkins as code:* plugins baked into the image, configuration in `casc.yaml`, jobs from a Job DSL seed, so the whole server is reproducible from git.
   - *Safe releases:* the release workflow only runs for annotated tags on main, builds that exact version, and attaches checksums and build provenance attestations.
4. **Deployment strategies:** rolling vs blue/green vs canary, automated canary analysis (Kayenta, Harness Continuous Verification), and rollback vs roll forward.
5. **What I'd do next:** a GitOps flow with Argo CD and signing images with cosign.

## Answers to likely questions

**"Tell me about your deployment process."**
Answer from work first, using [PRODUCTION_STORIES.md](PRODUCTION_STORIES.md): commit to production, your part, one decision, one problem. Bring in this lab to show breadth.

**"Have you used Spinnaker / Harness?"**
> "Not hands-on. I wrote reference pipelines for both in my CI/CD lab to learn their model (stages, manual judgment, canary analysis and rollback), and I've worked with [the tools you actually used]. The concepts carry over." Only list tools you really used.

**"Have you used GitHub Actions / Jenkins?"** Say what you did at work, if anything, then: "In my lab, the GitHub Actions release workflow guards on annotated tags and attaches provenance, and Jenkins runs the full pipeline locally, configured as code."

**"Can I see the code?"**
> "The lab is on my GitHub." *(if public)* / "It's in a private repository. I can share my screen and run the Jenkins pipeline live." *(if private)*

**"Did you use AI to build this?"**
> "Yes, I used an AI coding assistant to move faster. But I ran everything, broke things on purpose, and I can explain every part. Pick any piece."

Only say this if it's true, and only if you pass the self-check below.

## Self-check: explain these without notes

If you can't explain one of these out loud in about two minutes, study it before mentioning the project.

| Topic | Where | Must be able to explain |
|---|---|---|
| Next version | `scripts/next-version.sh` | Conventional Commits rules; what happens with no tags yet |
| Release | `scripts/release.sh`, `scripts/test-release-scripts.sh` | Why annotated tags; why refuse dirty trees and non-main branches; why the script never pushes |
| GitHub Actions | `.github/workflows/ci.yml`, `release.yml` | The tag guard, caching, provenance attestations, least-privilege `permissions` |
| Jenkins pipeline | `Jenkinsfile` | Stages, parallel gates, `input` approval, promoting the archived artifact instead of rebuilding |
| Shared library | `jenkins/shared-library/vars/` | What `semver`, `deployApp`, `smokeTest` and `stopApp` do, and why put them in a library |
| Jenkins as code | `jenkins/casc.yaml`, `jenkins/jobs.groovy`, `jenkins/Dockerfile` | JCasC vs clicking in the UI; reproducibility |
| Canary | `spinnaker/pipeline.json`, `harness/pipeline.yaml`, `deploy/k8s/` | Canary vs blue/green; what automated analysis compares; how rollback works |
| Release strategy | [RELEASE_STRATEGY.md](RELEASE_STRATEGY.md) | Build once and promote; hotfix flow; rollback vs roll forward |
| Pipeline security | [PIPELINE_SECURITY.md](PIPELINE_SECURITY.md) | OIDC instead of long-lived keys; common GitHub Actions pitfalls; SBOM and provenance |

Practice: make a commit with `feat!:` in a scratch branch, run `./scripts/release.sh --dry-run`, and explain the version it picks.

## Don't say

- That you've used Spinnaker or Harness hands-on, or ran these pipelines in production.
- That you owned your company's CI/CD platform if a platform team did.
- Build-time or deploy-frequency numbers you can't defend.

## Before making the repo public

- [ ] Commits use a personal or GitHub "noreply" email: `git log --format='%ae' | sort -u`.
- [ ] No company names, internal hostnames, registry URLs, tokens or private paths: `git grep -nIiE 'token|secret|password|internal'` and read what it finds.
- [ ] [PRODUCTION_STORIES.md](PRODUCTION_STORIES.md) stays a template; keep your filled-in stories in private notes.
- [ ] Remote URL has no token in it (`git remote -v`).
- [ ] `./gradlew test` and `bash scripts/test-release-scripts.sh` pass on a fresh clone.
