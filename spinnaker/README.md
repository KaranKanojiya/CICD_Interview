# Spinnaker (reference pipeline)

`pipeline.json` is a realistic Spinnaker pipeline for this app. It is **not runnable here** — Spinnaker needs its own installation (about ten services plus Redis and SQL) and cloud accounts. It's syntax-checked JSON you can read, explain and adapt.

## What the pipeline does

```
Docker trigger (new semver tag in GHCR)
  └─ 1 Deploy staging (deployManifest, deploy/k8s/deployment.yaml)
      └─ 2 Smoke test staging (webhook: /actuator/health == UP)
          └─ 3 Deploy prod canary, 1 pod (deploy/k8s/canary.yaml)        [skipped if skipCanary=true]
              └─ 4 Canary analysis (kayentaCanary, 30 min, pass >= 90)  [skipped if skipCanary=true]
                  └─ 5 Manual judgment (release-managers: Promote / Stop)
                      └─ 6 Deploy prod rolling (only if judgment == Promote)
                          └─ 7 Remove canary
```

- `refId` + `requisiteStageRefIds` form the DAG; stages without dependencies on each other run in parallel.
- `expectedArtifacts` bind the trigger's image to the manifests, so every stage deploys the same image (build once, promote).
- `${trigger.tag}`, `${parameters.skipCanary}`, `${#judgment('...')}` are SpEL pipeline expressions.
- `stageEnabled` makes a stage conditional; a disabled stage counts as passed for its children.

## Architecture (what each service does)

| Service | Role |
|---|---|
| Deck | Web UI |
| Gate | API gateway; UI and `spin` CLI talk to it |
| Orca | Orchestration engine: runs pipelines, stages, tasks |
| Clouddriver | Talks to clouds (Kubernetes, AWS, GCP, Azure); caches their state |
| Front50 | Stores applications, pipelines, project metadata (S3/GCS/SQL) |
| Igor | Integrates CI (Jenkins, GitHub Actions, Travis) and SCM; triggers pipelines on builds |
| Echo | Event bus: triggers (cron, webhook, Pub/Sub) and notifications (Slack, email) |
| Rosco | Bakes machine images (Packer) or renders Helm/Kustomize manifests |
| Kayenta | Automated canary analysis |
| Fiat | Authorization (roles from LDAP/GitHub teams/SAML) |
| Keel | Managed delivery (declarative, GitOps-like environments) |

Installed with Halyard (legacy) or the Spinnaker Operator / Kustomize on Kubernetes.

## Vocabulary interviewers use

- **Application**: a service and everything Spinnaker manages for it.
- **Server group**: a versioned set of identical instances — an AWS ASG, or a Kubernetes ReplicaSet. Versions look like `cicddemo-prod-v042`.
- **Cluster**: all server groups of an app in one account/region/stack.
- **Red/black**: Spinnaker's name for blue/green. Old server group is disabled, not destroyed, so rollback is "enable the old one".
- **Highlander**: deploy new, destroy all old.
- **Rolling red/black**: shift traffic in steps (e.g. 25/50/100%) with optional verification between steps.
- **Bake**: create an immutable image (AMI) or render manifests.
- **Manual judgment**: human gate with options that later stages can branch on.

## Try it if you want hands-on

- `spin` CLI: `spin pipeline save --file pipeline.json` against a running Gate.
- Local install: the Spinnaker docs describe a Kubernetes install with the Operator; budget around 8 GB RAM and an afternoon. For interview prep, reading this pipeline and the Kayenta docs is usually enough.
