#!/usr/bin/env bash
# Pre-commit guard: a file named *.sops.yml must contain a `sops:` metadata
# block, which SOPS appends at the bottom of every encrypted file. A *.sops.yml
# without that block is plaintext masquerading as encrypted — refuse to commit.
#
# Note: the SOPS *rules* file `.sops.yaml` at the repo root is plaintext on
# purpose — it only holds age public keys. The matching regex in
# .pre-commit-config.yaml excludes it via a `[^/]` prefix that requires at
# least one non-slash char before `.sops`, so `.sops.yaml` doesn't match
# but `secrets.sops.yml` does. If somehow this script is invoked on the rules
# file, refuse to act (defensive double-check).
set -euo pipefail

fail=0
for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    continue
  fi
  # Defensive: the rules file `.sops.yaml` should never be checked here.
  if [[ "$(basename "$f")" == ".sops.yaml" || "$(basename "$f")" == ".sops.yml" ]]; then
    continue
  fi
  if ! grep -q '^sops:' "$f"; then
    echo "ERROR: $f looks unencrypted — no 'sops:' metadata block found." >&2
    echo "  If you intentionally want plaintext, rename the file to drop .sops." >&2
    echo "  To re-encrypt: sops -e -i $f" >&2
    fail=1
  fi
done
exit "$fail"
