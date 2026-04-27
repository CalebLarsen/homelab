# Secrets onboarding

Secrets in this repo are SOPS-encrypted with `age` and committed in plain
sight. The encrypted file is safe in the git history; the age private key
is what guards it. Lose every copy of the age private key and the secrets
are unrecoverable — back it up.

## What lives where

| Path | What it is | Encrypted? |
| --- | --- | --- |
| `inventory/group_vars/all/secrets.sops.yml` | All runtime secrets (Mullvad WireGuard key, *arr API keys, admin password, Plex token, Cloudflare credentials, etc.) | Yes — committed encrypted |
| `.sops.yaml` | SOPS rules — declares which path patterns get encrypted, and which age public keys can decrypt them | No (public key only) |
| `~/.config/sops/age/keys.txt` | **The age private key**. Per-operator, never committed, never copied without intent. | n/a — local only |

The Ansible side picks up secrets automatically via the `community.sops.sops`
vars plugin (declared in `ansible.cfg`'s `vars_plugins_enabled`). At
playbook run time it sees `secrets.sops.yml`, decrypts it in memory using
the age key at `SOPS_AGE_KEY_FILE` (or `~/.config/sops/age/keys.txt`),
and exposes the values as group_vars. No on-disk decrypted artifact
should ever exist; `decrypted_secrets.yml` and `*.decrypted.yml` are in
`.gitignore` as a tripwire.

## First-time setup (you've never run this repo)

```sh
# 1. Install the tools
brew install sops age   # macOS — see DEPENDENCIES.md for Linux

# 2. Generate your age keypair (one-time, machine-local)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
# The file contains both the secret key and a `# public key:` comment.

# 3. Print your public key — you'll need to add it as a recipient
grep 'public key:' ~/.config/sops/age/keys.txt
```

After that, **either**:

- You're the first/only operator: use `make _init` (the Makefile has a
  helper that wires up `.sops.yaml` and creates a fresh
  `secrets.sops.yml`), then fill in the actual secret values with
  `make edit-secrets`.
- An existing operator has the repo set up: they need to **add your
  public key as a recipient** (see "Adding a recipient" below) and push
  the rotated file. After that you can `make edit-secrets` to verify
  decryption works on your machine.

## Daily use

| Action | Command |
| --- | --- |
| Edit secrets | `make edit-secrets` (decrypts, opens `$EDITOR`, re-encrypts on save) |
| Read a single value | `sops -d inventory/group_vars/all/secrets.sops.yml \| yq '.api_keys.sonarr'` |
| Run the playbook | `make deploy` (Ansible decrypts in memory at run time) |
| Encrypt a new file matching the rules | `sops -e -i <path>` |
| Decrypt for inspection (don't save!) | `sops -d <path>` |

`make edit-secrets` exports `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`
itself — Ansible-driven decryption uses the same env var, so set it in
your shell profile if you run `ansible-playbook` directly:

```sh
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

## Adding a recipient (e.g. a new operator or new machine)

A recipient is an age **public** key. Every recipient listed in
`.sops.yaml` for a path can decrypt that path. Adding one is a re-encrypt,
not a key copy.

```sh
# 1. Get the new operator's age public key (they ran `age-keygen` and
#    sent you the line starting with `age1...`).
NEW_KEY="age1abc...xyz"

# 2. Add it to .sops.yaml under the same path_regex as the existing key
#    (comma-separated for multiple recipients):
#
#    creation_rules:
#      - path_regex: inventory/group_vars/all/secrets.sops.yml$
#        age: "age1existing...,age1abc...xyz"

# 3. Re-encrypt the existing file with the updated recipient list:
sops updatekeys inventory/group_vars/all/secrets.sops.yml

# 4. Commit both .sops.yaml and the updated secrets file together.
git add .sops.yaml inventory/group_vars/all/secrets.sops.yml
git commit -m "secrets: add <name> as recipient"
```

After they pull, the new operator can `make edit-secrets` to confirm
their key works.

## Rotating / removing a recipient

Same flow as adding, in reverse:

1. Remove the public key from `.sops.yaml`'s recipient list.
2. `sops updatekeys inventory/group_vars/all/secrets.sops.yml` — this
   re-encrypts so the removed key can no longer decrypt **future**
   versions.
3. **Rotate the secret values themselves** (Mullvad key, *arr API keys,
   admin password, Plex token, etc.). The removed operator still has the
   old encrypted blob in their git clone and can decrypt it — anything
   they ever could read is now public to them. Treat removal as a leak.
4. Commit `.sops.yaml`, the updated `secrets.sops.yml`, and any
   downstream config changes for the rotated secrets.

## Recovery: what to do if you lose the age private key

If the only copy of `~/.config/sops/age/keys.txt` is gone:

- The file at `inventory/group_vars/all/secrets.sops.yml` is **lost**.
  No git history operation, no .sops.yaml edit, no anything will recover
  it. SOPS is symmetric encryption keyed off the age recipients.
- Recovery means re-creating every secret from its source of truth:
  generate a new Mullvad key in their dashboard, regenerate every *arr
  API key (they're settable, not derived), reset the admin password,
  pull a fresh Plex token, etc.
- Then run `make _init` to bootstrap a fresh encrypted secrets file with
  your new age key.

This is why **the age key should be backed up** — to a password manager,
to a hardware-encrypted USB stick, somewhere out-of-band. Backing up the
git repo doesn't back up secrets you can read; only a copy of the age
private key does.

## What goes in secrets.sops.yml vs. inventory main.yml

| In `secrets.sops.yml` | In `inventory/group_vars/all/main.yml` |
| --- | --- |
| API keys (Sonarr, Radarr, Prowlarr, Overseerr) | Service names, ports, image digests |
| Admin password | Storage paths, mergerfs disk UUIDs |
| Mullvad WireGuard private key | VPN provider name, server city |
| Plex auth tokens, machine ID, user IDs | Plex library names and paths |
| Cloudflare tunnel credentials | Tunnel name, public domain |
| Per-instance UUIDs (overseerr clientId, cleanuparr identifiers) | Tracker URLs, indexer names |

If you're unsure: secrets are anything that, if leaked, would let
someone *act* (impersonate, bill, decrypt). Public-but-stable identity
information (server names, public domains, library labels) goes in
plaintext.
