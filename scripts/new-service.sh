#!/usr/bin/env bash
# Scaffold a new homelab service.
#
# Generates:
#   - services/<name>/docker-compose.yml.j2  (uses shared network partials)
#   - roles/service-manager/tasks/per_service/<name>.yml  (empty stub)
#
# Then prints the inventory snippets to paste into
# inventory/group_vars/all/main.yml.
#
# Usage:
#   scripts/new-service.sh NAME=anki PORT=8765 [INTERNAL_PORT=80] [IMAGE=...] [USE_VPN=false]
#
# Defaults:
#   INTERNAL_PORT=PORT
#   IMAGE=lscr.io/linuxserver/<name>:latest
#   USE_VPN=false

set -euo pipefail

# Parse KEY=VALUE args
NAME=""
PORT=""
INTERNAL_PORT=""
IMAGE=""
USE_VPN="false"

for arg in "$@"; do
  case "$arg" in
    NAME=*) NAME="${arg#NAME=}" ;;
    PORT=*) PORT="${arg#PORT=}" ;;
    INTERNAL_PORT=*) INTERNAL_PORT="${arg#INTERNAL_PORT=}" ;;
    IMAGE=*) IMAGE="${arg#IMAGE=}" ;;
    USE_VPN=*) USE_VPN="${arg#USE_VPN=}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [[ -z "$NAME" || -z "$PORT" ]]; then
  cat >&2 <<USAGE
usage: scripts/new-service.sh NAME=foo PORT=1234 [INTERNAL_PORT=N] [IMAGE=...] [USE_VPN=true|false]

required:
  NAME           service name (lowercase, no spaces)
  PORT           host port to expose

optional:
  INTERNAL_PORT  container's internal port (default: same as PORT)
  IMAGE          container image (default: lscr.io/linuxserver/<name>:latest)
  USE_VPN        route through gluetun (default: false)
USAGE
  exit 2
fi

# Resolve repo root from this script's location
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Defaults
INTERNAL_PORT="${INTERNAL_PORT:-$PORT}"
IMAGE="${IMAGE:-lscr.io/linuxserver/$NAME:latest}"

COMPOSE_DIR="$REPO_ROOT/services/$NAME"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml.j2"
PER_SERVICE_FILE="$REPO_ROOT/roles/service-manager/tasks/per_service/$NAME.yml"

# Refuse to overwrite
if [[ -e "$COMPOSE_FILE" || -e "$PER_SERVICE_FILE" ]]; then
  echo "error: service '$NAME' already exists (compose template or per-service file present)" >&2
  exit 1
fi

mkdir -p "$COMPOSE_DIR"

cat > "$COMPOSE_FILE" <<EOF
name: $NAME

services:
  $NAME:
    image: "{{ item.image }}"
    container_name: $NAME
    environment:
      - PUID={{ puid }}
      - PGID={{ pgid }}
      - TZ="{{ timezone }}"
    volumes:
      - "{{ config_root }}/$NAME:/config"
{% set use_vpn = item.use_vpn | default(false) %}
{% set host_port = item.port %}
{% set internal_port = $INTERNAL_PORT %}
{% include "_service_network.yml.j2" %}
    restart: unless-stopped

{% include "_network_footer.yml.j2" %}
EOF

cat > "$PER_SERVICE_FILE" <<EOF
---
# Per-service pre-deploy configuration for $NAME.
# Add tasks here only if $NAME needs config templating, directory setup,
# or other steps beyond the standard compose deploy.
EOF

# Build the inventory snippet
USE_VPN_LINE=""
if [[ "$USE_VPN" == "true" ]]; then
  USE_VPN_LINE=$'\n    use_vpn: true'
fi

cat <<SUMMARY
✓ Created $COMPOSE_FILE
✓ Created $PER_SERVICE_FILE

Now add this snippet under  services:  in inventory/group_vars/all/main.yml:

  - name: $NAME
    port: $PORT$USE_VPN_LINE
    image: "$IMAGE"

Then run:  make deploy

If $NAME needs custom config templating (e.g. a generated config file), edit:
  $PER_SERVICE_FILE
SUMMARY
