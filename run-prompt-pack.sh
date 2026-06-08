#!/usr/bin/env bash
# Run numbered Markdown prompt files through Codex, OpenCode, or Claude Code.
# Compatible with macOS Bash 3.2 and zsh callers. Execute this file directly;
# the shebang selects Bash even if your interactive shell is zsh.
set -euo pipefail

PROMPT_DIR="ignore/prompts"
REPO_DIR=""
AGENT="codex"
FIRST=""
LAST=""
NOTIFY=1
RUN_TESTS=1
COMMIT_CHANGES=1
AUTOMATIC=0
AUTO_YES=0
ROLLBACK_ON_ERROR=0
ROLLBACK_YES=0
ROLLBACK_CLEAN_IGNORED=0
RUN_STARTED=0
BRANCH_NAME=""
NO_BRANCH=0
BRANCH_CREATED=0
ORIGINAL_BRANCH=""
ORIGINAL_HEAD=""
ORIGINAL_STATUS_WITH_IGNORED=""
ACTIVE_BRANCH=""

MODEL=""
VARIANT="xhigh"
VERSION="0.5.0"
DEFAULT_MODEL_CODEX="gpt-5.4-mini"
DEFAULT_MODEL_OPENCODE="openai/gpt-5.4-mini"
DEFAULT_MODEL_CLAUDE="sonnet"
REPO_ENV_BIN=""

