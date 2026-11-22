#!/usr/bin/env bash
# Asserts the hardened posture: internal ingress, IP restrictions,
# user-assigned identity, ACR admin disabled, no :latest, Key Vault refs,
# minReplicas 1. Static checks always run; live checks run when the
# resource group exists.
set -euo pipefail

RG="${RG:-rg-aca-ref}"
APP="${APP:-aca-hardened-app}"
fail=0

pass() { echo "PASS: $1"; }
fail_msg() { echo "FAIL: $1"; fail=1; }

echo "== Static checks (hardened/ + policy) =="

if grep -q "adminUserEnabled: false" hardened/main.bicep; then
  pass "ACR admin user disabled in hardened bicep"
else
  fail_msg "ACR adminUserEnabled must be false"
fi

if grep -q "external: false" hardened/main.bicep; then
  pass "ingress is internal in hardened bicep"
else
  fail_msg "hardened ingress must be internal (external: false)"
fi

if grep -q "ipSecurityRestrictions" hardened/main.bicep; then
  pass "IP restrictions present"
else
  fail_msg "hardened must set ipSecurityRestrictions"
fi

if grep -q "keyVaultUrl" hardened/main.bicep; then
  pass "secrets come from Key Vault"
else
  fail_msg "hardened must use keyVaultUrl"
fi

if grep -q "minReplicas: 1" hardened/main.bicep; then
  pass "minReplicas is 1"
else
  fail_msg "hardened minReplicas must be 1"
fi

if grep -q ":latest" hardened/main.bicep; then
  fail_msg "no :latest image tag allowed in hardened bicep"
else
  pass "no :latest in hardened bicep"
fi

for f in policy/*.json; do
  if python3 -m json.tool "$f" > /dev/null; then
    pass "$f is valid JSON"
  else
    fail_msg "$f is not valid JSON"
  fi
  if jq -e '.properties.rules.then.effect == "deny"' "$f" > /dev/null; then
    pass "$f denies on violation"
  else
    fail_msg "$f must deny on violation"
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
  *:latest) fail_msg "image must not use :latest, got $image" ;;
  *) pass "image is pinned ($image)" ;;
esac

exit "$fail"
