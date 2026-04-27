# 0008 — Pre-commit hooks as local CI; no cloud CI

## Context

Cloud CI (GitHub Actions, etc.) is the obvious "automated checks on every
push" tool, but the user has explicitly rejected it for this repo for two
reasons:

- Public Actions logs make secret-handling bugs (an `echo $SECRET`, a
  diff that includes a key, a leaked decrypted file in artifacts) into
  permanent disclosures. The repo's threat model treats committed
  encrypted secrets as safe and any decrypted form as a leak — running
  CI in a public-by-default environment violates that.
- Cloud CI uptime is best-effort, and a flaky run is just noise.

We still want the value cloud CI provides: lint, syntax checks, and a
check that the playbook is idempotent. We get that locally.

## Decision

The "CI" surface for this repo is:

1. **`pre-commit` hooks** that run on every `git commit`. Configured in
   `.pre-commit-config.yaml`. Hooks:
   - Standard `pre-commit/pre-commit-hooks`: trailing whitespace, EOF,
     merge-conflict markers, private-key detection, YAML syntax.
   - `yamllint` with config in `.yamllint` (relaxed: line-length warning
     only, Ansible truthy values allowed).
   - `ansible-lint` scoped to playbooks and roles.
   - Local `scripts/check-sops-encrypted.sh` — refuses to commit a
     `*.sops.yml` file that lacks a `sops:` metadata block.
2. **`make verify-local`** — what cloud CI would run, but on the operator's
   machine. Runs all hooks, `ansible-playbook --syntax-check`, and a
   `--check --diff` dry-run against the live host. Use before pushing
   meaningful changes.
3. **`roles/verify`** — runs as the last step of every real deploy.
   Asserts the load-bearing decisions in `docs/decisions/` are still
   intact (mergerfs cache, hardlinks, image pinning, cleanuparr schema).

Order of trust: a change has to pass pre-commit on the way in, and verify
on the way out. The dry-run in the middle is optional.

## Why

- All checks happen on a machine the operator controls. No leaked
  secrets in third-party logs.
- No CI uptime dependency — the deploy works whether GitHub is up or
  not.
- The same `pre-commit` config can be lifted into cloud CI later if
  the threat model changes; nothing is lost by starting local.

## What breaks if you skip this

- Easy class of mistakes (trailing whitespace, merge markers, private
  keys, accidentally-decrypted SOPS files) lands in commits.
- Ansible syntax errors or undefined-variable references make it to the
  host before being caught.
- `:latest` tags or unpinned images sneak past — both `ansible-lint` and
  `roles/verify` (decision 0006) catch this, but only if the verify
  layer runs.

## Onboarding (one-time per clone)

```sh
pip install pre-commit ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
pre-commit install
# Optional: refresh hook versions
pre-commit autoupdate
```

The `ansible-galaxy collection install` step is required: ansible-lint's
syntax-check rule resolves modules like `community.docker.docker_compose_v2`
against your installed collections. Without those installed, every
`docker_compose_v2` and `community.sops`-using task fails as
`syntax-check[unknown-module]`.

The `pre-commit install` command writes a hook into `.git/hooks/pre-commit`
that runs the configured hooks on staged files. Bypass with `--no-verify`
**only** when you understand exactly which check you are skipping and
why; it should be rare enough to be uncomfortable.

## Profile and skips

The config sits at `profile: production` — the strictest built-in
profile. Picking `production` was a deliberate choice: it forced us to
fix mechanical issues (FQCN prefixes, file modes, shell pipefail,
changed_when, etc.) rather than skip them. The earlier `profile: min`
setting was hiding rules entirely; `production` is the right surface.

`skip_list` is empty. Every rule under the `production` profile is
enforced. Per-task `# noqa: <rule>  # reason` is preferred over global
skips for any rule that's right most of the time but wrong in one
specific spot.

Per-task skips currently in place:
- `roles/service_manager/tasks/per_service/qbittorrent.yml`:
  `# noqa: no-handler` on the `Apply qBittorrent config change` block
  because qBittorrent must be stopped *before* the template is written
  or it clobbers the edit from its in-memory state — the inline-block
  pattern is required, not a handler.

Variable naming convention enforced by `var-naming[no-role-prefix]`:
every `register:` and `set_fact:` declared inside a role is prefixed
with the role name (`backup_*`, `cloudflared_*`, `mergerfs_*`,
`service_manager_*`, `verify_*`). Cross-role play-level variables
(API keys passed via secrets, the `services` list, etc.) are exempt
because they're not declared inside roles.

If you write new code that would hit one of these rules, follow the
established pattern (e.g. `set -o pipefail` in shell pipes, `mode:` on
file tasks, role-name underscores not hyphens, role-prefixed registers).
