# Claude / agent guidance for this repo

This is an Ansible + Docker Compose homelab. The deploy is meant to be
idempotent. Bad suggestions (especially anything that touches a service's
SQLite DB or config file directly) cost real time to undo, so the rules below
are tighter than usual.

## The hallucination rule

**For every config key, env var, container path, API endpoint, or SQL
identifier you put into this repo, name the source.** Either:

- A URL to upstream docs (see `docs/sources.md` — this is the curated list of
  canonical doc URLs per service), or
- A path to a file in the running system you read first
  (`docker exec <container> cat <path>`, `sqlite3 <db> '.schema <table>'`,
  the project's own source on disk), or
- An existing call site in this repo (`roles/...`, `services/...`,
  `inventory/...`).

If you cannot cite one of those three for a specific key, **do not write it**.
Stop and tell the user what you tried to verify and what you couldn't find.
"I think this is right" is not good enough for stateful services — it is what
caused the cleanuparr SQL incident this guidance exists to prevent.

## Before suggesting SQL or direct DB writes

The cleanuparr provisioning in `roles/service_manager/tasks/api_wiring.yml`
seeds a SQLite DB with hand-written `INSERT` statements. Schemas drift
between releases and most projects in this repo do **not** publish their
schema. Before adding or changing any of these statements:

1. Check the live schema on the running container:
   `docker exec <container> sqlite3 /path/to.db '.schema <table>'`
2. Confirm the image tag in `inventory/group_vars/all/main.yml` is pinned
   (not `:latest`) so the schema you read matches what will deploy.
3. If upstream docs do not document the schema (this is the case for
   cleanuparr — see `docs/decisions/0005-cleanuparr-pinned-tag.md`), say so
   and rely on the live read, not memory.

## Before suggesting config keys for a service

1. Find the service's row in `docs/sources.md` and read the linked upstream
   page for the exact key, env var, or API field.
2. If the doc covers a different version than the pinned image tag, flag
   that explicitly.
3. Prefer reading the live container's mounted config
   (`docker exec <container> cat /config/<file>`) over recalling defaults.

## Before changing the deployment hierarchy

Read `docs/architecture.md` first — it explains where each layer of the
deploy lives (`site.yml` → roles → service_manager → per-service tasks →
compose templates), and which decisions are load-bearing (`docs/decisions/`).
A change in the wrong layer is how drift gets introduced.

## What to do when you're unsure

Say so. The user would much rather have "I checked the LSIO Sonarr docs and
the live `/config/sonarr.xml`, but I can't find a documented key for X"
than a confidently wrong answer. Half the cost of a bad suggestion in this
repo is the time to figure out *which* part was wrong after the fact.
