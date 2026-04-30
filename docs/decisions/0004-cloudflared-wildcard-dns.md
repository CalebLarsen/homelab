# 0004 — A single wildcard CNAME routes all public subdomains

## Context

Public services in this repo (e.g. `request.caleb.trade`,
`plex.caleb.trade`, `anki.caleb.trade`, `note.caleb.trade`) are exposed
through a single Cloudflare Tunnel managed by the `cloudflared` role. Two
separate things need to be in place for a request to reach a backend:

1. A **DNS record** on the Cloudflare zone resolving the hostname to the
   tunnel (`<tunnel-id>.cfargotunnel.com`).
2. A **tunnel ingress rule** in `cloudflared_config.yaml.j2` telling
   `cloudflared` where to forward traffic once it arrives.

The ingress side is already handled by a wildcard rule
(`*.{{ cloudflare.domain }} → http://localhost:80`) that hands every
subdomain to Caddy, which fans out to backend containers by `Host` header.

The DNS side is what this decision is about. Earlier revisions of this
repo registered a CNAME per public hostname via
`cloudflared tunnel route dns <tunnel> <hostname>`, on the theory that a
wildcard CNAME at the apex (`*.caleb.trade`) didn't cover arbitrary new
subdomains. That theory was wrong — see "Why" below.

## Decision

We rely on a **single proxied wildcard CNAME** —
`*.{{ cloudflare.domain }} → <tunnel-id>.cfargotunnel.com` — to route
every public subdomain to the tunnel. Adding a new public service
requires:

- A `public: true` entry in `inventory/group_vars/all/main.yml` (which
  makes Caddy create the vhost), and
- Nothing else on the DNS side.

The wildcard CNAME is created once at tunnel-creation time by the
`Route Wildcard DNS locally` task in `roles/cloudflared/tasks/main.yml`.
The previous per-hostname loop and the matching task in
`roles/notes/tasks/main.yml` have been removed.

## Why

Cloudflare made proxied wildcard DNS records available on all plans on
2022-05-03 ([blog](https://blog.cloudflare.com/wildcard-proxy-for-everyone/),
[docs](https://developers.cloudflare.com/dns/manage-dns-records/reference/wildcard-dns-records/)).
A proxied `*.example.com` CNAME pointed at `<tunnel-id>.cfargotunnel.com`
resolves *any* one-level subdomain to a Cloudflare edge IP, and the edge
forwards the request through the tunnel based on the `Host` header.
Verified on this zone:

```sh
dig +short any-unconfigured-name.caleb.trade @1.1.1.1
# 104.21.44.168
# 172.67.201.148   ← Cloudflare edge, not NXDOMAIN
```

The earlier per-hostname loop was almost certainly compensating for a
silent failure of the *one-time* wildcard route task: that task runs only
`when: cloudflared_tunnel_exists.rc != 0` and has `failed_when: false`, so
if the initial invocation didn't actually create the wildcard CNAME there
was no signal and no retry. The per-hostname loop happened to paper over
that gap, which is why it looked like it was doing real work.

Universal SSL covers the apex plus one level of subdomain, so
`*.caleb.trade` is certificate-covered for free. Going deeper
(`a.b.caleb.trade`) would require Advanced Certificate Manager and is
out of scope here.

## What breaks if you undo this

- If the wildcard CNAME goes missing or gets switched to "DNS only" (grey
  cloud), every public subdomain returns `Cloudflare 1016 Origin DNS
  error` until the wildcard is restored proxied. The tunnel can be
  perfectly healthy and Caddy can be perfectly configured, and traffic
  still won't arrive.
- If you add a deeper level (`*.foo.caleb.trade` or `a.b.caleb.trade`),
  Universal SSL won't cover it; you either need ACM or a per-hostname
  CNAME with a per-hostname cert.

## Verifying live state

```sh
# DNS check from outside the local resolver cache:
dig +short something-unconfigured.caleb.trade @1.1.1.1
# Expect Cloudflare edge IPs (104.x / 172.x), NOT NXDOMAIN.

# Tunnel-level routes:
cloudflared tunnel info {{ cloudflare.tunnel_name }}

# Or look at the Cloudflare dashboard DNS tab — the `*` row should be
# orange-clouded (proxied), not grey (DNS only).
```
