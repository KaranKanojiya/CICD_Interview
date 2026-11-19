# Turning your own CI/CD work into answers

"Tell me about your deployment process" is almost guaranteed, followed by 3–5 probing follow-ups. Fill this in from your own notes (keep company names and internal numbers out of a public repo), and claim only what you did.

## Template

```
Pipeline / tool: ...
What it did: (one sentence: from commit to where?)
My part: (I wrote / I owned / I improved / I used; name what the platform team did)
One decision and why: (e.g. canary vs rolling, approval gate, flag rollout order)
One incident or problem: symptom -> how I found it -> fix -> what changed afterwards
Numbers I can defend: (build time before/after, deploy frequency, rollback time)
```

## Prompts to prepare

- **Jenkins:** Declarative or scripted? Shared library — what did you put in it? How were credentials handled? Agents static or on Kubernetes? What broke most often (plugins, flaky tests, disk) and what did you do about it?
- **Pipeline speed:** What was the slowest stage and how did you speed it up? Caching? Parallel tests?
- **Releases:** How was the version decided? Tags, release branches, release notes? Who could deploy to prod and how was that enforced?
- **Feature flags (LaunchDarkly or similar):** How did you roll out a risky change — which segments first, what metrics did you watch, how fast could you turn it off? How did you clean up old flags?
- **Deployment safety:** Rolling, blue/green or canary? What signals told you a release was bad? How long did a rollback take and did you ever do one?
- **Database changes:** How did you ship a schema change without downtime?
- **GameDay / resilience:** What failure did you inject in a pre-prod or prod-like environment, what did you expect, what actually happened, what did you fix?
- **Incident tied to a deploy:** How did you detect it, roll back or forward, and what pipeline change prevented a repeat?
- **Security:** Any secret leak, dependency vulnerability or pipeline permission issue you handled?

## Bridges to this repo

| If they ask about... | Point to |
|---|---|
| Versioning and tags | `scripts/next-version.sh`, `scripts/release.sh`, `docs/RELEASE_STRATEGY.md` |
| GitHub Releases, provenance | `.github/workflows/release.yml` |
| Jenkins pipeline design | `Jenkinsfile`, `jenkins/shared-library/vars/`, `jenkins/casc.yaml`, `jenkins/jobs.groovy` |
| Canary and approvals | `spinnaker/pipeline.json`, `harness/pipeline.yaml`, `docs/DEPLOYMENT_STRATEGIES.md` |
| Secrets and supply chain | `docs/PIPELINE_SECURITY.md` |
| Probes, rolling updates, OOMKilled | Kubernetes_Interview (sibling project) |
