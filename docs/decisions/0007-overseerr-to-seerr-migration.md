# 0007 — Migrate overseerr → Seerr (planned, not yet executed)

> **Status:** planned. Migration has not been performed. Update this ADR
> when the work is done with the as-built sequence and any deviations.

## Context

The `lscr.io/linuxserver/overseerr` image we deploy tracks the original
`sct/overseerr` codebase, which was archived 2026-02-15 in favor of
**Seerr** — a unified project that merged Overseerr and Jellyseerr
(see `docs/sources.md` for the current docs URL). Continuing on the
archived fork means no security fixes, no Plex/TMDb API drift fixes, and
no new features.

The user's overseerr instance is a **stateful** service: requests, users,
mapped Plex libraries, and Sonarr/Radarr connections all live in
`/home/caleb/config/overseerr/db/db.sqlite3` and `settings.json`. A naive
image swap is unlikely to work because Seerr's schema and settings
format diverged from Overseerr's at some point during the merger.

## Decision (planned)

Migrate to the official Seerr image as a one-shot, scheduled operation:

1. Take a backup of `/home/caleb/config/overseerr/` (use the restic backup
   role if landed by then; otherwise a manual `tar -czf`).
2. Read Seerr's migration guide (https://docs.seerr.dev/) for the
   *current* recommended path. Likely options:
   - Seerr provides an Overseerr import path that reads the existing DB
     and settings, OR
   - A manual export/re-config is required.
3. Provision a fresh appdata directory for Seerr
   (`/home/caleb/config/seerr/`), update inventory:
   - Rename the service from `overseerr` to `seerr` (or keep `overseerr`
     for less inventory churn — decision time).
   - Swap `image:` to the official Seerr image with a pinned digest
     (decision 0006).
   - Update `subdomain: "request"` if the new instance should keep that
     hostname.
4. Re-render the compose template and stop overseerr cleanly first
   (`docker compose down`) so any in-memory state is flushed.
5. If Seerr supports importing Overseerr's data, run that step pointed
   at the backed-up appdata.
6. Update `roles/service_manager/tasks/api_wiring.yml`:
   - Endpoints, settings format, and API auth may differ. Re-verify each
     `uri` task against Seerr's API reference.
   - The `overseerr_settings.json.j2` template likely needs rewriting.
7. Update `docs/sources.md` to point at Seerr instead of Overseerr.
8. Run the deploy. Confirm via `roles/verify` that public access through
   the tunnel (`request.caleb.trade`) and Sonarr/Radarr/Plex wiring
   still pass.
9. After at least one week of clean operation, archive
   `/home/caleb/config/overseerr/` to the backup target and remove from
   the live host.

## Why

The archived overseerr will accumulate untriaged bugs and unpatched
dependencies. The user has explicitly chosen to follow upstream rather
than maintain a fork.

## What breaks if you skip the migration plan

- **Lost request history** if the DB schema changed and the import path
  is skipped. Users would re-request media that was already approved.
- **Broken Sonarr/Radarr/Plex wiring** if `api_wiring.yml`'s endpoints
  point at routes Seerr renamed.
- **Public DNS gap** if the inventory rename happens without a matching
  cloudflared route refresh — see decision 0004.

## Open questions for the migration session

- Does Seerr support direct import of an Overseerr `db.sqlite3`? (Read
  https://docs.seerr.dev/migration before starting.)
- Is the LSIO project planning a `linuxserver/seerr` image, or is the
  upstream `seerr/seerr` (or whatever the canonical image is) the
  right target?
- Does Seerr's settings.json schema match Overseerr's closely enough that
  `overseerr_settings.json.j2` only needs key renames, or is a full
  rewrite required?

Resolve these by reading https://docs.seerr.dev/ at the time of the
migration; do not bake answers into this ADR ahead of time, since the
docs site is the moving target.
