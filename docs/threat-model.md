# Threat model — Azure Container Apps reference

Scope: one container app, one registry, one vault, operator-deployed by Bicep.

## Assets
- The database credential in Key Vault.
- The registry, as a supply-chain entry point.
- The app's managed identity, as a pivot into the resource group.

## Trust boundaries
operator -> Bicep -> ARM -> Container Apps environment -> container -> Key Vault / ACR

Untrusted input crosses the ingress boundary. Everything behind it is trusted only because
the ingress is restricted.

## STRIDE

| Threat | Vector in the insecure column | Control |
|---|---|---|
| Spoofing | Admin GUI reachable from any address | `ipSecurityRestrictions`, Entra ID auth |
| Tampering | `:latest` tag rewritten under a deploy | Digest pin, Trivy gate on HIGH/CRITICAL |
| Repudiation | No diagnostics, no request log | Log Analytics workspace, `logAnalyticsConfiguration` |
| Information disclosure | Literal secret in ARM history | Key Vault reference, managed identity |
| Denial of service | Public ingress, no rate limit, `minReplicas: 0` | IP restrictions, WAF in front, `minReplicas: 1` |
| Elevation of privilege | Identity with Contributor on the RG | Scoped `AcrPull` + `Key Vault Secrets User` |

## Unanswered
Registry compromise still yields code execution: the digest pin prevents tag mutation, not
a malicious push. Signing (Notation/cosign) and a verified-pull policy are the answer and
are not implemented here. Identity federation for the workload is also absent — the app
authenticates to the vault with the platform identity, not a federated credential.
