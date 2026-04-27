#!/bin/bash

set -e

# --- Configuration ---
# Tier 1: NVMe (Fastest / Source)
TIER1_DIR="/home/caleb/nvme"

# Tier 2: SSD (Fast / Middle)
TIER2_DIR="/media/shield"
DAYS_TO_TIER2=30  # Move files > 30 days old from NVMe to SSD

# Tier 3: HDD (Slow / Archive)
TIER3_DIR="/media/seagate"
DAYS_TO_TIER3=90  # Move files > 90 days old from SSD to HDD

# General Settings
EXCLUDES=(torrents incomplete)
LOG_FILE="/home/caleb/.movement_log"

# All output goes to both the log file and journald. `journalctl -t
# move_old_media` surfaces the drift preflight warnings where they'll
# actually get noticed.
exec > >(tee -a "$LOG_FILE" | logger -t move_old_media) 2>&1

# --- Safety Checks ---
# Ensure both destination drives are mounted before doing anything
if ! grep -qs "$TIER2_DIR" /proc/mounts; then
    echo "$(date): Tier 2 drive ($TIER2_DIR) not mounted. Aborting."
    exit 1
fi

if ! grep -qs "$TIER3_DIR" /proc/mounts; then
    echo "$(date): Tier 3 drive ($TIER3_DIR) not mounted. Aborting."
    exit 1
fi

echo "$(date): Starting tiered move..."

# --- Preflight: warn & skip top-level dirs not mirrored on the destination ---
# A missing counterpart means caleb can't create it under the destination
# mount root (root:root 0755 by default). Fix by adding the dir to
# storage.pool_subdirs in inventory and re-running the mergerfs role.
drifted_excludes() {
    local src="$1"
    local dest="$2"
    local name
    while IFS= read -r -d '' dir; do
        name=$(basename "$dir")
        if [ ! -d "$dest/$name" ]; then
            echo "$(date): WARN: '$src/$name' has no counterpart on '$dest'; skipping. Add '$name' to storage.pool_subdirs and redeploy." >&2
            printf -- '--exclude=/%s\n' "$name"
        fi
    done < <(find "$src" -mindepth 1 -maxdepth 1 -type d -print0)
}

# --- Function: Move Files ---
# Usage: move_files "SOURCE" "DEST" "DAYS"
move_files() {
    local src="$1"
    local dest="$2"
    local days="$3"

    echo "Processing: $src -> $dest (> $days days)"

    local -a drifted
    mapfile -t drifted < <(drifted_excludes "$src" "$dest")

    local -a excludes=()
    for e in "${EXCLUDES[@]}"; do excludes+=( --exclude="/$e" ); done

    # -a: archive (timestamps matter for the next tier's age threshold)
    # -H: preserve hardlinks within the transfer set (won't rescue
    #     torrent↔media links since torrents/ is excluded, but does keep
    #     intra-media links intact)
    find "$src" -type f -mtime +$days -printf "%P\0" | \
    rsync -avH --remove-source-files --files-from=- --from0 \
          "${excludes[@]}" "${drifted[@]}" "$src/" "$dest/"

    # Cleanup empty directories.
    # We ignore the specific exclude folders so we don't accidentally delete their structure if empty
    find "$src" -type d -empty -not -path "$src/incomplete*" -delete
}

# --- Execution ---

# Step 1: Clear space on the Middle Tier (SSD -> HDD)
# We do this first so the SSD has room to receive data from the NVMe
move_files "$TIER2_DIR" "$TIER3_DIR" "$DAYS_TO_TIER3"

# Step 2: Clear space on the Top Tier (NVMe -> SSD)
move_files "$TIER1_DIR" "$TIER2_DIR" "$DAYS_TO_TIER2"

echo "$(date): Tiered move complete."
