# Threat model — public ingress and secret theft

Scope: the Container App in `insecure/` vs `hardened/`. Two attack surfaces
dominate the difference: a **public ingress** (external FQDN + plain HTTP) and
**secret theft** (plaintext secrets + an over-privileged identity). Method:
STRIDE. (MCSB DS-1: conduct threat modeling.)

## Assets and trust boundaries

- **Assets:** app data, the DB password and API key, the ACR images, the
  resource group itself.
- **Boundaries:** internet → Container App ingress; app → Key Vault / ACR;
  app identity → resource group.

## STRIDE

| Threat | Insecure exposure | Hardened mitigation |
| --- | --- | --- |
| **Spoofing** | Public FQDN over HTTP: anyone can impersonate the app or MITM traffic on the path. | Internal ingress (no public FQDN), IP restrictions with default Deny, HTTPS-only transport. |
| **Tampering** | `nginx:latest` is mutable: the image you audited is not the image you run. | Pinned tag (`hello:1.0.0`) from a private ACR, pulled by identity. |
| **Repudiation** | No log destination: actions against the app leave no trail. | Log Analytics with 30-day retention (LT-3, LT-6). |
| **Information Disclosure** | Plaintext secrets in env vars are visible in the portal, CLI, and deployment history; HTTP exposes payloads to sniffing. | Secrets via Key Vault `keyVaultUrl` + `secretRef`; no `value` in env. Internal ingress removes the sniffing surface. |
| **Denial of Service** | Public ingress is reachable by anyone: trivial to flood, and scale-to-zero means cold-start latency under load. | Internal ingress + IP restrictions; `minReplicas: 1` keeps the app warm. |
| **Elevation of Privilege** | The app identity holds **Contributor on the whole resource group**: a compromised app can read, modify, or delete every resource in the RG. | User-assigned identity with **AcrPull** (ACR only) and **Key Vault Secrets User** (vault only). Least privilege (PA-7). |

## Why the identity is the worst finding

The public ingress is loud; the Contributor role is quiet. A compromised
container with Contributor can list Key Vaults, read other apps' secrets,
and rewrite the deployment — the app becomes a foothold for the whole
resource group. That is why `deny-overprivileged-role` exists alongside the
ingress policies, and why the hardened identity is scoped to two resources.

## Residual risk

Single region, no WAF (internal ingress makes it moot), no private endpoint
to ACR/Key Vault, and the `allowedCidr` placeholder must be replaced with the
real app network before production use.
