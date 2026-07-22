#!/bin/bash
set -euo pipefail

# Default to non-destructive mode. Pass --apply or -a to perform changes.
APPLY=0
if [ "${1:-}" = "--apply" ] || [ "${1:-}" = "-a" ]; then
    APPLY=1
    shift
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<'EOF_HELP'
Usage: $0 [--apply]

Create a dated zip backup of ./bin, then copy all root *.sh utilities and
./ov into ./bin, setting the executable bit.

Run this from the repository root.
Default: dry-run (no destructive changes). To perform the actions, pass
`--apply` or `-a`. With --apply this overwrites files in ./bin.
EOF_HELP
    exit 0
fi

if [ "$#" -ne 0 ]; then
    echo "Usage: $0 [--apply]" >&2
    exit 2
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

[ -f ./ov ] || {
    echo "deploy.sh: required utility not found: ./ov" >&2
    exit 1
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

# Replace the deployed utility set.
run_cmd rm -f ./bin/*
run_cmd cp ./*.sh ./bin/
run_cmd cp ./ov ./bin/ov
run_cmd chmod +x ./bin/*
