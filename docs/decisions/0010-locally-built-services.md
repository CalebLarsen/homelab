# 0010 — Locally-built services are exempt from digest pinning

## Context

Decision 0006 mandates that every entry in `services:` carries a
`<repo>:<tag>@sha256:<digest>` image. The digest is what makes the
deploy reproducible; the registry resolves it to immutable bytes.

Some services in this homelab are not third-party images — they are
small, self-written apps (currently: `phone-logger`,
`github.com/CalebLarsen/phone-logger`). They have no registry image and
no manifest digest. They are also not subject to the failure modes that
0006 was written to prevent:

- **Schema drift** (the cleanuparr / *arr / anki problem) — these are
  our own apps; we control the on-disk format.
- **Silent upstream releases** — there is no upstream releasing without
  our knowledge. Source changes show up in the upstream repo's git log.

Forcing a registry-and-digest workflow on a 90-line Flask app would mean
standing up a CI publish pipeline (or pushing to GHCR by hand on every
change) for no risk-management benefit.

## Decision

A service entry may set `build_local: true` instead of providing an
`image:` with a digest. When `build_local` is true:

1. **Source comes from a separate public repo.** The service entry
   includes a `source_repo` (git URL) and `source_branch` (default
   `main`). The homelab role clones it to a known path on the host and
   builds the image locally.
2. **`image:` is a local tag**, not a registry reference (e.g.
   `phone-logger:local`). It is what `docker compose` will tag the
   build output as and what the compose template will reference.
3. **`roles/verify` skips the `@sha256:` assertion** for these entries
   only. Every other 0006 invariant still applies to every other
   service.
4. **Reproducibility** comes from git: the source is in a tracked
   public repo. Bumping the version is `git pull` plus an explicit
   commit in this homelab repo if `source_branch` is changed.

Currently `phone-logger` tracks `main` because the user owns that repo.
If a future locally-built service is shared with collaborators, pin it
to a commit SHA in `source_branch` rather than tracking a moving branch.

## Why

- **Source-of-truth is git, not a registry.** A public repo at a known
  commit is just as reproducible as a registry digest, with simpler
  ergonomics for an app you own.
- **No CI publish pipeline.** This homelab has no cloud CI by design
  (decision 0008); requiring one for a small Flask service contradicts
  that.
- **Risk model is different.** 0006 protects against silent third-party
  changes. There is no third party here.
- **Privacy boundary is preserved.** Source lives in a public repo;
  data lives only on the host (`{{ config_root }}/<service>/`) and is
  never committed. Any locally-built service must keep this separation.

## How to add a new locally-built service

1. **Author the source in its own public repo**, with a `Dockerfile` and
   a `docker-compose.yml` that uses an env-var-driven absolute data
   path (never `./data` — see `phone-logger`'s compose for the pattern).
   Add `data/` to `.gitignore`.
2. **Add an entry** to `services:` in
   `inventory/group_vars/all/main.yml`:
   ```yaml
   - name: <service>
     port: <host port>
     image: "<service>:local"
     build_local: true
     source_repo: "https://github.com/<owner>/<service>.git"
     source_branch: "main"   # or a pinned commit SHA
   ```
3. **Add a per-service task**
   `roles/service_manager/tasks/per_service/<service>.yml` that:
   - clones / fast-forwards `source_repo` into a known directory on the
     host
   - runs `docker build -t <image> <source_dir>`
   - ensures the data directory exists under `{{ config_root }}`
4. **Add a compose template** under `services/<service>/` that
   references the locally-built image tag and bind-mounts
   `{{ config_root }}/<service>/data` (or whatever the app expects).
5. **No DNS step** is needed even for `public: true` services — the
   zone's wildcard CNAME (decision 0004) covers them. Most locally-built
   services are internal-only by intent anyway.

## What breaks if you undo this

- A locally-built service that doesn't carve out the verify exemption
  fails the `@sha256:` assertion and blocks every deploy.
- A locally-built service that commits its `data/` directory to the
  public source repo leaks PII the moment it is pushed. The
  `data/`-in-`.gitignore` + absolute-path data mount pattern is the
  guardrail; do not weaken it.

## Verifying the exemption is in effect

```sh
grep -E '^\s*-\s*name:|build_local:' inventory/group_vars/all/main.yml
```

should show `build_local: true` only on entries whose `image:` does
*not* contain `@sha256:` — and `roles/verify` should still pass on
every deploy.
