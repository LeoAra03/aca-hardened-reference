# Cost

This reference is designed to cost almost nothing when idle and to be impossible to forget about.

## What you pay for

| Resource | Billing | Idle cost |
| --- | --- | --- |
| Container Apps Environment | Consumption plan, per vCPU/memory-second while running | ~0 EUR at 0 replicas |
| Container App | Scale-to-zero (`minReplicas: 0`) | 0 EUR when scaled to zero |
| Container Registry (Basic) | Flat monthly fee | ~5 EUR/month if left up |
| Log Analytics workspace | Per GB ingested, 30-day retention | First 5 GB free, then ~2.30 EUR/GB |
| Managed identity, policy, budget | Free | 0 EUR |

## Expected totals

- **Idle (deployed, no traffic):** a few cents per day. The environment and app scale to zero; the only standing charge is the Basic ACR.
- **Full day of use:** under 5 EUR, including a day of active replicas and log ingestion.
- **Worst case:** the 20 EUR budget alarm fires at 80% (16 EUR) and again at 100%, so a forgotten environment cannot surprise you.

## How to stop all spend

```bash
make down
```

This deletes the resource group, which removes the environment, app, registry, workspace and budget in one operation. Policy assignments live at subscription scope and cost nothing; remove them with `az policy assignment delete` if you no longer want the guardrails.

## Notes

- Prices are indicative for `westeurope` on the Container Apps consumption plan. Check [Azure pricing](https://azure.microsoft.com/pricing/details/container-apps/) and Cost Management for your subscription.
- The 30-day retention is deliberate: telemetry is real, but bounded. Raise it only if you have a compliance reason.