usage() {
  cat <<USAGE

Usage:
  run-prompt-pack.sh [OPTIONS]

Version: $VERSION
Default codex model: $DEFAULT_MODEL_CODEX
Default opencode model: $DEFAULT_MODEL_OPENCODE
Default claude model: $DEFAULT_MODEL_CLAUDE
USAGE

  cat <<'USAGE'

Runs numbered Markdown prompt files one at a time. Each selected prompt must be
named NN-something.md, for example 01-fix-ci.md. Files named 00-*.md are skipped.

Options:
  -r, --repo DIR           Repository root to operate on. Required when running
                           from outside the repo root.
  -d, --prompt-dir DIR     Directory containing prompt files. Default:
                           ignore/prompts (relative to the repo root)
  -b, --branch NAME        Create or switch to this branch before running prompts.
                           By default, a prompt-pack/YYYYMMDD-HHMMSS branch is
                           created.
      --no-branch          Run on the current branch instead of creating or
                           switching branches.
  -a, --agent AGENT        Agent to use: codex, opencode, claude. Default: codex
  -f, --first NUM          First prompt number to run, e.g. 01. Optional.
      --start NUM          Alias for --first
  -l, --last NUM           Last prompt number to run, e.g. 04. Optional.
      --finish NUM         Alias for --last
  -m, --model MODEL        Override model name. Default depends on --agent; see
                           the default model lines near the top of this help.
      --variant VALUE      Reasoning/variant/effort value. Default: xhigh
      --automatic          Fully unattended mode where supported. Prints a loud
                           warning and asks for confirmation unless --yes is
                           passed.
      --AUTOMATIC          Alias for --automatic
  -Y, --yes                Skip the automatic-mode confirmation prompt.
      --yes                Alias for -Y
  -n, --no-notify          Suppress the macOS notification when finished or
                           failed. Notifications are enabled by default.
      --no-tests           Do not run tests after each prompt
      --no-commit          Do not commit after each prompt
      --rollback-on-error  Offer to reset and clean changes made by the failed
                           prompt.
      --rollback-yes       Auto-confirm rollback without prompting. Requires
                           --rollback-on-error. Also required when combining
                           --automatic with --rollback-on-error.
      --rollback-clean-ignored
                           Also remove all ignored untracked files during
                           rollback, including files that existed before this
                           run. Requires --rollback-on-error.
  -h, --help               Show this help

Default behaviour:
  The script creates or switches to a prompt branch before running prompts. Pass
  --no-branch to run on the current branch. If a script-created branch ends with
  no commits, no remaining changes, and no new ignored files, the script switches
  back and deletes it.

  Without --automatic, the script does not bypass permissions. Codex and Claude
  use interactive modes so you can answer prompts or approve actions. OpenCode
  runs without --dangerously-skip-permissions.

Automatic behaviour:
  With --automatic, the script uses each harness's unattended mode:
  - codex:   codex exec --dangerously-bypass-approvals-and-sandbox
  - opencode: opencode run --dangerously-skip-permissions
  - claude:  claude -p --dangerously-skip-permissions

Examples:
  run-prompt-pack.sh
  run-prompt-pack.sh --repo /home/dev/my-repo --first 01 --last 02
  run-prompt-pack.sh --prompt-dir ./ignore/prompts
  run-prompt-pack.sh --first 01 --last 02
  run-prompt-pack.sh --start=02 --finish=04
  run-prompt-pack.sh --rollback-on-error --first 01 --last 03
  run-prompt-pack.sh --agent codex --model gpt-5.4-mini --automatic --yes
  run-prompt-pack.sh --agent opencode --model openai/gpt-5.4-mini --variant xhigh
  run-prompt-pack.sh --agent claude --model sonnet --variant xhigh

Environment:
  TEST_CMD                Shell command run from the repo root. Default: pytest
                          through a repo virtualenv, uv.lock, or poetry.lock.
                          Global pytest is never used as a fallback.

Repo usage:
  Run this script from the repo root. If you want to run it from elsewhere,
  pass --repo /path/to/repo, for example --repo /home/dev/my-repo.

Disclaimer:
  This script is provided as-is and can break things up, especially with
  --automatic, rollback, and --rollback-clean-ignored. Review the selected
  prompts and repository before continuing.

USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

shell_quote() {
  printf '%q' "$1"
}

rollback_failed_prompt() {
  local prompt_file="$1"
  local checkpoint_sha="$2"
  local clean_flags="-fd"

  echo
  echo "Rollback requested for failed prompt: $prompt_file"
  echo "This resets tracked changes and removes non-ignored untracked files."
  if [[ "$ROLLBACK_CLEAN_IGNORED" -eq 1 ]]; then
    clean_flags="-fdx"
    echo "WARNING: ignored untracked files will also be removed because --rollback-clean-ignored is set."
    echo "This includes ignored files that existed before this script run."
  fi
  echo "This will run:"
  echo "  git -C $(shell_quote "$REPO_DIR") reset --hard $checkpoint_sha"
  echo "  git -C $(shell_quote "$REPO_DIR") clean $clean_flags"
  echo

  git -C "$REPO_DIR" reset --hard "$checkpoint_sha"
  git -C "$REPO_DIR" clean "$clean_flags"
  echo
  echo "Git status after rollback:"
  git -C "$REPO_DIR" status --short
}

handle_prompt_failure() {
  local prompt_file="$1"
  local checkpoint_sha="$2"
  local exit_code="$3"
  local rollback_reply

  echo
  echo "Prompt failed: $prompt_file"
  echo "Exit code: $exit_code"
  echo
  echo "Current git status:"
  git -C "$REPO_DIR" status --short
  echo

  if [[ "$ROLLBACK_ON_ERROR" -ne 1 ]]; then
    echo "Rollback is disabled. Re-run with --rollback-on-error to offer cleanup on failures."
    return 0
  fi

  if [[ "$ROLLBACK_YES" -eq 1 ]]; then
    rollback_failed_prompt "$prompt_file" "$checkpoint_sha"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Rollback requires confirmation on an interactive terminal. Re-run with --rollback-on-error --rollback-yes to auto-confirm."
    return 0
  fi

  echo "Rollback will reset --hard to $checkpoint_sha and run git clean -fd."
  if [[ "$ROLLBACK_CLEAN_IGNORED" -eq 1 ]]; then
    echo "WARNING: --rollback-clean-ignored is set; git clean -fdx will also remove ignored files,"
    echo "including ignored files that existed before this run."
  fi

  read -r -p "Rollback changes from this failed prompt? [y/N] " rollback_reply
  case "$rollback_reply" in
    y|Y|yes|YES)
      rollback_failed_prompt "$prompt_file" "$checkpoint_sha"
      ;;
    *)
      echo "Rollback skipped."
      ;;
  esac

  return 0
}

