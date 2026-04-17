#!/bin/bash
# update_mailmate_keys.sh — copy MailMate keybindings into user Library
# Usage: update_mailmate_keys.sh [source-file]
# Default: ./tom.plist
# Notes: Backs up existing tom.plist into KeyBindings/backups with a timestamp.

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<EOF
Usage: $0 [source-file]

Copy keybinding file into MailMate KeyBindings (backups original).
Default source-file: ./tom.plist
EOF
  exit 0
fi

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
mkdir -p "$DEST_DIR"
mkdir -p "$BACKUP_DIR"

# Check if the destination file already exists
if [ -f "$DEST_FILE" ]; then
  # Get the current date and time in the format yyyy-mm-dd-hh-mm
  TIMESTAMP=$(date +"%Y-%m-%d-%H-%M")
  
  # Define the backup file name with the timestamp
  BACKUP_FILE="$BACKUP_DIR/${TIMESTAMP}-tom.plist"

  echo "Backing up $DEST_FILE to $BACKUP_FILE"
  echo 
  # Rename the existing file to the backup folder
  mv "$DEST_FILE" "$BACKUP_FILE"
fi

# Copy the source file to the destination
echo "Copying $SOURCE_FILE to $DEST_DIR"
cp "$SOURCE_FILE" "$DEST_FILE"
echo 
echo "Done"
