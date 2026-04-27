# Documentation sources, per service

The canonical upstream docs to consult before suggesting any config key, env
var, container path, API endpoint, or SQL identifier for a service in this
repo. Pinned image tags from `inventory/group_vars/all/main.yml` are listed
so you can confirm you are reading docs for the right version.

When a row says **"no schema docs"**, the upstream project does not publish
its DB schema. Read the live container's DB before writing SQL — see
`../CLAUDE.md`.

URLs in this file were spot-checked via WebFetch on 2026-04-26. If a link
404s, fix it here in the same PR as the change you were making.

## The *arr stack

Sonarr, Radarr, Prowlarr, and Bazarr share an ecosystem of docs (Servarr
wiki for cross-cutting topics, project-specific sites for API references,
LinuxServer.io docs for the Docker images we actually run).

| Service | Image | Upstream project / repo | API reference | Settings reference | Docker image docs |
| --- | --- | --- | --- | --- | --- |
| sonarr | `lscr.io/linuxserver/sonarr:latest` | https://sonarr.tv/ | https://sonarr.tv/docs/api/ | https://wiki.servarr.com/sonarr/settings | https://docs.linuxserver.io/images/docker-sonarr/ |
| radarr | `lscr.io/linuxserver/radarr:latest` | https://radarr.video/ | https://radarr.video/docs/api/ | https://wiki.servarr.com/radarr/settings | https://docs.linuxserver.io/images/docker-radarr/ |
| prowlarr | `lscr.io/linuxserver/prowlarr:latest` | https://prowlarr.com/ | https://prowlarr.com/docs/api/ | https://wiki.servarr.com/prowlarr/settings | https://docs.linuxserver.io/images/docker-prowlarr/ |
| bazarr | `lscr.io/linuxserver/bazarr:latest` | https://www.bazarr.media/ | (uses Sonarr/Radarr APIs; no public REST API of its own) | https://wiki.bazarr.media/ | https://docs.linuxserver.io/images/docker-bazarr/ |

Servarr wiki landing page: https://wiki.servarr.com/ — check here for
cross-cutting topics (custom formats, quality profiles, naming).

## Download stack

| Service | Image | Upstream project / repo | API / config reference | Docker image docs |
| --- | --- | --- | --- | --- |
| qbittorrent | `lscr.io/linuxserver/qbittorrent:latest` | https://www.qbittorrent.org/ | WebUI API: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-5.0) — Settings: https://github.com/qbittorrent/qBittorrent/wiki/Explanation-of-Options-in-qBittorrent | https://docs.linuxserver.io/images/docker-qbittorrent/ |
| gluetun | `qmcgaw/gluetun:latest` | https://github.com/qdm12/gluetun | Wiki: https://github.com/qdm12/gluetun-wiki — Mullvad: https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/mullvad.md | (no separate image docs; wiki covers Docker usage) |
| flaresolverr | `ghcr.io/flaresolverr/flaresolverr:latest` | https://github.com/FlareSolverr/FlareSolverr | README is canonical: https://github.com/FlareSolverr/FlareSolverr#readme (env vars + API endpoints) | (none separate) |
| cross-seed | `ghcr.io/cross-seed/cross-seed:latest` | https://www.cross-seed.org/ | Options reference: https://www.cross-seed.org/docs/basics/options — Getting started: https://www.cross-seed.org/docs/basics/getting-started | (none separate; site covers Docker) |

## Media servers / clients

