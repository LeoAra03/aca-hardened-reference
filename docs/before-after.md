# Before / after — what each control buys

The README table in prose: for every row, the insecure shape, the hardened
shape, and the specific failure the hardened shape prevents. Read this if you
want the reasoning; read the README if you want the diff.

## Ingress — direct public reach, WAF bypass
Insecure: `external: true` gives the app a public FQDN. Anyone on the
internet can reach it, and any WAF you bolt on later can be bypassed by
hitting the FQDN directly. Hardened: `external: false` plus
`ipSecurityRestrictions` with default Deny — the app is only reachable from
the app network, and only from the CIDR you allow.

## Transport — bearer token in cleartext
Insecure: `allowInsecure: true` serves plain HTTP. Any bearer token, API
key, or session cookie crosses the wire readable. Hardened:
`allowInsecure: false` — HTTPS only, and internal ingress removes the
sniffing surface entirely.

## Secrets — secret in ARM history and `containerapp show` output
Insecure: `env.value` is stored literally in the ARM template, the
deployment history, and the `containerapp show` output. Anyone with read
access to the deployment can read it. Hardened: the value lives in Key
Vault; the app references it with `keyVaultUrl` + `secretRef`, resolved at
runtime by the managed identity.

## Identity — registry pull over admin credentials; over-scoped RBAC
Insecure: no identity at all, so registry access falls back to admin
credentials or public images. Hardened: a user-assigned identity with
`AcrPull` on the registry and `Key Vault Secrets User` on the vault — it
can pull images and read secrets, and nothing else.

## Image — non-reproducible deploys, no rollback target
Insecure: `:latest` is mutable. The image you audited yesterday is not the
image you run today, and there is no digest to roll back to. Hardened: the
image is pinned by digest (`@sha256:...`), so a deploy is reproducible and
a rollback target exists.

## Scaling — cold-start auth timeouts masking a DoS
Insecure: `minReplicas: 0` means the first request after idle pays a cold
start. Under load this looks like a slow app; under attack it looks like
the app is down. Hardened: `minReplicas: 1` keeps one replica warm, so
latency is predictable and a DoS is visible as a DoS.

## Egress — unrestricted egress, no egress inspection
Insecure: default egress. The app can reach any address on the internet,
and nothing inspects what leaves. Hardened: `outboundType: userDefined`
with a UDR to a firewall — egress is inspected and can be allow-listed.
(Assumes a firewall that is not in this repo.)

## Diagnostics — no audit trail
Insecure: no log destination. When something goes wrong, there is nothing
to investigate. Hardened: Log Analytics via `logAnalyticsConfiguration`
with 30-day retention — every request and system event is recorded.

## Health — traffic to a half-started replica
Insecure: no probes. The platform sends traffic to replicas that are not
ready yet. Hardened: liveness + readiness probes, so traffic only reaches
replicas that can actually serve it.

## Policy — regression by copy-paste
Insecure: no policy. The next person who copies the sample reintroduces
every issue above. Hardened: Deny assignments on both resource types, so
the insecure shape cannot be deployed again — the failing deploy in the
README is the proof.
