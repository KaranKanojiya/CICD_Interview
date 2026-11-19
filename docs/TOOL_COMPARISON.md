# Jenkins vs GitHub Actions vs Spinnaker vs Harness (and friends)

First separate the jobs: **CI** turns a commit into a tested artifact; **CD** moves that artifact through environments safely. Jenkins and GitHub Actions are CI-first tools that can deploy; Spinnaker and Harness CD are deployment-first tools that usually take an artifact built elsewhere.

| | Jenkins | GitHub Actions | Spinnaker | Harness |
|---|---|---|---|---|
| Primary job | CI (and scripted CD) | CI (and simple CD) | Multi-cloud CD | CD platform (+ CI, flags, verification, cost) |
| Model | Self-hosted controller + agents | SaaS runners or self-hosted runners | Self-hosted microservices (Deck, Gate, Orca, Clouddriver, ...) | SaaS control plane + **Delegate** in your network (self-managed edition exists) |
| Pipeline definition | `Jenkinsfile` (Groovy DSL), shared libraries | YAML in `.github/workflows`, reusable workflows, actions | JSON pipelines (UI or "pipelines as code" via Dinghy/spin CLI) | YAML pipelines, templates, can live in Git (Git Experience) |
| Deployment strategies | You script them | You script them (or use environments + approvals) | Built in: red/black, highlander, rolling, canary with Kayenta | Built in: rolling, blue/green, canary with Continuous Verification |
| Approvals | `input` step | Environments with required reviewers | Manual Judgment stage | Approval stages (Harness, Jira, ServiceNow) |
| Rollback | You script it | You script it | Rollback stages, previous server groups kept | Rollback steps + failure strategies per stage |
| Extensibility | ~2,000 plugins (power and pain) | Marketplace actions | Custom stages, webhooks | Custom steps, templates, OPA policies |
| Cost | Free software, you pay ops time | Minutes (free for public repos) or own runners | Free software, heavy to operate | Commercial licence |
| Typical pain | Plugin upgrades, controller as a pet, Groovy CPS quirks | Vendor lock-in, secrets/permissions mistakes, long YAML | Operating ~10 services; steep learning curve | Cost; abstractions to learn; vendor lock-in |

## When to pick what (interview answer)

- **Jenkins**: you already run it, need on-prem builds, unusual toolchains or deep customisation. Modernise it: JCasC, job-dsl/multibranch, shared libraries, ephemeral Kubernetes agents, 0 executors on the controller.
- **GitHub Actions**: code is on GitHub, team wants low ops. Use OIDC to clouds, environments with reviewers, reusable workflows for consistency.
- **GitLab CI**: same idea as Actions when code lives in GitLab; strong built-in registry and environments.
- **Spinnaker**: many services across several clouds/accounts, need standard canary and red/black with automated rollback, and have a platform team to run it (Netflix built it; now a CD Foundation project).
- **Harness**: want Spinnaker-style safety (verification, rollback, governance) as a managed product, with audit, RBAC, policy-as-code and templates, and the budget for it.
- **Argo CD / Flux (GitOps)**: Kubernetes-only, want Git to be the source of truth. A controller in the cluster **pulls** desired state from Git and reconciles drift. Argo Rollouts adds canary/blue-green. Often combined: Actions/Jenkins builds and bumps the image tag in a config repo; Argo CD deploys.

## Push vs pull deployment

| Push (Jenkins, Actions, Spinnaker, Harness) | Pull / GitOps (Argo CD, Flux) |
|---|---|
| Pipeline has credentials to the cluster and runs `kubectl apply`/`helm upgrade` | Agent in the cluster pulls from Git; CI never holds cluster credentials |
| Easy to orchestrate cross-system steps (DB migration, tests, approvals) | Drift detection and self-healing built in; audit = Git history |
| Drift possible if someone runs `kubectl edit` | Multi-step orchestration needs extra tooling |

## Common combinations in job descriptions

- **Jenkins (CI) + Spinnaker (CD)**: Jenkins builds and pushes the image; Spinnaker's Igor service watches Jenkins (or the registry) and triggers the deploy pipeline. Classic Netflix-style setup.
- **GitHub Actions (CI) + Harness (CD)**: Actions builds; Harness pipeline triggered by artifact or webhook does canary + verification + approvals.
- **GitHub Actions + Argo CD**: build, push, update the tag in a GitOps repo; Argo CD syncs.
- **Jenkins → GitHub Actions migration**: move per-repo builds to Actions, keep complex release orchestration elsewhere; `gh actions-importer` can convert Jenkinsfiles as a starting point.

## Jenkins quick map for people who know GitHub Actions

| GitHub Actions | Jenkins |
|---|---|
| workflow file | `Jenkinsfile` |
| job | stage (on an `agent`) |
| step | step (`sh`, `junit`, ...) |
| `runs-on` | `agent { label '...' }` / Kubernetes pod template |
| `needs:` | stage order / `parallel` |
| `strategy.matrix` | `matrix { axes { ... } }` |
| reusable workflow / composite action | shared library (`vars/*.groovy`) |
| `secrets.X` | `credentials('id')` / `withCredentials` |
| `actions/upload-artifact` | `archiveArtifacts`, `stash`/`unstash` |
| environment protection rules | `input` step, folder permissions |
| `concurrency:` | `disableConcurrentBuilds()`, `lock()` (Lockable Resources) |
| `if:` | `when { }` |
