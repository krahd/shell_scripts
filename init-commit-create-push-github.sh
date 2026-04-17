#!/bin/bash

# init-commit-create-push-github.sh — initialise a folder as a git repo and push to GitHub
# Usage: init-commit-create-push-github.sh <path-to-folder>
# Requires: `gh` (GitHub CLI) authenticated. May remove an existing .git if you confirm.

usage() {
  echo "Usage: $0 <path-to-folder>"
  echo
  echo "Initialise the folder at <path-to-folder> as a git repo, create a GitHub"
  echo "repository via 'gh', and push the initial commit. Requires 'gh' to be"
  echo "authenticated."
  exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
fi

if [ -z "${1:-}" ]; then
  usage
fi

TARGET_DIR="$1"

# Determine repository name; prefer realpath if available
if command -v realpath >/dev/null 2>&1; then
  REPO_NAME=$(basename "$(realpath "$TARGET_DIR")")
else
  REPO_NAME=$(basename "$TARGET_DIR")
fi

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