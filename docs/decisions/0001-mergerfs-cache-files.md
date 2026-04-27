# 0001 — mergerfs needs `cache.files=partial` for mmap users

## Context

The pool at `{{ storage.pool_path }}` is mergerfs over the disks defined in
`inventory/group_vars/all/main.yml`. mergerfs's default `cache.files` mode
disables `mmap()` on files in the pool. qBittorrent (and any other torrent
client / database that mmaps its working files) returns `ENODEV` on any
file it tries to map, with no obvious error in the application logs.

## Decision

The `mergerfs` role mounts the pool with `cache.files=partial` (or stronger).
Do not drop this option from the mount line.

## Why

`cache.files=off` is the historical mergerfs default and is faster for
read-heavy media playback workloads, but it is incompatible with `mmap()`.
qBittorrent uses mmap for its piece store; without it the client cannot
write torrent data into the pool at all.

## What breaks if you undo this

qBittorrent (and likely Plex's database when stored on the pool, plus any
SQLite-backed app pointing at the pool) will start failing with `ENODEV`
on file operations. The failure mode is often silent in the UI — torrents
just stop progressing — so it is easy to misdiagnose.

## Verifying live state

`/proc/mounts` does **not** show mergerfs's runtime options. Inspect with:

```sh
xattr -l user.mergerfs.<option> {{ storage.pool_path }}
# e.g.
xattr -l user.mergerfs.cache.files /home/caleb/data
```

or read the runtime config via the `.mergerfs` control file inside the
mount.
