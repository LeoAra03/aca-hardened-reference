# aca-hardened-reference

The same container app, deployed twice. The left column ships. The right column survives an
audit.

This is a review artifact, not a template. It exists so a reviewer can read one diff and
see whether I know what each Azure Container Apps control actually buys. Every hardened
setting is paired with the specific failure it prevents and the Azure Policy that now
blocks the insecure version from coming back.

## Before / after

| Setting | insecure/ | hardened/ | Failure prevented |
|---|---|---|---|
| Ingress | `external: true` | `external: false` + `ipSecurityRestrictions` | Direct public reach, WAF bypass |
| Transport | `allowInsecure: true` | `allowInsecure: false` | Bearer token in cleartext |
| Secrets | literal `env.value` | Key Vault reference + user-assigned identity | Secret in ARM history and `containerapp show` output |
| Identity | none | user-assigned, `AcrPull` + `Key Vault Secrets User` | Registry pull over admin credentials; over-scoped RBAC |
| Image | `:latest` | digest pin | Non-reproducible deploys, no rollback target |
| Scaling | `minReplicas: 0` | `minReplicas: 1` | Cold-start auth timeouts masking a DoS |
| Egress | default | `outboundType: userDefined` + UDR to firewall | Unrestricted egress, no egress inspection |
| Diagnostics | none | Log Analytics + `logAnalyticsConfiguration` | No audit trail |
| Health | no probes | liveness + readiness | Traffic to a half-started replica |
| Policy | none | Deny assignment on both resource types | Regression by copy-paste |

## Reproduce the block

```bash
az group create -n rg-aca-ref -l eastus
az deployment group create -g rg-aca-ref -f policy/deny-public-ingress.json
az deployment group create -g rg-aca-ref -f insecure/main.bicep   # fails
```

Expected, and the point of the repo:

```
Deployment failed. Error: RequestDisallowedByPolicy
  Policy: deny-aca-public-ingress
  Resource: api (Microsoft.App/containerApps)
  Reason: ingress.external must be false; ingress.ipSecurityRestrictions must be non-empty
```

Then `hardened/main.bicep` deploys clean. The insecure column is not a strawman I wrote to
lose — it is the default output of most scaffolding tools.

## Structure

- `insecure/` — deployable, plausible, wrong.
- `hardened/` — the corrected version, one control at a time.
- `policy/` — Deny definitions and a test harness that asserts each one fires.
- `tests/` — the harness. A policy that has never denied a resource is a policy you have not
  written.
- `docs/threat-model.md` — STRIDE over the public ingress and the secret path.
- `docs/control-matrix.md` — control to Microsoft cloud security benchmark to verification.

## Limitations

The egress UDR assumes a firewall that is not in this repo. No WAF, no Private Endpoint for
the registry, no workload identity federation for the app itself. `minReplicas: 1` trades
cost for cold-start behavior and is wrong for a batch worker.

## Contributors

- [Leonardo Araya](https://github.com/LeoAra03) (@LeoAra03) — maintainer
