#!/bin/bash
set -euo pipefail

# Default to non-destructive mode. Pass --apply or -a to perform changes.
APPLY=0
if [ "${1:-}" = "--apply" ] || [ "${1:-}" = "-a" ]; then
    APPLY=1
    shift
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'EOF'
Usage: $0 [--apply]

Create a dated zip backup of ./bin into ./backups and copy all *.sh
from the repo root into ./bin, setting the executable bit.

Run this from the repository root.
Default: dry-run (no destructive changes). To perform the actions, pass
`--apply` or `-a`. Note: with --apply this WILL overwrite files in ./bin.
EOF
    exit 0
fi

run_cmd() {
    if [ "$APPLY" -eq 1 ]; then
        "$@"
    else
        printf "[DRY-RUN]"
        for a in "$@"; do printf " %s" "$a"; done
        echo
    fi
}

run_cmd mkdir -p ./backups
run_cmd mkdir -p ./bin

backup_date=$(date +%Y-%m-%d)
backup_file="./backups/bin-backup-$backup_date.zip"
suffix=1

while [ -e "$backup_file" ]; do
    backup_file="./backups/bin-backup-$backup_date-$suffix.zip"
    ((suffix++))
done

if [ -d ./bin ]; then
    run_cmd zip -r "$backup_file" ./bin
fi

# Remove existing files in ./bin (ignore errors if none)
run_cmd rm -f ./bin/* || true

# Copy shell scripts into ./bin and make them executable
run_cmd cp ./*.sh ./bin
run_cmd chmod +x ./bin/*.sh
