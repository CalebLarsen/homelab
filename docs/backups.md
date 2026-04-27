# Backups

A nightly restic backup of `/home/caleb/config/` runs to
`/media/seagate/restic-backup/` (the 7.3TB external drive). This is the
only automated backup on the host — see "Limits and threats" below for
what it does and does not protect against.

## What's backed up

| Path | What's there | Why |
| --- | --- | --- |
| `/home/caleb/config/` | All Docker service appdata: *arr DBs, Plex DB, Overseerr settings, qBittorrent config, etc. | Expensive to lose; not reproducible from upstream sources |
| Generated SQLite snapshots in `/var/lib/homelab-backup/sqlite-staging/` | Online-consistent copies of the *arr and cleanuparr DBs taken via `sqlite3 .backup` before restic runs | Avoid torn snapshots of live SQLite |

**Excluded from the backup** (large, regenerable, or noisy):
- `**/Cache/**`, `**/cache/**`, `**/Logs/**` everywhere
- `**/MediaCover{,s}/**` (re-fetched from TMDb on demand)
- Plex's `Cache/`, `Logs/`, `Crash Reports/`, `Codecs/`
- SQLite `*.db-shm` and `*.db-wal` sidecars (the staged copies replace these)

## Schedule and retention

- Runs daily at **03:00 host time** via the cron entry installed by
  `roles/backup`.
- Retention: `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`.
- After each backup, restic does a `--read-data-subset=1%` integrity
  check as a cheap sanity test.
- Logs go to `/var/log/homelab-backup.log`.

## Setup (one-time)

1. Add a strong passphrase to the encrypted secrets file. The passphrase
   never changes after this — restic's repository encryption is keyed off
   it, and bumping it requires a `restic key passwd` operation against an
   already-open repo:
   ```sh
   make edit-secrets
   # Add a line:
   #   restic_password: "<output of `openssl rand -base64 32`>"
   ```
2. Deploy the backup role:
   ```sh
   ansible-playbook site.yml --tags backup
   ```
   First run installs `restic`, runs `restic init` against
   `/media/seagate/restic-backup`, and writes the cron entry.

## Restoring

### List available snapshots

```sh
sudo -E RESTIC_PASSWORD="$(sudo cat /usr/local/sbin/homelab-backup.sh | grep RESTIC_PASSWORD | head -1 | cut -d'"' -f2)" \
  restic -r /media/seagate/restic-backup snapshots
```

(The script bakes the password in at deploy time. Easier: run the
restore against a one-off shell that exports `RESTIC_PASSWORD` from your
`make edit-secrets` view.)

### Restore a single file

```sh
export RESTIC_REPOSITORY=/media/seagate/restic-backup
export RESTIC_PASSWORD="<the value from secrets.sops.yml>"
restic snapshots                          # find the snapshot ID you want
restic restore <snapshot-id> --target /tmp/restore --include /home/caleb/config/sonarr/sonarr.db
# Then move/copy the file back into place after stopping the service.
```

### Restore the whole config tree (full recovery)

```sh
# 1. Stop everything that writes to /home/caleb/config
sudo systemctl stop docker

# 2. Move the existing tree out of the way (don't delete yet — keep a fallback)
sudo mv /home/caleb/config /home/caleb/config.broken.$(date +%s)

# 3. Restore from the most recent snapshot
export RESTIC_REPOSITORY=/media/seagate/restic-backup
export RESTIC_PASSWORD="<the value from secrets.sops.yml>"
restic restore latest --target /

# 4. SQLite snapshots: the restored tree includes
#    /var/lib/homelab-backup/sqlite-staging/*.db (the consistent copies).
#    For each, copy it over the corresponding live DB:
sudo cp /var/lib/homelab-backup/sqlite-staging/sonarr.db /home/caleb/config/sonarr/sonarr.db
sudo cp /var/lib/homelab-backup/sqlite-staging/radarr.db /home/caleb/config/radarr/radarr.db
sudo cp /var/lib/homelab-backup/sqlite-staging/prowlarr.db /home/caleb/config/prowlarr/prowlarr.db
sudo cp /var/lib/homelab-backup/sqlite-staging/cleanuparr.db /home/caleb/config/cleanuparr/cleanuparr.db
sudo cp /var/lib/homelab-backup/sqlite-staging/users.db /home/caleb/config/cleanuparr/users.db

# 5. Fix ownership (restic restores with original UID/GID; usually fine)
sudo chown -R 1000:1000 /home/caleb/config

# 6. Start docker back up; let services boot.
sudo systemctl start docker
```

### Restoring without the secrets file

If you've lost both the live host **and** `secrets.sops.yml`, the restic
repository on the seagate disk is still encrypted with `restic_password`.
Without that passphrase, the backup is unreadable. **Back the passphrase
up out of band** — alongside (and separately from) the age key for SOPS,
in a password manager.

## Limits and threats

This backup protects against:

- Accidental deletion or corruption of files in `/home/caleb/config/`
- Bad config writes (Ansible bug, manual `rm -rf`, *arr DB corruption)
- Single-disk failure of the **nvme** (root) drive

It does **not** protect against:

- **Fire / theft / total loss of the host.** Every byte is on one
  machine. There is no off-site copy by design (no cloud, per the
  threat model).
- **Failure of the seagate drive itself.** Backups and live data live on
  separate drives, so a seagate failure leaves the live data intact —
  but you have no backup until it's replaced and the role re-runs.
- **Ransomware that has root.** restic's repo is on a mounted disk
  the cron job can write to. A compromise that gets root can read the
  passphrase out of `/usr/local/sbin/homelab-backup.sh` and corrupt the
  repo too.
- **Loss of `restic_password`.** The repo is encrypted; the passphrase
  is in SOPS. Loss of both = data loss.

If the threat model ever expands, the cheapest next step is an
append-only off-site copy (rclone to a free B2 tier, or a second
external drive rotated to a friend's house) — both compatible with the
no-cloud-cost rule if the free tier holds.
