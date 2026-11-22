# aca-hardened-reference

A hardened Azure Container Apps reference: private ingress, user-assigned managed identity, zero secrets, OIDC-only deploys, Azure Policy guardrails and a budget alarm. Deploy in one command, tear down in one.

Most Container Apps samples are `az containerapp up` and a public FQDN. This one is the shape you would actually hand to a security reviewer.

## Posture
| Concern | Here | Why it matters |
| --- | --- | --- |
| Ingress | internal only, external opt-in flag | Nothing is public by accident |
| Identity | user-assigned managed identity, no connection strings | No rotation, no leaks |
| Registry auth | ACR pull via identity, admin user disabled | No registry password |
| CI auth | OIDC federated credential, no stored secret | Nothing long-lived in GitHub |
| Policy | deny public ingress, deny `:latest`, require identity | Guardrails at subscription scope |
| Cost | budget alarm at 20 EUR, scale-to-zero | A lab cannot surprise you |
| Observability | Log Analytics with 30-day retention | Bounded spend, real telemetry |

## Quickstart
make up # resource group, policy assignments, deploy
make verify # asserts internal ingress, identity, no admin creds, no :latest
make down # deletes the resource group

## Decisions
[docs/decisions.md](docs/decisions.md) records why internal-by-default, why managed identity over secrets, and why policy is assigned at subscription and not per resource.

## Cost
[docs/cost.md](docs/cost.md). Scale-to-zero, one environment, 30-day retention: a few cents idle, under 5 EUR for a full day of use.

## Limitations
Single region, no private endpoint to ACR, no WAF in front (internal ingress makes it moot), no multi-env promotion.

## Contributors
- [Leonardo Araya](https://github.com/LeoAra03) (@LeoAra03) — maintainer
