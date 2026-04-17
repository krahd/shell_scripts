#!/bin/bash
set -euo pipefail

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
