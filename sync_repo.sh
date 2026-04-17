#!/usr/bin/env zsh
# Sync the currently active branch of a local Git repo with its remote (origin).
# Usage: ./sync_repo.sh /path/to/repo

set -euo pipefail

if [[ "${1:-}" = "-h" || "${1:-}" = "--help" ]]; then
  echo "Usage: $0 /path/to/repo"
  exit 0
fi

usage() {
  echo "Usage: $0 /path/to/repo" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage

REPO_DIR="$1"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "✗ Not a directory: $REPO_DIR" >&2
  exit 2
fi
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "✗ Not a Git repository: $REPO_DIR" >&2
  exit 3
fi

pushd "$REPO_DIR" >/dev/null

# Determine current branch (handle detached HEAD)
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" == "HEAD" ]]; then
  echo "⚠ Detached HEAD detected. Cannot pull/push a branch. Aborting." >&2
  popd >/dev/null
  exit 4
fi

# Ensure origin exists
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "✗ No 'origin' remote configured." >&2
  popd >/dev/null
  exit 5
fi

echo "------------------------------------------------------------------------"
echo "Syncing"
echo "→ Repo: $REPO_DIR"
echo "→ Branch: $BRANCH"

echo "• Fetching origin…" 
git fetch --all --prune

# If working tree dirty, stash (incl. untracked) to avoid pull/rebase failures
stash_ref=""
if [[ -n "$(git status --porcelain)" ]]; then
  echo "• Stashing local changes…"
  git stash push -u -m "sync_repo.sh auto-stash $(date -Iseconds)"
  # Capture the top stash ref (e.g., stash@{0})
  stash_ref="$(git stash list | head -n1 | cut -d: -f1)"
fi

# Rebase onto remote to keep linear history
echo "• Rebase-pulling from origin/$BRANCH…"
git pull --rebase origin "$BRANCH"

# Re-apply stash if we created one
if [[ -n "$stash_ref" ]]; then
  echo "• Re-applying stashed changes…"
  # Use apply so the stash is kept if conflicts occur
  if git stash apply --index "$stash_ref"; then
    # If apply succeeded, drop the stash
    git stash drop "$stash_ref" >/dev/null || true
  else
    echo "✗ Conflicts while applying stash. Resolve conflicts, then commit/push manually." >&2
    popd >/dev/null
    exit 6
  fi
fi

# Commit only if there are staged/unstaged changes
if [[ -n "$(git status --porcelain)" ]]; then
  echo "• Committing local changes…"
  git add -A
  # Only commit if something actually staged
  if ! git diff --cached --quiet; then
    git commit -m "sync: $(date -Iseconds)"
  else
    echo "• Nothing staged; skipping commit."
  fi
else
  echo "• No local changes to commit."
fi

echo "• Pushing to origin/$BRANCH…"
git push origin "$BRANCH"

echo "✓ Sync complete."
popd >/dev/null