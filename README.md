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
- Optional AI coding agents for `run-prompt-pack.sh`: `codex`, `opencode`, or `claude`

## Repository layout

- Root scripts: `brew_backup.sh`, `deploy.sh`, `init-commit-create-push-github.sh`, `join_videos.sh`, `run-prompt-pack.sh`, `run_script_on.sh`, `show_mailmate_config.sh`, `set_mailmate_config.sh`, `update_mailmate_keys.sh`, `sync_repo.sh`
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

- Run a numbered prompt pack through an AI coding agent:

```bash
./run-prompt-pack.sh
./run-prompt-pack.sh --repo /home/dev/my-repo --first 01 --last 03
./run-prompt-pack.sh --branch prompt-pack/my-run --agent codex --model gpt-5.4-mini
./run-prompt-pack.sh --rollback-on-error --rollback-yes --first 01 --last 02
```

`run-prompt-pack.sh` runs `NN-name.md` files from `ignore/prompts` one at a time,
skipping `00-*.md`. Run it from the repository root, or pass `--repo /path/to/repo`
when launching it from another directory. It defaults to `codex` with model
`gpt-5.4-mini`; `opencode` defaults to `openai/gpt-5.4-mini`, and `claude`
defaults to `sonnet`.

By default, `run-prompt-pack.sh` creates or switches to a `prompt-pack/YYYYMMDD-HHMMSS`
branch before running prompts. Pass `--branch NAME` to choose a branch, or
`--no-branch` to run on the current branch. If the script-created branch ends
with no commits, no remaining changes, and no new ignored files, the script
switches back and deletes that empty branch.

Tests are enabled by default. The script never falls back to global `pytest`;
it uses repo virtualenv Python when pytest is installed there, or `uv run` /
`poetry run` when `uv.lock` / `poetry.lock` is present. Set `TEST_CMD` to provide
an explicit shell command run from the repo root, or pass `--no-tests`.

### `bin/` and deployment

`bin/` is the on-machine deploy target. Use `deploy.sh` from the repository root to copy
scripts into `bin/` and make them executable. `bin/` is intentionally kept populated and
should not be deduplicated or removed by automated tidy tasks.

### Safety notes

- `deploy.sh` can overwrite or delete files in `./bin`; keep backups and inspect before running.
- `init-commit-create-push-github.sh` may reinitialize repositories and affect existing `.git` data.
- `run-prompt-pack.sh` is provided as-is and can break things, especially with `--automatic`, rollback, and `--rollback-clean-ignored`.
- `run-prompt-pack.sh --automatic` bypasses normal agent approval prompts where supported; review the selected prompts and repository first.
- `run-prompt-pack.sh --rollback-clean-ignored` removes all ignored untracked files during rollback, including ignored files that existed before the run.
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

## License

MIT License

Copyright (c) 2026 Tom

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