warn_automatic_mode() {
  cat >&2 <<'EOF'
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
WARNING: --automatic is enabled.
This script is provided as-is and can break things up, especially with
--automatic.
Proceed only if you understand the repo state and the changes this may make.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF
}

confirm_automatic_mode() {
  warn_automatic_mode

  if [[ "$AUTO_YES" -eq 1 ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    fail "Automatic mode requires confirmation on an interactive terminal. Re-run with --yes/-Y to bypass the prompt."
  fi

  local automatic_reply
  read -r -p "Continue with --automatic? [y/N] " automatic_reply
  case "$automatic_reply" in
    y|Y|yes|YES)
      ;;
    *)
      fail "Automatic mode cancelled."
      ;;
  esac
}

resolve_repo_env_bin() {
  local candidate

  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    case "$VIRTUAL_ENV" in
      "$REPO_DIR"|"$REPO_DIR"/*)
        candidate="$VIRTUAL_ENV/bin"
        if [[ -d "$candidate" ]]; then
          printf '%s\n' "$candidate"
          return 0
        fi
        ;;
    esac
  fi

  for candidate in "$REPO_DIR/.venv/bin" "$REPO_DIR/venv/bin" "$REPO_DIR/env/bin"; do
    if [[ -x "$candidate/python3" || -x "$candidate/python" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

resolve_default_test_cmd() {
  local python_path

  if [[ -n "$REPO_ENV_BIN" ]]; then
    for python_path in "$REPO_ENV_BIN/python3" "$REPO_ENV_BIN/python"; do
      if [[ -x "$python_path" ]] && "$python_path" -m pytest --version >/dev/null 2>&1; then
        printf '%s -m pytest -q\n' "$(shell_quote "$python_path")"
        return 0
      fi
    done
  fi

  if [[ -f "$REPO_DIR/uv.lock" ]] && command_exists_with_repo_env uv; then
    printf 'uv run python -m pytest -q\n'
    return 0
  fi

  if [[ -f "$REPO_DIR/poetry.lock" ]] && command_exists_with_repo_env poetry; then
    printf 'poetry run python -m pytest -q\n'
    return 0
  fi

  return 1
}

run_with_repo_env() {
  if [[ -n "$REPO_ENV_BIN" ]]; then
    PATH="$REPO_ENV_BIN:$PATH" "$@"
  else
    "$@"
  fi
}

command_exists_with_repo_env() {
  if [[ -n "$REPO_ENV_BIN" ]]; then
    PATH="$REPO_ENV_BIN:$PATH" command -v "$1" >/dev/null 2>&1
  else
    command -v "$1" >/dev/null 2>&1
  fi
}

resolve_repo_path() {
  local path="$1"

  case "$path" in
    /*)
      printf '%s\n' "$path"
      ;;
    *)
      printf '%s/%s\n' "$REPO_DIR" "$path"
      ;;
  esac
}

run_repo_shell() {
  local command_text="$1"
  local repo_dir_shell_escaped
  repo_dir_shell_escaped="$(shell_quote "$REPO_DIR")"

  if [[ -n "$REPO_ENV_BIN" ]]; then
    local path_shell_escaped
    path_shell_escaped="$(shell_quote "$REPO_ENV_BIN:$PATH")"
    bash -lc "cd $repo_dir_shell_escaped && export PATH=$path_shell_escaped && $command_text"
  else
    bash -lc "cd $repo_dir_shell_escaped && $command_text"
  fi
}

current_branch_name() {
  git -C "$REPO_DIR" symbolic-ref --quiet --short HEAD
}

branch_exists() {
  local branch_name="$1"
  git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$branch_name"
}

normalise_branch_name() {
  local branch_name="$1"

  [[ -n "$branch_name" ]] || fail "Branch name cannot be empty."
  git -C "$REPO_DIR" check-ref-format --branch "$branch_name" 2>/dev/null \
    || fail "Invalid branch name: $branch_name"
}

generate_prompt_branch_name() {
  local base
  local candidate
  local suffix

  base="prompt-pack/$(date +%Y%m%d-%H%M%S)"
  candidate="$base"
  suffix=2

  while branch_exists "$candidate"; do
    candidate="$base-$suffix"
    suffix=$((suffix + 1))
  done

  printf '%s\n' "$candidate"
}

setup_prompt_branch() {
  ORIGINAL_HEAD="$(git -C "$REPO_DIR" rev-parse HEAD)"
  ORIGINAL_STATUS_WITH_IGNORED="$(git -C "$REPO_DIR" status --porcelain --ignored)"

  if [[ "$NO_BRANCH" -eq 1 ]]; then
    ORIGINAL_BRANCH="$(current_branch_name 2>/dev/null || true)"
    ACTIVE_BRANCH="$ORIGINAL_BRANCH"
    echo "Branch mode disabled; running on the current branch."
    return 0
  fi

  if ! ORIGINAL_BRANCH="$(current_branch_name 2>/dev/null)"; then
    fail "Default branch mode requires a checked-out branch. Use --no-branch to run on a detached HEAD."
  fi

  if [[ -z "$BRANCH_NAME" ]]; then
    BRANCH_NAME="$(generate_prompt_branch_name)"
  fi

  BRANCH_NAME="$(normalise_branch_name "$BRANCH_NAME")"

  if branch_exists "$BRANCH_NAME"; then
    echo "Switching to existing prompt branch: $BRANCH_NAME"
    git -C "$REPO_DIR" switch "$BRANCH_NAME"
    BRANCH_CREATED=0
  else
    echo "Creating prompt branch: $BRANCH_NAME"
    git -C "$REPO_DIR" switch -c "$BRANCH_NAME"
    BRANCH_CREATED=1
  fi

  ACTIVE_BRANCH="$BRANCH_NAME"
}

cleanup_empty_created_branch() {
  local current_branch
  local current_head
  local status_output
  local status_with_ignored

  if [[ "$BRANCH_CREATED" -ne 1 || -z "$ACTIVE_BRANCH" ]]; then
    return 0
  fi

  current_branch="$(current_branch_name 2>/dev/null || true)"
  if [[ "$current_branch" != "$ACTIVE_BRANCH" ]]; then
    return 0
  fi

  current_head="$(git -C "$REPO_DIR" rev-parse HEAD)" || return 1
  status_output="$(git -C "$REPO_DIR" status --porcelain)" || return 1
  status_with_ignored="$(git -C "$REPO_DIR" status --porcelain --ignored)" || return 1

  if [[ "$current_head" != "$ORIGINAL_HEAD" || -n "$status_output" || "$status_with_ignored" != "$ORIGINAL_STATUS_WITH_IGNORED" ]]; then
    return 0
  fi

  echo
  echo "Created branch has no commits, remaining changes, or new ignored files; deleting it: $ACTIVE_BRANCH"
  git -C "$REPO_DIR" switch "$ORIGINAL_BRANCH"
  git -C "$REPO_DIR" branch -d "$ACTIVE_BRANCH"
  BRANCH_CREATED=0
  ACTIVE_BRANCH="$ORIGINAL_BRANCH"
}

normalise_num() {
  local value="$1"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    fail "Prompt number must be numeric: $value"
  fi

  printf "%02d" "$((10#$value))"
}

num_to_int() {
  local value="$1"
  printf "%d" "$((10#$value))"
}

apple_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

send_notification() {
  local title="$1"
  local message="$2"

  if [[ "$NOTIFY" -ne 1 ]]; then
    return 0
  fi

  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Notification requested, but this is not macOS; skipping notification."
    return 0
  fi

  local escaped_title
  local escaped_message
  escaped_title="$(apple_escape "$title")"
  escaped_message="$(apple_escape "$message")"

  /usr/bin/osascript <<EOF2 >/dev/null 2>&1 || true
display notification "$escaped_message" with title "$escaped_title"
EOF2
}

on_exit() {
  local code=$?

  cleanup_empty_created_branch || true

  if [[ "$RUN_STARTED" -eq 1 ]]; then
    if [[ "$code" -eq 0 ]]; then
      send_notification "Prompt pack finished" "All selected prompts completed."
    else
      send_notification "Prompt pack failed" "Stopped with exit code $code."
    fi
  fi

  exit "$code"
}

trap on_exit EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--prompt-dir)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      PROMPT_DIR="$2"
      shift 2
      ;;
    --prompt-dir=*)
      PROMPT_DIR="${1#*=}"
      shift
      ;;

    -a|--agent)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      AGENT="$2"
      shift 2
      ;;
    --agent=*)
      AGENT="${1#*=}"
      shift
      ;;

    -r|--repo)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      REPO_DIR="$2"
      shift 2
      ;;
    --repo=*)
      REPO_DIR="${1#*=}"
      shift
      ;;

    -b|--branch)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      BRANCH_NAME="$2"
      shift 2
      ;;
    --branch=*)
      BRANCH_NAME="${1#*=}"
      shift
      ;;

    --no-branch)
      NO_BRANCH=1
      shift
      ;;

    -f|--first|--start)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      FIRST="$(normalise_num "$2")"
      shift 2
      ;;
    --first=*|--start=*)
      FIRST="$(normalise_num "${1#*=}")"
      shift
      ;;

    -l|--last|--finish)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      LAST="$(normalise_num "$2")"
      shift 2
      ;;
    --last=*|--finish=*)
      LAST="$(normalise_num "${1#*=}")"
      shift
      ;;

    -m|--model)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      MODEL="$2"
      shift 2
      ;;
    --model=*)
      MODEL="${1#*=}"
      shift
      ;;

    --variant)
      [[ $# -ge 2 ]] || fail "$1 requires a value"
      VARIANT="$2"
      shift 2
      ;;
    --variant=*)
      VARIANT="${1#*=}"
      shift
      ;;

    --automatic|--AUTOMATIC)
      AUTOMATIC=1
      shift
      ;;

    -Y|--yes)
      AUTO_YES=1
      shift
      ;;

    -n|--no-notify)
      NOTIFY=0
      shift
      ;;

    --no-tests)
      RUN_TESTS=0
      shift
      ;;

    --no-commit)
      COMMIT_CHANGES=0
      shift
      ;;

    --rollback-on-error)
      ROLLBACK_ON_ERROR=1
      shift
      ;;

    --rollback-yes)
      ROLLBACK_YES=1
      shift
      ;;

    --rollback-clean-ignored)
      ROLLBACK_CLEAN_IGNORED=1
      shift
      ;;

    -h|--help)
      NOTIFY=0
      usage
      exit 0
      ;;

    *)
      fail "Unknown option: $1"
      ;;
  esac
done

if [[ "$NO_BRANCH" -eq 1 && -n "$BRANCH_NAME" ]]; then
  fail "--branch and --no-branch cannot be used together."
fi

if [[ "$ROLLBACK_YES" -eq 1 && "$ROLLBACK_ON_ERROR" -ne 1 ]]; then
  fail "--rollback-yes requires --rollback-on-error."
fi

if [[ "$ROLLBACK_CLEAN_IGNORED" -eq 1 && "$ROLLBACK_ON_ERROR" -ne 1 ]]; then
  fail "--rollback-clean-ignored requires --rollback-on-error."
fi

if [[ "$AUTOMATIC" -eq 1 && "$ROLLBACK_ON_ERROR" -eq 1 && "$ROLLBACK_YES" -ne 1 ]]; then
  fail "--automatic with --rollback-on-error requires --rollback-yes."
fi

case "$AGENT" in
  codex|opencode|claude)
    ;;
  *)
    fail "--agent must be one of: codex, opencode, claude"
    ;;
esac

if [[ -n "$FIRST" && -n "$LAST" ]]; then
  if [[ "$(num_to_int "$FIRST")" -gt "$(num_to_int "$LAST")" ]]; then
    fail "--first/--start must be less than or equal to --last/--finish"
  fi
fi

if [[ -z "$MODEL" ]]; then
  case "$AGENT" in
    codex)
      MODEL="$DEFAULT_MODEL_CODEX"
      ;;
    opencode)
      MODEL="$DEFAULT_MODEL_OPENCODE"
      ;;
    claude)
      MODEL="$DEFAULT_MODEL_CLAUDE"
      ;;
  esac
fi

if [[ -n "$REPO_DIR" ]]; then
  repo_arg="$REPO_DIR"
  [[ -d "$repo_arg" ]] || fail "Repo directory not found: $repo_arg"

  if ! REPO_DIR="$(git -C "$repo_arg" rev-parse --show-toplevel 2>/dev/null)"; then
    fail "Not a git repository: $repo_arg"
  fi
else
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "Run this from the repo root, or pass --repo /path/to/repo."
  fi

  REPO_DIR="$(git rev-parse --show-toplevel)"

  if [[ "$(pwd -P)" != "$REPO_DIR" ]]; then
    fail "Run this from the repo root ($REPO_DIR), or pass --repo /path/to/repo."
  fi
fi

git_status="$(git -C "$REPO_DIR" status --porcelain)"
if [[ -n "$git_status" ]]; then
  echo "Working tree is not clean:"
  git -C "$REPO_DIR" status --short
  fail "Commit or stash changes before running."
fi

setup_prompt_branch

PROMPT_DIR="$(resolve_repo_path "$PROMPT_DIR")"
[[ -d "$PROMPT_DIR" ]] || fail "Prompt directory not found: $PROMPT_DIR"

if ! REPO_ENV_BIN="$(resolve_repo_env_bin)"; then
  REPO_ENV_BIN=""
fi

if ! command_exists_with_repo_env "$AGENT"; then
  fail "Agent command not found in PATH: $AGENT"
fi

if [[ "$RUN_TESTS" -eq 1 && -z "${TEST_CMD:-}" ]]; then
  TEST_CMD="$(resolve_default_test_cmd)" || fail "No repo pytest command found. Add pytest to a repo virtualenv, add uv.lock/poetry.lock, or set TEST_CMD."
fi

SELECTED_PROMPTS=()
had_nullglob=0

if shopt -q nullglob; then
  had_nullglob=1
fi

shopt -s nullglob
for prompt_file in "$PROMPT_DIR"/[0-9][0-9]-*.md; do
  base="$(basename "$prompt_file")"
  num="${base%%-*}"

  if [[ "$num" == "00" ]]; then
    continue
  fi

  if [[ -n "$FIRST" && "$(num_to_int "$num")" -lt "$(num_to_int "$FIRST")" ]]; then
    continue
  fi

  if [[ -n "$LAST" && "$(num_to_int "$num")" -gt "$(num_to_int "$LAST")" ]]; then
    continue
  fi

  SELECTED_PROMPTS+=("$prompt_file")
done

if [[ "$had_nullglob" -eq 0 ]]; then
  shopt -u nullglob
fi

if [[ "${#SELECTED_PROMPTS[@]}" -eq 0 ]]; then
  fail "No prompt files selected."
fi

echo "Prompt directory: $PROMPT_DIR"
echo "Repo root: $REPO_DIR"
if [[ "$NO_BRANCH" -eq 1 ]]; then
  echo "Branch mode: disabled"
else
  echo "Prompt branch: $ACTIVE_BRANCH"
fi
echo "Agent: $AGENT"
echo "Model: $MODEL"
echo "Variant/effort: $VARIANT"
echo "Repo environment: ${REPO_ENV_BIN:-none detected}"
echo "Automatic: $AUTOMATIC"
echo "Run tests: $RUN_TESTS"
echo "Commit changes: $COMMIT_CHANGES"
echo "Rollback on error: $ROLLBACK_ON_ERROR"
echo "Rollback clean ignored: $ROLLBACK_CLEAN_IGNORED"
echo "Notify: $NOTIFY"
echo

echo "Selected prompts:"
for prompt_file in "${SELECTED_PROMPTS[@]}"; do
  echo "  $prompt_file"
done
echo

run_prompt() {
  local prompt_file="$1"
  local prompt_text
  prompt_text="$(cat "$prompt_file")"

  case "$AGENT" in
    codex)
      if [[ "$AUTOMATIC" -eq 1 ]]; then
        run_with_repo_env codex exec \
          --cd "$REPO_DIR" \
          --model "$MODEL" \
          --dangerously-bypass-approvals-and-sandbox \
          "$prompt_text"
      else
        run_with_repo_env codex \
          --cd "$REPO_DIR" \
          --model "$MODEL" \
          --sandbox workspace-write \
          --ask-for-approval on-request \
          "$prompt_text"
      fi
      ;;

    opencode)
      if [[ "$AUTOMATIC" -eq 1 ]]; then
        run_with_repo_env opencode run \
          --dir "$REPO_DIR" \
          --model "$MODEL" \
          --variant "$VARIANT" \
          --dangerously-skip-permissions \
          "$prompt_text"
      else
        run_with_repo_env opencode run \
          --dir "$REPO_DIR" \
          --model "$MODEL" \
          --variant "$VARIANT" \
          "$prompt_text"
      fi
      ;;

    claude)
      if [[ "$AUTOMATIC" -eq 1 ]]; then
        (cd "$REPO_DIR" && run_with_repo_env claude -p \
          --model "$MODEL" \
          --effort "$VARIANT" \
          --dangerously-skip-permissions \
          "$prompt_text")
      else
        (cd "$REPO_DIR" && run_with_repo_env claude \
          --model "$MODEL" \
          --effort "$VARIANT" \
          --permission-mode default \
          "$prompt_text")
      fi
      ;;
  esac
}

run_prompt_iteration() {
  local prompt_file="$1"
  local name="$2"
  local status_output

  echo
  echo "============================================================"
  echo "Running prompt: $prompt_file"
  echo "============================================================"
  echo

  run_prompt "$prompt_file" || return $?

  echo
  echo "Prompt finished: $prompt_file"
  echo

  echo "Current git status:"
  git -C "$REPO_DIR" status --short || return $?
  echo

  if [[ "$RUN_TESTS" -eq 1 ]]; then
    echo "Running tests: $TEST_CMD"
    run_repo_shell "$TEST_CMD" || return $?
    echo
  fi

  if [[ "$COMMIT_CHANGES" -eq 1 ]]; then
    status_output="$(git -C "$REPO_DIR" status --porcelain)" || return $?
    if [[ -n "$status_output" ]]; then
      git -C "$REPO_DIR" add -A || return $?
      git -C "$REPO_DIR" commit -m "Apply $name" || return $?
    else
      echo "No changes to commit for $name."
    fi
  fi

  echo "Completed: $prompt_file"
}

if [[ "$AUTOMATIC" -eq 1 ]]; then
  confirm_automatic_mode
fi

RUN_STARTED=1

for prompt_file in "${SELECTED_PROMPTS[@]}"; do
  name="$(basename "$prompt_file" .md)"
  checkpoint_sha="$(git -C "$REPO_DIR" rev-parse HEAD)"
  prompt_exit=0

  set +e
  run_prompt_iteration "$prompt_file" "$name"
  prompt_exit=$?
  set -e

  if [[ "$prompt_exit" -ne 0 ]]; then
    handle_prompt_failure "$prompt_file" "$checkpoint_sha" "$prompt_exit"
    cleanup_empty_created_branch || true
    exit "$prompt_exit"
  fi
done

echo
echo "All selected prompts completed."
cleanup_empty_created_branch || true
git -C "$REPO_DIR" status --short
