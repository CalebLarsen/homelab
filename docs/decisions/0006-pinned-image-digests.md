# 0006 — Pin every container image to `tag@digest`, never floating tags

## Context

Until 2026-04-26 most services in `inventory/group_vars/all/main.yml` ran
on `:latest`. A `docker compose pull` on any deploy could land a new
upstream release silently — same tag, different content. This is the
class of failure that motivated the pin on cleanuparr (decision 0005)
and on anki, and it is also the same trust gap that lets bad config
suggestions slip into the repo unverified (see `../../CLAUDE.md`).

We collected the live image, tag, and digest from every running container
on 2026-04-26 (`docker inspect <name> --format '{{.Config.Image}} {{.Image}}'`)
and pinned each entry in inventory.

## Decision

Every entry in the `services:` list must use one of two formats:

```yaml
image: "<repo>:<tag>@sha256:<digest>"   # preferred
image: "<repo>@sha256:<digest>"          # when upstream has no useful version label
```

Floating tags (`:latest`, `:stable`, `:nightly`, no tag at all) are
forbidden. The `roles/verify` role asserts this on every deploy.

The **digest is what resolves**. The tag is documentation for humans —
it tells you what version the digest corresponds to so you can read the
right release notes. If the tag and digest disagree, Docker uses the
digest.

## Why

- **Reproducibility.** A pinned digest is immutable. Two deploys at
  different times produce identical containers.
- **Schema and config safety.** The cleanuparr SQL coupling (decision 0005)
  and the anki volume layout shifts (see `docs/sources.md`) are the
  loudest examples; many other services have similar quieter coupling
  (DB migrations, config-key renames). Pinning makes upgrades a
  deliberate, auditable change.
- **Auditability.** The git diff for an upgrade shows the new digest.
  No mystery about when something changed.

## How to bump a pin

1. **Read upstream release notes** (links in `docs/sources.md`) and check
   for breaking changes — especially DB schema changes, env var
   renames, volume layout changes.
2. Pull the new image on the host:
   `docker pull <repo>:<new-tag>`
3. Get the new **manifest digest** (this is what compose pulls by, *not*
   the image config ID):
   `docker image inspect <repo>:<new-tag> --format '{{index .RepoDigests 0}}'`

   ⚠️ Do **not** use `docker inspect <container> --format '{{.Image}}'` —
   that returns the image config ID, which looks like a digest but is a
   different hash. Compose will fail to pull with
   `manifest schema unsupported` because the registry doesn't index by
   config ID. Always use `docker image inspect ... .RepoDigests`.

4. Update both the tag and the digest in `inventory/group_vars/all/main.yml`
   in the same commit. Do not split.
5. For schema-coupled services (cleanuparr, *arr DBs, anki), follow the
   per-service ADR's verification steps before re-deploying.
6. Re-deploy and confirm `roles/verify` passes.

## What breaks if you undo this

- A `docker compose pull` during routine deploys can land a new upstream
  release without warning. Symptoms: silent behavior changes, broken API
  contracts in `api_wiring.yml`, schema drift on the SQLite DBs the
  cleanuparr provisioning writes to, hardlink/EXDEV regressions if a base
  image's filesystem layout changes.
- Reproducing a working state from history becomes guesswork.

## Verifying pinning is in effect

`roles/verify` asserts every entry in `services[*].image` contains
`@sha256:`. Floats fail the deploy. To inspect manually:

```sh
grep 'image:' inventory/group_vars/all/main.yml | grep -v '@sha256:'
```

(should print only comments — any other line is an unpinned entry)
