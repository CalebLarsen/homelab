# 0004 — New public hostnames need an explicit `cloudflared tunnel route dns`

## Context

Public services in this repo (currently `request.caleb.trade`,
`plex.caleb.trade`, `anki.caleb.trade`, plus a few static sites in the
notes role) are exposed through a single Cloudflare Tunnel managed by the
`cloudflared` role. The tunnel's ingress config lists per-hostname rules,
but Cloudflare also requires a separate **DNS** record (a CNAME pointing
the hostname at the tunnel) for traffic to reach the tunnel at all.

The `cloudflared tunnel route dns <tunnel> <hostname>` command creates
that CNAME. The wildcard route only runs when the tunnel is first
created.

## Decision

Adding a new public hostname (anything with `public: true` in
`inventory/group_vars/all/main.yml`, or a new vhost in `Caddyfile.j2` /
the notes role) requires either:

- An ad-hoc `cloudflared tunnel route dns <tunnel> <hostname>` invocation
  on the operator's machine, **or**
- An idempotent task in the `cloudflared` role that runs the equivalent
  for each `public: true` service.

Without one of these, the new hostname is accepted by the tunnel's ingress
config but Cloudflare's DNS never sends traffic to it.

## Why

The wildcard DNS route created at tunnel-creation time covers the apex
hostnames listed at that time, not arbitrary new ones added later. Each
new hostname is a new DNS record on the Cloudflare zone.

## What breaks if you undo this

A newly-added public service's hostname returns `Cloudflare: 1016 Origin
DNS error` (or similar), even though the tunnel is healthy and the
ingress rule is present. The fix is always to run
`cloudflared tunnel route dns ...` for that specific hostname.

## Verifying live state

```sh
cloudflared tunnel route ip show       # tunnel-level routes
# DNS records — check the Cloudflare dashboard or:
cloudflared tunnel info <tunnel-name>
```
