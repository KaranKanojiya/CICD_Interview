# Pipeline security (the supply-chain questions)

CI/CD systems hold production credentials and produce the code that runs in production, which makes them a prime target. Interviewers expect you to name concrete controls.

## Secrets

- **No long-lived cloud keys in CI.** Use OIDC federation: the workflow gets a short-lived signed token (`permissions: id-token: write`), the cloud trusts it for a role scoped to repo + branch/environment. AWS: `aws-actions/configure-aws-credentials` with `role-to-assume`; the role's trust policy checks `token.actions.githubusercontent.com:sub` (e.g. `repo:owner/repo:environment:prod`).
- Store remaining secrets in the CI secret store or a vault (HashiCorp Vault, AWS Secrets Manager); scope them to **environments** so only the prod job after approval can read prod secrets.
- Masking is best effort: base64-encoding or splitting a secret defeats it. Don't echo secrets, don't pass them on command lines (visible in `ps`), prefer env vars or files.
- **Jenkins**: `credentials('id')` in `environment {}` or `withCredentials([...])`; use **single-quoted** `sh '... $TOKEN ...'` so the shell expands the secret — Groovy interpolation (`"${TOKEN}"`) leaks it into the process list and logs, and Jenkins warns about it.
- This repo: Jenkins admin password comes from `$JENKINS_ADMIN_PASSWORD` or a generated, git-ignored file; JCasC reads `${JENKINS_ADMIN_PASSWORD}`; nothing secret is committed.
- A leaked token: revoke first, then rotate dependents, then audit its use (GitHub audit log, CloudTrail), then find how it leaked.

## GitHub Actions specifics

| Risk | Control |
|---|---|
| `GITHUB_TOKEN` too powerful | `permissions: contents: read` at the top, widen per job (this repo's `release.yml` adds `contents/packages/id-token/attestations: write` only on the release job) |
| Compromised third-party action (e.g. the March 2025 `tj-actions/changed-files` compromise that dumped secrets into logs) | Pin actions to a **full commit SHA** (`uses: owner/action@<40-char sha> # v4.1.0`), keep them updated with Dependabot/Renovate, prefer official or verified actions, limit allowed actions in org settings |
| **Script injection**: `run: echo "${{ github.event.pull_request.title }}"` | Pass untrusted values through `env:` and quote them: `env: TITLE: ${{ ... }}` then `"$TITLE"` |
| **`pull_request_target`** runs with secrets and write token in the base repo context; checking out the PR head and running its code hands secrets to forks | Use `pull_request` for untrusted code; never build fork code under `pull_request_target`; split privileged steps into `workflow_run` with care |
| Self-hosted runners on public repos: forks can run code on your machine | Ephemeral, isolated runners (ARC on Kubernetes, `--ephemeral`); never for public repos |
| Cache poisoning across branches | Don't restore caches from untrusted refs in release jobs |
| Tag/branch tampering | Rulesets: protect `main` (reviews, status checks) and `v*` tags (no update/delete) |

This repo pins to major tags for readability; `docs/INTERVIEW_QUESTIONS.md` Q30 explains the SHA-pinning trade-off you should mention.

## Jenkins specifics

- Controller with **0 executors**; builds run on ephemeral agents (Kubernetes plugin pods) so a build can't read `$JENKINS_HOME` secrets.
- Keep plugins few and current (most Jenkins CVEs are plugin CVEs); manage them as code (`plugins.txt`) and rebuild the image to upgrade.
- **Groovy sandbox / script approval**: Pipeline code runs sandboxed; trusted global shared libraries run outside it, so control who can change them (repo branch protection).
- Authorization: Matrix or Role-based strategy, SSO (SAML/OIDC); no anonymous read; CSRF crumbs on (the REST trigger in `jenkins/run-pipeline.sh` fetches a crumb with a session cookie).
- Credentials scoped to folders, not global. Prefer short-lived cloud credentials (OIDC / IRSA on EKS) over stored keys.
- Configuration as Code (JCasC) + job-dsl = reviewable changes and a rebuildable controller.

## Artifact integrity (SLSA)

- **Provenance**: a signed statement "this artifact was built from commit X by workflow Y". `actions/attest-build-provenance` produces it (Sigstore-backed); verify with `gh attestation verify <file> --repo owner/repo` or `cosign verify-attestation` for images. SLSA Build Level 2–3 is the target conversation.
- **Signing**: `cosign sign` images (keyless with OIDC); enforce at deploy time with admission policies (Kyverno, Sigstore policy-controller) so unsigned images can't run.
- **SBOM**: generate with Syft or the CycloneDX Gradle plugin; attach to the release; scan with Grype/Trivy/Dependabot.
- **Checksums** next to release assets (this repo publishes `.sha256`).
- **Immutable** references: deploy images by digest; immutable GitHub releases; registry tag immutability (ECR supports it).

## Shift-left checks to put in the pipeline

Ordered from cheap to expensive: secret scanning (gitleaks, GitHub push protection) → SAST (CodeQL, Semgrep, SpotBugs + Find Security Bugs) → dependency/SCA (Dependabot, OWASP Dependency-Check, Snyk) → IaC scan (Checkov, tfsec) → container scan (Trivy) → DAST against staging (OWASP ZAP). Fail the build on new high-severity findings; track the backlog separately so the gate stays credible.

## Separation of duties

- The person who writes the change shouldn't be the only approver for prod (Harness `disallowPipelineExecutor`, GitHub environment reviewers with "prevent self-review", branch protection requiring review).
- Audit trail: who approved, which artifact digest, which commit — all three tools in this repo record it.
