#!/usr/bin/env bash
# Hardened Pre-commit guard: validates that files matching *.sops.yml are
# actually encrypted using the `sops filestatus` command.
#
# A *.sops.yml without a valid sops metadata block is plaintext masquerading
# as encrypted — refuse to commit.
set -euo pipefail

if ! command -v sops &> /dev/null; then
  echo "ERROR: 'sops' is not installed or not in PATH. Cannot verify encryption status." >&2
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "ERROR: 'jq' is not installed or not in PATH. Cannot verify encryption status." >&2
  exit 1
fi

fail=0
for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    continue
  fi

  # Defensive: the rules file `.sops.yaml` or `.sops.yml` should never be checked here.
  if [[ "$(basename "$f")" == ".sops.yaml" || "$(basename "$f")" == ".sops.yml" ]]; then
    continue
  fi

  # Use sops filestatus for definitive check.
  status=$(sops filestatus "$f")
  encrypted=$(echo "$status" | jq -r '.encrypted')

  if [[ "$encrypted" != "true" ]]; then
    echo "ERROR: $f is NOT encrypted according to SOPS." >&2
    echo "  If you intentionally want plaintext, rename the file to drop .sops." >&2
    echo "  To encrypt: sops -e -i $f" >&2
    fail=1
  fi
done
exit "$fail"