| Service | Image | Upstream project / repo | API / config reference | Docker image docs |
| --- | --- | --- | --- | --- |
| plex | `lscr.io/linuxserver/plex:latest` | https://www.plex.tv/ | https://support.plex.tv/articles/ (Plex Media Server section); unofficial API map: https://github.com/Arcanemagus/plex-api/wiki | https://docs.linuxserver.io/images/docker-plex/ |
| tautulli | `lscr.io/linuxserver/tautulli:latest` | https://tautulli.com/ | API: https://github.com/Tautulli/Tautulli/wiki/Tautulli-API-Reference — Wiki: https://github.com/Tautulli/Tautulli/wiki | https://docs.linuxserver.io/images/docker-tautulli/ |
| audiobookshelf | `ghcr.io/advplyr/audiobookshelf:latest` | https://www.audiobookshelf.org/ | Server config + env vars: https://www.audiobookshelf.org/docs — API (marked out of date by upstream): https://api.audiobookshelf.org/ | (none separate; advplyr publishes the image directly) |
| anki | `jeankhawand/anki-sync-server:25.07` | https://hub.docker.com/r/jeankhawand/anki-sync-server | Image docs (env, ports, volume layout): https://hub.docker.com/r/jeankhawand/anki-sync-server — Upstream protocol: https://github.com/ankitects/anki/tree/main/docs/syncserver | (Docker Hub page is the source) |

**Note on anki:** the Docker Hub page documents that volume paths change
between tag families (`/anki_data` for 25.02.6+ simple tags vs
`/root/.syncserver` for distroless). The pin in
`inventory/group_vars/all/main.yml` exists for this reason. Read the Docker
Hub page before bumping the tag.

## Request / management

| Service | Image | Upstream project / repo | API / config reference | Docker image docs |
| --- | --- | --- | --- | --- |
| overseerr (Seerr) | `ghcr.io/seerr-team/seerr:v3.2.0` ⚠️ pinned | https://github.com/seerr-team/seerr | Docs: https://docs.seerr.dev/ — Migration guide: https://docs.seerr.dev/migration-guide — API still served at `/api/v1/docs` on the running instance | (none separate; image is built by the project) |
| kometa | `kometateam/kometa:latest` | https://kometa.wiki/ | Config overview: https://kometa.wiki/en/config/overview — Builders/filters: https://kometa.wiki/en/latest/ | (none separate; image is built by the project) |
| recyclarr | `ghcr.io/recyclarr/recyclarr:latest` | https://recyclarr.dev/ | Configuration reference: https://recyclarr.dev/wiki/reference/configuration/ — Wiki: https://recyclarr.dev/wiki/ | (none separate) |
| cleanuparr | `ghcr.io/cleanuparr/cleanuparr:2.9.8` ⚠️ pinned | https://github.com/Cleanuparr/Cleanuparr | Docs site: https://cleanuparr.github.io/Cleanuparr/ — **no schema docs**: see `decisions/0005-cleanuparr-pinned-tag.md` and read the live DB schema before any SQL change | (none separate) |

**Note on overseerr:** the service is still named `overseerr` in the
inventory and DNS (`request.caleb.trade`), but the image is now Seerr —
the unified project that merged the archived sct/overseerr (2026-02-15)
with Jellyseerr. Migration was performed 2026-04-26 (see
`decisions/0007-overseerr-to-seerr-migration.md`). The settings.json and
db.sqlite3 were auto-migrated in place by Seerr on first boot. Container
config path is `/app/config` (was `/config` on the LSIO image).

## Reverse proxy / network edge

| Service | Image | Upstream project / repo | Config reference | Docker image docs |
| --- | --- | --- | --- | --- |
| caddy | `caddy:latest` | https://caddyserver.com/ | Caddyfile: https://caddyserver.com/docs/caddyfile — JSON: https://caddyserver.com/docs/json/ — Modules: https://caddyserver.com/docs/modules/ | https://hub.docker.com/_/caddy |
| cloudflared | (host-installed via the `cloudflared` role, not a container) | https://github.com/cloudflare/cloudflared | https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/ — `cloudflared tunnel route dns` is per-hostname; see `decisions/0004-cloudflared-per-hostname-dns.md` | (n/a — host install) |

## How to use this file

1. Identify the service you are about to suggest a change for.
2. Open the row's "API reference" or "Settings reference" link.
3. Confirm the key, endpoint, or env var you are about to write actually
   exists in that doc.
4. If the doc covers a different version than the pinned image tag, flag
   that to the user before writing.
5. If the doc says **"no schema docs"** (or you cannot find the key), do
   not guess. Read the live container's config or DB instead, and tell
   the user what you read.
