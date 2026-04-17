Overview
--------
Small, personal shell utilities and helpers for macOS. Some scripts are read-only inspectors; others perform file changes or network actions — read the safety notes before running anything.

Prerequisites
-------------
- macOS (tested on recent versions)
- Homebrew (recommended) and these tools for some scripts:
	- `git`, `gh` (GitHub CLI), `ffmpeg`, `ffprobe`, `python3`, `zip`, `cliclick`, `openconnect`

Install common tools via Homebrew:

```bash
brew install git gh ffmpeg python3 zip cliclick openconnect
```

Repository layout
-----------------
- Root scripts (examples): `brew_backup.sh`, `deploy.sh`, `init-commit-create-push-github.sh`, `join_videos.sh`, `run_script_on.sh`, `show_mailmate_config.sh`, `set_mailmate_config.sh`, `update_mailmate_keys.sh`, `sync_repo.sh`
- `bin/`: executable copies of many scripts (duplicates)
- `backups/`: helper scripts and historical backups (e.g., `backups/mailmate-config-backup.sh`)
- `decomissioned/`: retired or special-purpose utilities

How to enable scripts
---------------------
Make scripts executable before running:

```bash
chmod +x ./brew_backup.sh ./deploy.sh ./init-commit-create-push-github.sh ./join_videos.sh \
	./run_script_on.sh ./show_mailmate_config.sh ./set_mailmate_config.sh ./update_mailmate_keys.sh ./sync_repo.sh
```

Per-script summary (examples)
-----------------------------
- `brew_backup.sh` — generates a `Brewfile` for your installed Homebrew packages:

```bash
./brew_backup.sh
```

- `deploy.sh` — creates a dated zip backup of `./bin` to `./backups` and copies `*.sh` into `./bin` (makes them executable). Run from repo root.

```bash
./deploy.sh
```

- `init-commit-create-push-github.sh` — initialize a local folder as a git repo and create/push to a new GitHub repo (requires `gh` authentication):

```bash
./init-commit-create-push-github.sh /path/to/project
```

- `join_videos.sh` — zsh script that concatenates multiple videos using `ffmpeg` (requires `ffmpeg`/`ffprobe`):

```bash
./join_videos.sh -s 0.5 '*.mp4' output.mp4
```

- MailMate helpers: `show_mailmate_config.sh`, `set_mailmate_config.sh`, `update_mailmate_keys.sh`, `backups/mailmate-config-backup.sh` — inspect/modify MailMate defaults and keybindings (macOS `defaults` used).

- `sync_repo.sh` — fetch, rebase-pull, stash/reapply, and push; useful for syncing a local repo with `origin`.

Safety notes
------------
- `deploy.sh` performs destructive operations on `./bin` (deletes/replaces files). Keep backups and review before running.
- `init-commit-create-push-github.sh` may remove an existing `.git` directory when re-initializing — use with caution.
- `set_mailmate_config.sh` and `update_mailmate_keys.sh` modify MailMate defaults and keybindings; run only if you understand the changes.
- `decomissioned/openconnect.sh` references external helpers and stores passwords; review securely before use.

Recommended fixes applied
------------------------
- Fixed `deploy.sh` shebang placement and added error-handling (`set -euo pipefail`).
- Fixed `update_mailmate_keys.sh` destination path quoting.
- Added help and a basic Homebrew check to `brew_backup.sh`.

Contributing
------------
If you'd like to tidy the repo further, consider keeping a single canonical copy of each script (remove duplicates from `bin/`), add `--help` to other scripts, and add tests for destructive operations.

---

If you want me to push these changes to a branch and open a PR, tell me and I'll proceed.

