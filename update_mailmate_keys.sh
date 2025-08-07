#!/bin/bash
# Updates the keybindings

# Define source and destination paths
SOURCE_FILE="./tom.plist"
DEST_DIR="$HOME/Library/Application\ Support/MailMate/Resources/KeyBindings"
BACKUP_DIR="$DEST_DIR/backups"
DEST_FILE="$DEST_DIR/tom.plist"

echo "Copying $SOURCE_FILE to $DEST_FILE"
echo 

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
