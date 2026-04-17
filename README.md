# shell_scripts

Personal macOS shell utilities and helpers — a small collection of single-purpose scripts
used on my machines. Some scripts are read-only inspectors; others perform file operations
or interact with the network. Read the Safety notes before running anything.

## Quick start

1. Clone the repo and change into it:

```bash
git clone <your-repo-url>
cd shell_scripts
```

2. Install common prerequisites (Homebrew recommended):

```bash
brew install git gh ffmpeg python3 zip cliclick openconnect
```

3. Make scripts executable and deploy them to `bin/`:

```bash
chmod +x ./*.sh
./deploy.sh            # dry-run by default; pass --apply to perform changes
```

## Requirements

- macOS (tested on recent versions)
- Homebrew (recommended)
- Tools used by various scripts: `git`, `gh`, `ffmpeg`, `ffprobe`, `python3`, `zip`, `cliclick`, `openconnect`

## Repository layout

- Root scripts: `brew_backup.sh`, `deploy.sh`, `init-commit-create-push-github.sh`, `join_videos.sh`, `run_script_on.sh`, `show_mailmate_config.sh`, `set_mailmate_config.sh`, `update_mailmate_keys.sh`, `sync_repo.sh`
- `bin/`: deployed, executable copies intended to be on your PATH (populated by `deploy.sh`)
- `backups/`: archives and helper scripts (e.g. MailMate config backups)
- `decomissioned/`: retired or special-purpose utilities

## Common usage examples

- Generate a Brewfile of installed Homebrew packages:

```bash
./brew_backup.sh
```

- Deploy scripts to `bin/` and create a dated backup of the previous `bin/`:

```bash
./deploy.sh            # dry-run by default; pass --apply to actually copy files into ./bin
```

- Initialize a folder as a git repo and create/push a GitHub repo (requires `gh` auth):

```bash
./init-commit-create-push-github.sh /path/to/project
```

- Concatenate videos using `ffmpeg`:

```bash
./join_videos.sh -s 0.5 '*.mp4' output.mp4
# Note: this script refuses to overwrite an existing output by default. Pass
# `-f` or `--force` to overwrite an existing output file.
```

- MailMate helpers (inspect and modify defaults/keybindings):

```bash
./show_mailmate_config.sh
./set_mailmate_config.sh   # dry-run by default; pass --apply to write defaults
./update_mailmate_keys.sh  # dry-run by default; pass --apply to copy keybindings
```

- Sync a repo with remote `origin` (fetch, rebase, push):

```bash
./sync_repo.sh /path/to/repo   # dry-run by default; pass --apply to perform stash/pull/push
```

### `bin/` and deployment

`bin/` is the on-machine deploy target. Use `deploy.sh` from the repository root to copy
scripts into `bin/` and make them executable. `bin/` is intentionally kept populated and
should not be deduplicated or removed by automated tidy tasks.

### Safety notes

- `deploy.sh` can overwrite or delete files in `./bin`; keep backups and inspect before running.
- `init-commit-create-push-github.sh` may reinitialize repositories and affect existing `.git` data.
- `set_mailmate_config.sh` and `update_mailmate_keys.sh` change MailMate defaults/keybindings using `defaults`.
- Scripts in `decomissioned/` may reference external helpers or store sensitive data; review carefully.
Note: Many scripts now default to a non-destructive dry-run mode. To actually
apply changes use `--apply` or `-a` (where supported). Some scripts use
`-f`/`--force` for specific destructive actions (e.g. overwriting outputs).

## Notes & recent fixes

- Fixed `deploy.sh` shebang placement and added safer error handling (`set -euo pipefail`).
- Fixed quoting in `update_mailmate_keys.sh`.
- Added `--help` and a Homebrew check to `brew_backup.sh`.

## Contributing

- These are personal scripts, feel free to use them and to create PR with bugfixes and improvements.
