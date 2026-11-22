# Control matrix

Each hardened control mapped to the **Microsoft cloud security benchmark
(MCSB) v2** and how it is verified in this repo. Verification is one of:
policy test (`python3 tests/run_tests.py`), static check
(`bash scripts/verify.sh`), or the live deploy proof in the README.

| Control | MCSB v2 | Verification |
| --- | --- | --- |
| Internal ingress (`external: false`) | NS-1 Establish network segmentation boundaries; NS-2 Secure cloud native services with network controls | `deny-public-ingress` policy + tests; `verify.sh` asserts `external=false` |
| IP restrictions, default Deny | NS-2; NS-7 Manage network security centrally and effectively | `ipSecurityRestrictions` in `hardened/main.bicep`; `verify.sh` |
| No `allowInsecure` (HTTPS / internal only) | NS-8 Detect and disable insecure services and protocols; DP-3 Encrypt sensitive data in transit | `deny-insecure-transport` policy + tests |
| Secrets via Key Vault (`keyVaultUrl` + `secretRef`), never env `value` | IM-8 Restrict the exposure of credentials and secrets; DP-8 Ensure security of key and certificate repository | `deny-plaintext-secrets` policy + tests |
| User-assigned managed identity | IM-3 Manage application identities securely and automatically | `require-managed-identity` policy + tests; `verify.sh` |
| Least-privilege roles (AcrPull, Key Vault Secrets User) | PA-7 Follow just enough administration (least privilege) principle; IM-3 | `deny-overprivileged-role` policy + tests |
| Pinned image tag, private ACR, admin user disabled | DS-2 Secure the software supply chain; AM-3 Ensure security of asset lifecycle management | `deny-latest-tag` policy + tests; `verify.sh` |
| Log Analytics, 30-day retention | LT-3 Enable logging for security investigation; LT-6 Configure log storage retention | `retentionInDays: 30` in `hardened/main.bicep`; `verify.sh` |
| `minReplicas: 1` (always up) | PV-3 Define and establish secure configurations for compute resources | `minReplicas: 1` in `hardened/main.bicep`; `verify.sh` |
| Policy assignments in Deny at subscription scope | PV-2 Audit and enforce secure configurations; PV-4 Audit and enforce secure configurations for compute resources | Failing `az deployment` in README; `tests/run_tests.py` |

MCSB v2 control names: https://learn.microsoft.com/en-us/security/benchmark/azure/overview
