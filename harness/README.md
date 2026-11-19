# Harness (reference pipeline)

`pipeline.yaml` is a Harness NextGen pipeline for this app. It is **not runnable here** — it needs a Harness account, a Delegate in your cluster, connectors (`github_karan`, `ghcr_karan`), a service `cicd_demo`, environments `staging`/`prod` and their infrastructure definitions. It's syntax-checked YAML you can read, explain and import into a free Harness account.

## What the pipeline does

```
Build (CI stage)       Gradle build + JUnit report, build and push image tagged with the release version
Staging (Deployment)   K8sRollingDeploy, HTTP smoke test; rollback: K8sRollingRollback
Approve prod           HarnessApproval by release_managers, executor can't approve their own run
Prod (Deployment)      [Canary step group unless skipCanary]
                         K8sCanaryDeploy (1 pod) -> Verify (Continuous Verification, 15 min) -> K8sCanaryDelete
                       K8sRollingDeploy
                       rollback: delete canary, K8sRollingRollback
```

- `service.useFromStage: staging` makes prod deploy the exact service + artifact that staging deployed (build once, promote).
- `failureStrategies` → `StageRollback` on any error runs `rollbackSteps`.
- `<+codebase.tag.replace("v","")>` turns the Git tag `v1.2.0` into the image/semver `1.2.0`.
- `<+input>` makes a field a runtime input; `.default()` and `.allowedValues()` constrain it.
- The Slack webhook comes from the secret manager: `<+secrets.getValue("slack_deployments_webhook")>` — no secrets in YAML.

## Concepts interviewers use

| Term | Meaning |
|---|---|
| Delegate | Agent you run in your network; outbound-only connection to Harness; executes tasks with local access |
| Connector | Configured integration (Git, registry, cluster, cloud, APM) referencing secrets |
| Service | What you deploy: manifests + artifact source + variables |
| Environment | Where: prod / pre-prod, with overrides |
| Infrastructure Definition | The concrete target (cluster + namespace, AWS account + region) |
| Stage / step / step group | Pipeline structure; step groups can run in parallel or conditionally |
| Failure strategy | Per step/stage: retry, ignore, manual intervention, abort, stage/pipeline rollback |
| Continuous Verification | ML comparison of metrics/logs (Prometheus, Datadog, AppDynamics, Splunk…) for the new version vs baseline |
| Templates | Versioned, reusable pipelines/stages/steps for a golden path |
| OPA policies | Policy-as-code gates, e.g. "prod needs approval", "only approved registries" |
| Git Experience | Pipelines stored in Git, changed through PRs |
| Freeze window | Blocks deployments during set periods |

## Harness vs Spinnaker in one breath

Both are deployment-first with built-in strategies, verification and rollback. Spinnaker is open source and you operate it; Harness is a commercial platform (SaaS or self-managed) with governance, templates, RBAC and extra modules (CI, feature flags, cloud cost, chaos, security testing) included.
