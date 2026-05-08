# 0011 — `FIREWALL_OUTBOUND_SUBNETS` must not capture the VPN's in-tunnel NAT-PMP gateway

## Context

After migrating the gluetun stack from Mullvad WireGuard to ProtonVPN
WireGuard with dynamic port forwarding (NAT-PMP), gluetun's port-forwarding
service failed every reconnect with:

```
[vpn] starting port forwarding service: ... reading from udp connection:
read udp 172.18.0.14:NNNNN->10.2.0.1:5351: recvfrom: no route to host
```

`/tmp/gluetun/forwarded_port` was never written, qBittorrent had no public
listening port, and inbound peer connections were impossible (seeding-only
trackers and DHT peers had no way to reach the client).

The compose template carried this from the Mullvad days:

```yaml
- FIREWALL_OUTBOUND_SUBNETS="192.168.0.0/16,172.16.0.0/12,10.0.0.0/8,100.64.0.0/10"
```

`FIREWALL_OUTBOUND_SUBNETS` tells gluetun which RFC1918 ranges to bypass
the VPN tunnel for. ProtonVPN's NAT-PMP gateway lives at **10.2.0.1**
inside the WireGuard tunnel — which sits inside `10.0.0.0/8`. So gluetun
was routing its own NAT-PMP requests via the docker bridge (eth0,
`172.18.0.x`) instead of through the tunnel (tun0, `10.2.0.2`). The
docker-bridge gateway has no route to a private RFC1918 address that only
exists at the WireGuard peer; the kernel returned ICMP host-unreachable
and gluetun saw it as `recvfrom: no route to host`.

The source-IP field in the error confirmed the diagnosis: the local end
of the failing UDP socket was `172.18.0.14` (eth0), not `10.2.0.2` (tun0).

This was invisible under Mullvad because Mullvad's port forwarding (when
it still existed) was static — it never sent NAT-PMP into the tunnel.
Any VPN provider that uses NAT-PMP at an in-tunnel `10.x.x.x` address
trips the same trap: ProtonVPN, PIA, AirVPN.

## Decision

`FIREWALL_OUTBOUND_SUBNETS` in `services/gluetun/docker-compose.yml.j2` is
limited to ranges that do **not** overlap the VPN provider's in-tunnel
addressing:

```yaml
- FIREWALL_OUTBOUND_SUBNETS="192.168.0.0/16,172.16.0.0/12,100.64.0.0/10"
```

If a service ever needs to reach a specific `10.x.x.x` host on the LAN
without going through the VPN, add a **more-specific** CIDR for it (e.g.
`10.42.0.0/16`) — never re-add the whole `10.0.0.0/8`.

## Why

`FIREWALL_OUTBOUND_SUBNETS` is a coarse "don't tunnel this" filter, and
on a `/8` it swallows the VPN's own internal subnet. The VPN tunnel uses
RFC1918 space too, so any LAN-bypass list has to be narrower than the
tunnel's subnet to avoid breaking provider-internal services like
NAT-PMP, the DNS resolver, or the metadata endpoint.

## What breaks if you undo this

- gluetun's NAT-PMP requests fail with `recvfrom: no route to host`.
- `/tmp/gluetun/forwarded_port` is never written.
- The `VPN_PORT_FORWARDING_UP_COMMAND` hook never fires, so qBittorrent's
  listen port stays whatever it was at boot — almost certainly not the
  port Proton would have forwarded.
- qBittorrent appears healthy but is firewalled: outbound peer
  connections work, inbound do not, seeding stalls.

## Verifying live state

```sh
# (1) gluetun has a forwarded port — non-empty, numeric
docker exec gluetun cat /tmp/gluetun/forwarded_port

# (2) The settings dump shows the bypass list. 10.0.0.0/8 must NOT appear.
docker logs gluetun 2>&1 | grep -A6 'Firewall settings'

# (3) qBittorrent's listen port matches what gluetun forwarded
#     (LocalHostAuthentication=false in qBittorrent.conf lets this skip auth)
docker exec gluetun wget -qO- \
  --header='Referer: http://localhost:6969' \
  http://localhost:6969/api/v2/app/preferences \
  | tr ',' '\n' | grep listen_port
```

The Ansible verify role (see
`roles/verify/tasks/main.yml`) also asserts (1) on every deploy.
