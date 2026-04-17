#!/bin/bash
set -euo pipefail
# Default to non-destructive mode. Pass --apply or -a to perform changes.
APPLY=0
if [ "${1:-}" = "--apply" ] || [ "${1:-}" = "-a" ]; then
  APPLY=1
  shift
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<EOF
Usage: $0 [--apply] [source-file]

Copy keybinding file into MailMate KeyBindings (backs up original).
Default source-file: ./tom.plist

Default: dry-run. Pass --apply to actually copy files.
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

# Define source and destination paths
SOURCE_FILE="${1:-./tom.plist}"
DEST_DIR="$HOME/Library/Application Support/MailMate/Resources/KeyBindings"
BACKUP_DIR="$DEST_DIR/backups"
DEST_FILE="$DEST_DIR/tom.plist"

echo "Copying $SOURCE_FILE to $DEST_FILE"
echo

# Ensure source exists before proceeding
if [ ! -f "$SOURCE_FILE" ]; then
  echo "Error: source file '$SOURCE_FILE' not found." >&2
  exit 1
fi

# Create the destination and backup directories if they don't exist
run_cmd mkdir -p "$DEST_DIR"
run_cmd mkdir -p "$BACKUP_DIR"

# Check if the destination file already exists
if [ -f "$DEST_FILE" ]; then
  # Get the current date and time in the format yyyy-mm-dd-hh-mm
  TIMESTAMP=$(date +"%Y-%m-%d-%H-%M")
  
  # Define the backup file name with the timestamp
  BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}-tom.plist"

  echo "Backing up $DEST_FILE to $BACKUP_FILE"
  echo 
  # Rename the existing file to the backup folder
  run_cmd mv "$DEST_FILE" "$BACKUP_FILE"
fi

# Copy the source file to the destination
echo "Copying $SOURCE_FILE to $DEST_DIR"
run_cmd cp "$SOURCE_FILE" "$DEST_FILE"
echo 
run_cmd echo Done
