#!/usr/bin/env bash
# Live policy tests: for each policy, deploy it into a scratch resource
# group, then deploy the insecure app and assert RequestDisallowedByPolicy.
# A policy that has never denied a resource is a policy you have not written.
# Requires: az CLI logged in (az login) and a subscription.
# Usage: bash tests/run-policy-tests.sh
set -u

LOC="${LOC:-eastus}"
fail=0

for p in policy/deny-*.json; do
  name=$(basename "$p" .json)
  rg="rg-test-$name"
  echo "== $name =="
  az group create -n "$rg" -l "$LOC" --output none
  az deployment group create -g "$rg" -f "$p" -p @policy/params.json --output none

  if az deployment group create -g "$rg" -f insecure/main.bicep --output none 2> /tmp/policy-test-err.txt; then
    echo "FAIL: insecure deployed despite $name"
    fail=1
  else
    if grep -qi "RequestDisallowedByPolicy\|policy violation" /tmp/policy-test-err.txt; then
      echo "PASS: $name denied insecure (RequestDisallowedByPolicy)"
    else
      echo "FAIL: insecure failed for an unexpected reason:"
      cat /tmp/policy-test-err.txt
      fail=1
    fi
  fi

  az group delete -n "$rg" --yes --no-wait --output none
done

# The hardened column must still deploy clean.
echo "== hardened =="
rg="rg-test-hardened"
az group create -n "$rg" -l "$LOC" --output none
for p in policy/deny-*.json; do
  az deployment group create -g "$rg" -f "$p" -p @policy/params.json --output none
done
if az deployment group create -g "$rg" -f hardened/main.bicep \
  -p sampleSecret="test-secret" --output none; then
  echo "PASS: hardened deployed clean"
else
  echo "FAIL: hardened was denied"
  fail=1
fi
az group delete -n "$rg" --yes --no-wait --output none

exit "$fail"
