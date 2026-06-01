# Design Spec: Plex Guest Isolation via Label System

## Overview
This design implements a multi-tenant isolation system for Plex users, allowing guests to have a "private" library experience where they only see content they have requested via Seerr. It leverages Radarr/Sonarr tags as the source of truth, Kometa as the bridge, and Plex Labels as the enforcement mechanism.

## Goals
- Provide a "Netflix-like" experience for guests (only see their requests).
- Minimize disk space usage (share files between users).
- Automate the process from request to library visibility.
- Support multiple guest users with independent permissions.

## Architecture

### 1. Seerr (Request Portal)
- **Configuration**: Enable `tagRequests` in Radarr and Sonarr settings.
- **User Management**: Update `overseerr_secret.users` in `secrets.sops.yml` to include a `label` field for each guest.
- **Automation**: When a user makes a request, Seerr will apply their `label` as a tag in Radarr/Sonarr.

### 2. Radarr / Sonarr (Media Management)
- **Role**: Act as the metadata store for request "ownership" via tags.
- **Behavior**: Multiple users requesting the same item will result in multiple tags on that item.

### 3. Kometa (Metadata Sync)
- **Configuration**: Update `kometa_config.yml.j2` to iterate over all users in `overseerr_secret.users`.
- **Logic**: For each user with a `label`, Kometa will:
    - Read items from Radarr/Sonarr that have that tag.
    - Apply the corresponding "Label" to those items in Plex.
- **Append Mode**: Kometa will be configured to append labels, ensuring multi-user "ownership" is preserved.

### 4. Plex (Streaming)
- **Manual Setup**: For each guest user, the admin must:
    - Go to **Settings -> Manage Library Access**.
    - Select the Guest user.
    - Under **Restrictions**, add the specific Label (e.g., `guest-name`) to the shared libraries.
- **Experience**: The guest will only see items that have their specific label applied.

## Component Changes

### Ansible / Infrastructure
- **`inventory/group_vars/all/main.yml`**: Ensure Kometa is configured to run regularly.
- **`roles/service_manager/templates/kometa_config.yml.j2`**: Add dynamic label operations.
- **`roles/service_manager/tasks/api_wiring.yml`**: Ensure Seerr's `tagRequests` setting is provisioned.

### Secrets
- **`inventory/group_vars/all/secrets.sops.yml`**: Update `overseerr_secret.users` schema.

## Data Flow
1. **Request**: Guest logs into Seerr and requests a movie.
2. **Tagging**: Seerr approves the request and sends it to Radarr with tag `guest-label`.
3. **Sync**: Kometa's next run detects the tag in Radarr and applies label `guest-label` in Plex.
4. **Visibility**: Plex immediately makes the item visible to the Guest user based on their label restriction.

## Alternatives Considered
- **Separate Libraries**: Rejected because it requires users to switch sidebars and is harder to manage at scale.
- **Service Isolation**: Rejected due to excessive resource usage.

## Success Criteria
- A guest user requests a movie and it appears in their Plex library without manual admin intervention (post-initial setup).
- Content not requested by the guest remains hidden from them.
- Shared requests correctly show up for all requesting parties.
