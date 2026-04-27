# Architecture decisions

Short records of non-obvious choices that are load-bearing in this repo.
Each one explains the context, the decision, and **what breaks if you
undo it** — that last line is the most important part. If a future change
is going to remove or contradict one of these, it should update or
supersede the ADR in the same PR.

| # | Title |
| --- | --- |
| [0001](0001-mergerfs-cache-files.md) | mergerfs needs `cache.files=partial` for mmap users |
| [0002](0002-shared-parent-bind-mount.md) | Single shared parent bind mount for hardlinking services |
| [0003](0003-name-reclaim-step.md) | Reclaim container names from unmanaged containers before deploy |
| [0004](0004-cloudflared-per-hostname-dns.md) | New public hostnames need an explicit `cloudflared tunnel route dns` |
| [0005](0005-cleanuparr-pinned-tag.md) | Pin cleanuparr's image tag because the DB schema is undocumented |
