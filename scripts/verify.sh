#!/usr/bin/env bash
# Asserts the hardened posture: internal ingress, IP restrictions, HTTPS-only
# transport, user-assigned identity, ACR admin disabled, digest pin, Key Vault
# refs, user-defined egress, diagnostics, probes, minReplicas 1.
# Static checks always run; live checks run when the resource group exists.
set -euo pipefail

RG="${RG:-rg-aca-ref}"
APP="${APP:-aca-hardened-app}"
fail=0

pass() { echo "PASS: $1"; }
fail_msg() { echo "FAIL: $1"; fail=1; }

echo "== Static checks (hardened/ + policy) =="

check() {
  if grep -q "$1" hardened/main.bicep; then pass "$2"; else fail_msg "$2"; fi
}

check "adminUserEnabled: false" "ACR admin user disabled"
check "external: false" "ingress is internal"
check "allowInsecure: false" "transport is HTTPS-only"
check "ipSecurityRestrictions" "IP restrictions present"
check "keyVaultUrl" "secrets come from Key Vault"
check "outboundType: 'userDefined'" "egress is user-defined (firewall UDR)"
check "logAnalyticsConfiguration" "diagnostics to Log Analytics"
check "type: 'Liveness'" "liveness probe present"
check "type: 'Readiness'" "readiness probe present"
check "minReplicas: 1" "minReplicas is 1"
check "imageDigest" "image is digest-pinned"

if grep -q ":latest" hardened/main.bicep; then
  fail_msg "no :latest image tag allowed in hardened bicep"
else
  pass "no :latest in hardened bicep"
fi

for f in policy/deny-*.json policy/params.json; do
  if python3 -m json.tool "$f" > /dev/null; then
    pass "$f is valid JSON"
  else
    fail_msg "$f is not valid JSON"
  fi
done

echo "== Live checks (Azure) =="

if ! command -v az > /dev/null 2>&1; then
  echo "SKIP: az CLI not installed — live checks skipped"
  exit "$fail"
fi

if ! az group exists --name "$RG" --output tsv | grep -qi true; then
  echo "SKIP: resource group $RG not found — run 'make up' first"
  exit "$fail"
fi

external=$(az containerapp show -g "$RG" -n "$APP" --query 'properties.configuration.ingress.external' -o tsv)
if [ "$external" = "false" ]; then
  pass "ingress is internal (external=false)"
else
  fail_msg "ingress must be internal, got external=$external"
fi

identity_type=$(az containerapp show -g "$RG" -n "$APP" --query 'identity.type' -o tsv)
if [ "$identity_type" = "UserAssigned" ]; then
  pass "app uses user-assigned managed identity"
else
  fail_msg "app identity.type must be UserAssigned, got $identity_type"
fi

acr_name=$(az acr list -g "$RG" --query '[0].name' -o tsv)
admin=$(az acr show -g "$RG" -n "$acr_name" --query 'adminUserEnabled' -o tsv)
if [ "$admin" = "false" ]; then
  pass "ACR admin user disabled"
else
  fail_msg "ACR adminUserEnabled must be false"
fi

image=$(az containerapp show -g "$RG" -n "$APP" --query 'properties.template.containers[0].image' -o tsv)
case "$image" in
  *@sha256:*) pass "image is digest-pinned ($image)" ;;
  *) fail_msg "image must be digest-pinned, got $image" ;;
esac

exit "$fail"
