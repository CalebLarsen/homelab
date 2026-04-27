# 0005 — Pin cleanuparr's image tag because the DB schema is undocumented

## Context

Cleanuparr does not expose its provisioning surface as an API: configuring
arr instances, download clients, queue cleaner rules, stall rules, and
seeker configs all require an admin user to be created via the web UI
first, then the rest of the config goes through the UI. There is no
documented headless bootstrap path and no documented public API for
seeding these tables.

To make the deploy idempotent, the `service-manager` role writes to the
container's two SQLite DBs directly — `users.db` and `cleanuparr.db` —
using hand-written `INSERT OR REPLACE` statements (see
`roles/service-manager/tasks/api_wiring.yml`, the
"Create Cleanuparr SQL Scripts" and "Inject Cleanuparr Configuration
Scripts (Post-start)" tasks).

The cleanuparr docs at https://cleanuparr.github.io/Cleanuparr/ do **not**
publish the DB schema. The schema is internal and changes between
releases.

## Decision

Cleanuparr's image is pinned to a specific tag in
`inventory/group_vars/all/main.yml` (currently
`ghcr.io/cleanuparr/cleanuparr:2.9.8`) — never `:latest`. The hand-written
SQL is coupled to that exact schema.

When you bump the tag:

1. Pull and start the new image **on a scratch host or `docker run`** with
   no SQL injection.
2. Compare the new schema to the SQL in `api_wiring.yml`:
   ```sh
   docker exec cleanuparr sqlite3 /config/cleanuparr.db .schema
   docker exec cleanuparr sqlite3 /config/users.db .schema
   ```
3. Update the `INSERT` column lists, table names, and any added/removed
   constraints in `api_wiring.yml` to match the new schema.
4. **Only then** update the tag in inventory and re-deploy.

## Why

A floating `:latest` tag means a `docker compose pull` could silently
pick up a schema-incompatible release. The provisioning SQL would then
either fail loudly (best case) or silently corrupt cleanuparr's state
(worst case). Pinning forces the schema check above to happen as a
deliberate, version-controlled change.

This is also the incident that motivated `../CLAUDE.md`'s hallucination
rule: a model (or human) who doesn't read the live schema before writing
SQL will produce statements that look plausible and don't apply to the
running version.

## What breaks if you undo this

Either:

- `sqlite3 -bail … < inject_configs.sql` exits non-zero mid-way through
  the deploy, leaving cleanuparr partially configured. Recovery: roll
  back the tag and re-run.
- The statements happen to apply to the new schema syntactically but mean
  something different (e.g. a renamed column, a new required NOT NULL
  column with a different default), corrupting the persisted config.
  Recovery: delete `cleanuparr.db`, roll back the tag, re-run.

## Verifying live state

Before any change to the cleanuparr SQL, always run the `.schema` check
above against the **currently-running** container, not the image you
think is running:

```sh
docker inspect cleanuparr --format '{{.Config.Image}}'
docker exec cleanuparr sqlite3 /config/cleanuparr.db .schema
```
