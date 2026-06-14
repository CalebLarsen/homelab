# State Ownership Matrix

This document maps system state (databases, config files, API settings) to the Ansible tasks/roles that manage them. Use this to identify the "Source of Truth" and avoid conflicting manual changes.

| Service | State Type | Path / Resource | Managing Task / Role | Ownership Mode |
| --- | --- | --- | --- | --- |
| **Common** | Directory | `{{ config_root }}/<name>` | `service_manager/tasks/main.yml` | Full (Recursive) |
| **Servarrs** | Database | `sonarr.db`, `radarr.db`, `prowlarr.db` | `service_manager/tasks/main.yml` (Admin Seed) | Bootstrap Only |
| **Servarrs** | API Settings | `/config/mediamanagement` | `service_manager/tasks/api_wiring.yml` | Partial (Hardlinks) |
| **Servarrs** | API Settings | `/rootfolder` | `service_manager/tasks/api_wiring.yml` | Enforced |
| **Servarrs** | API Settings | `/downloadclient` | `service_manager/tasks/api_wiring.yml` | Enforced (qBittorrent) |
| **Prowlarr** | Indexers | `/api/v1/indexer` | `service_manager/tasks/prowlarr_indexers.yml` | Enforced (Sync) |
| **qBittorrent** | Config | `qBittorrent.conf` | `service_manager/tasks/per_service/qbittorrent.yml` | Full (Templated) |
| **Cleanuparr** | Database | `cleanuparr.db`, `users.db` | `service_manager/tasks/api_wiring.yml` | Full (SQL Injection) |
| **Overseerr** | API Settings | `/api/v1/settings/*` | `service_manager/tasks/api_wiring.yml` | Partial (Bootstrapping) |
| **Plex** | Config | `Preferences.xml` | `service_manager/tasks/api_wiring.yml` (via API) | API-Authoritative |
| **Cross-seed** | Config | `config.js` | `service_manager/tasks/api_wiring.yml` | Full (Templated) |
| **Kometa** | Config | `config.yml` | `service_manager/tasks/api_wiring.yml` | Full (Templated) |
| **Caddy** | Config | `Caddyfile` | `service_manager/tasks/per_service/caddy.yml` | Full (Templated) |
| **MergerFS** | Host Mount | `/etc/fstab` (effectively) | `mergerfs/tasks/main.yml` | Full (Ansible Mount) |

## Ownership Modes Definitions

- **Full**: Ansible owns the file entirely. Any manual changes will be clobbered on the next deploy.
- **Enforced**: Ansible ensures a specific configuration exists via API. Manual changes to *other* settings are preserved.
- **Partial**: Ansible manages specific keys or entries but leaves the rest to the application/user.
- **Bootstrap Only**: Ansible only ensures the state exists for the initial boot (e.g., admin user).
- **API-Authoritative**: Ansible uses the application's API to set state, ensuring the application is aware of the change and can persist it correctly.
