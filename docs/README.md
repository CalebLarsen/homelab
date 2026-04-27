# Homelab docs

The wiki for this repo. Start here, then click through to the section that
matches what you're doing.

| If you want to… | Read |
| --- | --- |
| Understand how a deploy is structured (which roles run, in what order, where to make a change) | [architecture.md](architecture.md) |
| Find the canonical upstream docs for a service before suggesting any config | [sources.md](sources.md) |
| Understand a non-obvious decision baked into the repo (why something is the way it is) | [decisions/](decisions/) |
| Onboard a new Plex user | [PLEX_USER_ONBOARDING.md](PLEX_USER_ONBOARDING.md) |

## For agents (Claude / models)

The rules at [`../CLAUDE.md`](../CLAUDE.md) apply to every change in this
repo. The short version: cite a source for every config key, env var,
container path, API endpoint, or SQL identifier — either a URL from
[sources.md](sources.md), a path you read on the running system, or an
existing call site. Do not guess.
