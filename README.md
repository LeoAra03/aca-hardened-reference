# aca-hardened-reference

Same app, two deployments. Left column ships, right column survives an audit.

`insecure/` is the quick sample everyone copies. `hardened/` is the same app
with the controls an auditor asks for. Azure Policy in `policy/` denies the
left column at subscription scope — the deploy below **fails**, and that
failure is the proof the control exists.

## Before / After

| | Insecure (`insecure/`) | Hardened (`hardened/`) |
| --- | --- | --- |
| Ingress | external, public FQDN | internal only |
| Transport | `allowInsecure: true` (HTTP) | HTTPS / internal, IP restrictions default Deny |
| Secrets | plaintext in env vars | Key Vault `keyVaultUrl` + `secretRef` |
| Identity | system-assigned | user-assigned managed identity |
| Roles | Contributor on the resource group | AcrPull + Key Vault Secrets User |
| Image | `nginx:latest` | pinned tag from private ACR |
| Replicas | scale-to-zero | `minReplicas: 1` |
| Logs | none | Log Analytics, 30-day retention |

Why each control exists: [docs/threat-model.md](docs/threat-model.md) (STRIDE).
What it maps to: [docs/control-matrix.md](docs/control-matrix.md) (MCSB v2).

## Deploy

Prerequisites: `az` CLI logged in (`az login`), `jq`, `python3`.

```bash
RG=rg-aca-ref
LOC=westeurope
SUB=$(az account show --query id -o tsv)

# 1. Resource group
az group create -n $RG -l $LOC

# 2. Policy definitions (custom, from policy/*.json)
for p in policy/*.json; do
  name=$(basename $p .json)
  [ "$name" = "assignment" ] && continue
  az policy definition create --name $name --mode All \
    --rules $(jq -c '.properties.rules' $p)
done

# 3. Assign them in Deny mode at subscription scope
az deployment sub create -f policy/assignment.bicep
```

Now try the insecure deployment — it **fails** by policy:

```bash
# 4. Insecure: DENIED by policy (see output below)
az deployment group create -g $RG -f insecure/main.bicep
```

Expected output — the control working, not just written:

```
Deployment failed with error: 'The resource submission failed due to policy violation. Azure policy denied the deployment. The request id 8a9f3c2e-1b4d-4e5f-9a8b-7c6d5e4f3a2b is for tracking. Please refer to https://aka.ms/arm-requestid for usage details.'
```

The hardened deployment goes through:

```bash
# 5. Hardened: allowed
az deployment group create -g $RG -f hardened/main.bicep \
  -p sampleSecret="$SAMPLE_SECRET" budgetEmail="you@example.com"
```

Push your image to the ACR from step 5 (`az acr login`, `docker push`) and
the app starts. Tear everything down with `az group delete -n $RG --yes`.

## Tests

Offline — no subscription needed. Every policy must deny the insecure
fixture and allow the hardened one:

```bash
python3 tests/run_tests.py
```

```
Policy                           Insecure   Hardened   Result
----------------------------------------------------------------------
deny-insecure-transport          DENY       allow      PASS
deny-latest-tag                  DENY       allow      PASS
deny-overprivileged-role         DENY       allow      PASS
deny-plaintext-secrets           DENY       allow      PASS
deny-public-ingress              DENY       allow      PASS
require-managed-identity         DENY       allow      PASS
----------------------------------------------------------------------
All 6 policies deny insecure and allow hardened.
```

Live posture check after deploying hardened:

```bash
make verify   # tests + asserts internal ingress, identity, no admin creds, no :latest
```

## Limitations

Single region, no private endpoint to ACR/Key Vault, no WAF in front
(internal ingress makes it moot), `allowedCidr` is a placeholder, and the
`deny-overprivileged-role` policy is intentionally strict — scope the
assignment to the resource group in production instead of the subscription.

## Contributors

- [Leonardo Araya](https://github.com/LeoAra03) (@LeoAra03) — maintainer
