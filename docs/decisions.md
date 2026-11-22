# Decisions

## Internal ingress by default
A public sample teaches the wrong default. Exposure becomes an explicit `externalIngress` parameter, and the policy denies public ingress at subscription scope, so a PR that flips it needs a policy exception.

## Managed identity over secrets
Connection strings and registry passwords are the top source of leaked credentials in container samples. The identity pulls from ACR and reaches Log Analytics; there is no secret to rotate.

## Policy at subscription scope
Resource-scoped policy is trivially bypassed by deploying outside the template. Subscription assignment catches drift from any tool.

## Budget alarm instead of a hard cap
Container Apps has no hard spend cap. An alarm at 20 EUR plus scale-to-zero bounds the blast radius of a forgotten environment.
