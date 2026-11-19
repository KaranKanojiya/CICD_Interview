# Deployment strategies

The question is never "which is best" but "what does it cost and what risk does it remove". Learn the table, then the follow-ups.

| Strategy | How | Downtime | Extra capacity | Rollback | Main risk |
|---|---|---|---|---|---|
| **Recreate** | Stop all old, start all new | Yes | None | Redeploy old (slow) | Outage during switch |
| **Rolling** | Replace instances in batches (`maxSurge`, `maxUnavailable`) | No | Small (surge) | Roll back in batches | Old and new run together; bad version reaches everyone gradually |
| **Blue/green** (Spinnaker: red/black) | Full new stack, switch traffic at once | No | 2x during switch | Switch back instantly | Cost; DB must work for both; all users hit new version at once |
| **Canary** | Small % of traffic to new version, analyse, then widen | No | Small | Route traffic away from canary | Needs good metrics and enough traffic to be significant |
| **Shadow / dark** | Copy live traffic to new version, discard responses | No | Up to 2x | Nothing user-facing | Side effects (writes, emails) must be stubbed |
| **A/B test** | Route by user attribute to compare business metrics | No | Small | Stop experiment | It's product experimentation, not a safety mechanism |
| **Feature flags** | Deploy code dark, release by flipping a flag per user/segment | No | None | Flip the flag | Flag debt; untested flag combinations |

## Rolling (Kubernetes default)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # at most 1 extra pod during the rollout
    maxUnavailable: 0    # never drop below desired capacity
```

Depends on a correct **readiness probe** (no traffic until ready) and **graceful shutdown** (finish in-flight requests on SIGTERM; `server.shutdown=graceful` here). `kubectl rollout status`, `kubectl rollout undo`. Kubernetes_Interview has the hands-on lab.

## Blue/green

- Traffic switch options: load balancer target group swap (AWS ALB, ECS with CodeDeploy), Kubernetes Service selector change (`track: blue` → `track: green`), DNS (slow, caches).
- Keep blue alive until green has proven itself, then scale blue down. Spinnaker's red/black can disable the old server group but keep it for instant rollback.
- **Database**: both colours share it, so the schema must work for old and new code at the same time (expand/contract).

## Canary

1. Deploy 1 canary instance (or route 1–5% of traffic) next to stable.
2. Compare canary vs a **baseline** (fresh pods of the old version, same size — not the long-running stable fleet, which has warm caches and different uptime).
3. Metrics: error rate, latency p95/p99, saturation, plus business signals (checkouts, logins).
4. Automated judgment: Spinnaker **Kayenta** (statistical comparison, score thresholds), Harness **Continuous Verification** (ML on APM metrics/logs), Argo Rollouts / Flagger analysis templates.
5. Pass → widen (10% → 50% → 100%). Fail → route away and roll back automatically.

Plain Kubernetes Services split by replica count only (`deploy/k8s/canary.yaml`: 1 of 5 pods ≈ 20%). For exact weights use a service mesh (Istio, Linkerd), ingress weights, Argo Rollouts, or ALB weighted target groups.

## Feature flags (deployment ≠ release)

- **Deploy** = put code in production. **Release** = expose behaviour to users. Flags separate them, so a risky feature can ship dark and be turned on for internal users, then 1%, then everyone.
- Uses: kill switches, gradual rollout, per-tenant enablement, trunk-based development without long-lived branches.
- Tools: LaunchDarkly, Unleash, Flagsmith, OpenFeature (vendor-neutral SDK standard), Harness Feature Flags, AWS AppConfig.
- Hygiene: owner and expiry date per flag, remove after full rollout, test both paths, default to the safe value if the flag service is unreachable.

## Database changes during deployments

Expand/contract (also "parallel change"):

1. **Expand**: add the new column/table, nullable; old code ignores it.
2. Deploy code that writes both old and new.
3. Backfill existing rows.
4. Deploy code that reads new.
5. **Contract**: stop writing old, then drop it in a later release.

Each step is independently deployable and rollback-safe. Tools: Flyway, Liquibase. Never put a destructive migration in the same release as the code that stops using the column.

## Picking one (interview answer)

- Internal tool, downtime OK → recreate or rolling.
- Stateless service on Kubernetes, good probes → rolling by default; canary for risky changes.
- Payment or auth path, high traffic → canary with automated analysis + feature flags + fast rollback.
- Big infrastructure change (new runtime, new region) → blue/green or shadow traffic first.
- Mobile/desktop clients → staged rollout percentages in the store, server-side flags, backward-compatible APIs for old clients.
