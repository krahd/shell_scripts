#!/bin/bash
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat <<EOF
Usage: $0

Create a dated zip backup of ./bin into ./backups and copy all *.sh
from the repo root into ./bin, setting the executable bit.

Run this from the repository root. This will overwrite files in ./bin.
EOF
    exit 0
fi

mkdir -p ./backups
mkdir -p ./bin

backup_date=$(date +%Y-%m-%d)
backup_file="./backups/bin-backup-$backup_date.zip"
suffix=1

while [ -e "$backup_file" ]; do
    backup_file="./backups/bin-backup-$backup_date-$suffix.zip"
    ((suffix++))
done

if [ -d ./bin ]; then
    zip -r "$backup_file" ./bin > /dev/null
fi

# Remove existing files in ./bin (ignore errors if none)
rm -f ./bin/* || true

# Copy shell scripts into ./bin and make them executable
cp ./*.sh ./bin
chmod +x ./bin/*.sh
