# 0009 — Local-only restic backup to the seagate external drive

## Context

Until 2026-04-26 the homelab had no automated backup. Manual snapshots
existed (occasional `tar` of `/home/caleb/config`) but nothing
recurring. Loss of the nvme system drive would mean rebuilding every
service's state from scratch — request history, indexer config, watch
progress, etc.

The user has explicit constraints:

- No paid cloud storage.
- No additional hardware purchases.
- No reliance on third-party CI / scheduled actions.

The hardware available is the existing 3-drive layout: `nvme` (root,
915G), `shield` (916G internal HDD), `seagate` (7.3T external HDD).
`seagate` has the most free space and is on a separate physical disk
from `nvme` and `shield`.

## Decision

A nightly `restic` backup of `/home/caleb/config/` to
`/media/seagate/restic-backup/`, scheduled via the host crontab from
`roles/backup`.

- **Tool:** `restic` (deduplicating, encrypted, integrity-checking).
- **Source:** `/home/caleb/config/` plus an online-consistent SQLite
  staging copy of the *arr / cleanuparr DBs taken with `sqlite3 .backup`
  immediately before the run.
- **Target:** `/media/seagate/restic-backup/`.
- **Schedule:** 03:00 daily.
- **Retention:** `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`.
- **Encryption passphrase:** `restic_password` in
  `inventory/group_vars/all/secrets.sops.yml`. Long-lived; loss = data
  loss.
- **Logs:** `/var/log/homelab-backup.log`.

The SQLite staging step matters: the *arr DBs use WAL mode and a naive
file copy of a live `.db` produces a torn snapshot that fails to open.
`sqlite3 source.db ".backup '$STAGING/source.db'"` is an online
consistent copy that does not block the running service. Plex's DB is
deliberately *not* staged — Plex tolerates a torn-copy restore by
rebuilding its caches, and the DB is large enough that a per-night
staged copy would balloon backup size and time.

## Why

- **Local satisfies the threat model.** The most likely failure modes
  (bad config write, accidental delete, *arr DB corruption, single-disk
  hardware failure on `nvme`) are all addressed by a separate-physical-
  disk copy.
- **restic gives encryption + dedup + integrity for free.** The
  encrypted repo on `seagate` is fine even if the disk leaves the
  premises (e.g. RMA), because the passphrase is needed to read it.
- **Daily + monthly retention** is enough granularity for a homelab.
  The seagate's free space (5.8T) makes 6 months of monthlies trivial.
- **No new role conventions.** The backup role wires cleanly into the
  existing playbook; cron-based scheduling matches the
  `host_cron_jobs:` pattern already used in inventory.

## Why NOT some alternatives

- **rsync / borg:** rsync has no integrity verification, no dedup, no
  retention model. borg is technically equivalent to restic but the
  ecosystem (especially around restoring to a different machine) is
  weaker; restic's docs are better.
- **ZFS / btrfs snapshots:** would require reformatting the disks. Too
  invasive for the value.
- **Cloud (B2, Backblaze, S3):** explicitly out of scope per user
  constraints.

## What breaks if you undo this

- A bad config write or *arr DB corruption requires manual recovery
  from upstream sources (re-add libraries, re-import, lose request
  history). Hours-to-days of operator time.
- A nvme failure requires rebuilding every service's state from scratch.

## Bumping retention or adding paths

Retention is hard-coded in `roles/backup/templates/run-backup.sh.j2`.
Add new source paths or relax the exclude rules in the same template
and re-deploy with the `backup` tag:

```sh
ansible-playbook site.yml --tags backup
```

The on-disk `restic` repo is forward-compatible — adding paths or
changing retention does not invalidate existing snapshots.

## Open questions / future moves

- **Off-site copy.** A weekly `restic copy` to a free-tier cloud bucket
  would cover fire/theft. Free tiers exist (B2 has 10GB free, others
  similar) but storage is the limiting factor — the encrypted repo size
  needs to fit. Defer until the threat model warrants it.
- **Restore drills.** Backups that have never been tested are not
  backups. A quarterly "restore one file from a random snapshot" sanity
  check should be added — manually for now, automated later.
