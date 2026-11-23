# Control matrix

Control → Microsoft cloud security benchmark (MCSB) v2 → verification command.
One row per before/after line in the README. MCSB control names:
https://learn.microsoft.com/en-us/security/benchmark/azure/overview

| Control | MCSB v2 | Verification |
| --- | --- | --- |
| Private ingress (`external: false` + `ipSecurityRestrictions`) | NS-2 Secure cloud native services with network controls | `az containerapp show -g $RG -n aca-hardened-app --query properties.configuration.ingress.external` |
| Transport (`allowInsecure: false`) | NS-8 Detect and disable insecure services and protocols; DP-3 Encrypt sensitive data in transit | `az containerapp show -g $RG -n aca-hardened-app --query properties.configuration.ingress.allowInsecure` |
| Secrets via Key Vault (`keyVaultUrl` + `secretRef`) | IM-8 Restrict the exposure of credentials and secrets; DP-8 Ensure security of key and certificate repository | `az containerapp show -g $RG -n aca-hardened-app --query properties.configuration.secrets` |
| User-assigned identity, `AcrPull` + `Key Vault Secrets User` | IM-3 Manage application identities securely and automatically; PA-7 Follow just enough administration (least privilege) principle | `az containerapp show -g $RG -n aca-hardened-app --query identity.type` and `az role assignment list -g $RG` |
| Digest-pinned image | DS-2 Secure the software supply chain | `az containerapp show -g $RG -n aca-hardened-app --query properties.template.containers[0].image` |
| `minReplicas: 1` | PV-3 Define and establish secure configurations for compute resources | `az containerapp show -g $RG -n aca-hardened-app --query properties.template.scale.minReplicas` |
| Egress `outboundType: userDefined` + UDR to firewall | NS-1 Establish network segmentation boundaries; NS-2 Secure cloud native services with network controls | `az containerapp env show -g $RG -n aca-hardened-env --query properties.vnetConfiguration.outboundType` |
| Log Analytics + `logAnalyticsConfiguration` | LT-3 Enable logging for security investigation; LT-6 Configure log storage retention | `az containerapp env show -g $RG -n aca-hardened-env --query properties.appLogsConfiguration.destination` |
| Liveness + readiness probes | PV-3 Define and establish secure configurations for compute resources | `az containerapp show -g $RG -n aca-hardened-app --query properties.template.containers[0].probes` |
| Policy Deny assignments | PV-2 Audit and enforce secure configurations; PV-4 Audit and enforce secure configurations for compute resources | `bash tests/run-policy-tests.sh` (live) and the failing deploy in the README |
