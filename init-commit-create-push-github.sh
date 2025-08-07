#!/bin/bash

# Check if a path was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <path-to-folder>"
  exit 1
fi

TARGET_DIR="$1"
REPO_NAME=$(basename "$(realpath "$TARGET_DIR")")

# Check if directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' does not exist."
  exit 1
fi

cd "$TARGET_DIR" || exit 1

# Check for existing .git folder
if [ -d ".git" ]; then
  read -rp ".git folder exists. Overwrite? [y/N]: " CONFIRM
  CONFIRM=${CONFIRM:-N}
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
  else
    rm -rf .git
  fi
fi

# Initialise Git and commit
git init
git add .
git commit -m "first commit"

# Create GitHub repo using `gh`
echo "Creating GitHub repo '$REPO_NAME'..."
gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
git push -u origin main


# Final git status
git status