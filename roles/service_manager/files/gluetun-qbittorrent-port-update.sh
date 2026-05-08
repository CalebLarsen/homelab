#!/bin/sh
# Push the VPN-forwarded port into qBittorrent's listening port.
#
# Run from inside the gluetun container by VPN_PORT_FORWARDING_UP_COMMAND
# whenever the upstream VPN provider assigns a new forwarded port. Argument:
#   $1 — the forwarded port (gluetun substitutes {{PORT}} into the command).
#
# qBittorrent shares gluetun's network namespace (network_mode:
# container:gluetun in services/qbittorrent/docker-compose.yml.j2), so its
# WebUI is reachable at localhost:6969 from inside this container.
#
# Auth note: qBittorrent 5.x's CSRF protection 403's POSTs without a valid
# session cookie even when WebUI\LocalHostAuthentication=false (that
# setting bypasses the password prompt for GETs but not the CSRF check on
# POSTs). So we POST /api/v2/auth/login first, save the SID cookie, then
# POST setPreferences with the cookie. Credentials come from env vars set
# in the gluetun compose template, sourced from secrets.sops.yml.
set -eu

PORT="${1:-}"
if [ -z "$PORT" ]; then
  echo "$0: missing port argument" >&2
  exit 2
fi

USER="${QBITTORRENT_USER:-admin}"
if [ -z "${QBITTORRENT_PASSWORD:-}" ]; then
  echo "$0: QBITTORRENT_PASSWORD env var not set" >&2
  exit 2
fi

COOKIES=/tmp/qbittorrent-cookies
URL_LOGIN="http://localhost:6969/api/v2/auth/login"
URL_PREFS="http://localhost:6969/api/v2/app/setPreferences"

# random_port:false is required — when UseRandomPort is true, qBittorrent
# silently ignores listen_port updates from this API. Always send both.
BODY="json={\"listen_port\":${PORT},\"random_port\":false}"

# qBittorrent may not be ready when gluetun first comes up — retry briefly.
i=0
while [ "$i" -lt 30 ]; do
  rm -f "$COOKIES"

  # Login response body is "Ok." on success, "Fails." on bad creds.
  login_response="$(wget -qO- \
      --save-cookies="$COOKIES" \
      --keep-session-cookies \
      --post-data="username=${USER}&password=${QBITTORRENT_PASSWORD}" \
      --header="Referer: http://localhost:6969" \
      "$URL_LOGIN" 2>/dev/null || true)"

  if [ "$login_response" = "Ok." ] && [ -s "$COOKIES" ]; then
    if wget -qO- \
         --load-cookies="$COOKIES" \
         --post-data="$BODY" \
         --header="Referer: http://localhost:6969" \
         "$URL_PREFS" >/dev/null 2>&1; then
      echo "qbittorrent listen_port set to $PORT"
      rm -f "$COOKIES"
      exit 0
    fi
  fi

  i=$((i + 1))
  sleep 2
done

echo "$0: failed to set qbittorrent listen_port to $PORT after retries" >&2
rm -f "$COOKIES"
exit 1
