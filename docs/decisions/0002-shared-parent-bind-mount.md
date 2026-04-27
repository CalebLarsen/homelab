# 0002 — Single shared parent bind mount for hardlinking services

## Context

The *arr stack and qBittorrent rely on **hardlinks** to move files from
`torrents/` into `media/<library>/` without copying. Inside a container,
two separate bind mounts of sibling host paths look like two different
filesystems to `link(2)` — the syscall returns `EXDEV` and the *arr falls
back to a (much slower) copy, or fails outright.

Concretely: mounting `/home/caleb/data/torrents` to `/torrents` and
`/home/caleb/data/media` to `/media` inside the same container is **not**
the same as mounting `/home/caleb/data` to `/data`, even though the two
paths share a parent on the host.

## Decision

Any service that reads from `torrents/` and writes hardlinks into
`media/` (sonarr, radarr, qbittorrent, cross-seed) bind-mounts the
**shared parent** `{{ data_root }}` (currently `/home/caleb/data`) into
the container at `/data`. Do not split it into per-subdirectory bind
mounts on these services.

The mergerfs role pre-creates `torrents/`, `media/movies/`, `media/tv/`,
`media/audiobooks/`, and `cross-seed-links/` on every underlying branch
(see `storage.pool_subdirs` in `inventory/group_vars/all/main.yml`) so
mergerfs's create policy does not split a new directory across disks
either, which would also produce `EXDEV`.

## Why

- `link(2)` requires source and destination to live on the same mount
  point, not just the same host filesystem.
- mergerfs is one filesystem; the host's underlying disks are separate
  filesystems. A directory created on disk A and a sibling on disk B
  look like the same mergerfs path to the container, but `link()` between
  them fails. Pre-creating the subdirs on every branch ensures both ends
  of any hardlink resolve to the same underlying disk.

## What breaks if you undo this

Hardlinking from `/torrents` to `/media` fails with `EXDEV`. Each of the
*arr stack will either error out or fall back to copying — doubling the
disk usage of every imported file and slowing imports significantly.
