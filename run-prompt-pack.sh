#!/usr/bin/env bash
# Run numbered Markdown prompt files through Codex, OpenCode, or Claude Code.
# Compatible with macOS Bash 3.2 and zsh callers. Execute this file directly;
# the shebang selects Bash even if your interactive shell is zsh.
set -euo pipefail

PROMPT_DIR="audit-prompts"
AGENT="codex"
FIRST=""
LAST=""
NOTIFY=0
RUN_TESTS=1
COMMIT_CHANGES=1
AUTOMATIC=0

MODEL=""
VARIANT="xhigh"
TEST_CMD="${TEST_CMD:-python -m pytest -q}"

usage() {
  cat <<'USAGE'
Usage:
  run-prompt-pack.sh [OPTIONS]

Runs numbered Markdown prompt files one at a time. Each selected prompt must be
named NN-something.md, for example 01-fix-ci.md. Files named 00-*.md are skipped.

Options:
  -d, --prompt-dir DIR     Directory containing prompt files. Default: audit-prompts
  -a, --agent AGENT        Agent to use: codex, opencode, claude. Default: codex
  -f, --first NUM          First prompt number to run, e.g. 01. Optional.
      --start NUM          Alias for --first
  -l, --last NUM           Last prompt number to run, e.g. 04. Optional.
      --finish NUM         Alias for --last
  -m, --model MODEL        Override model name
      --variant VALUE      Reasoning/variant/effort value. Default: xhigh
      --automatic          Fully unattended mode where supported
      --AUTOMATIC          Alias for --automatic
  -n, --notify             Show a macOS notification when finished or failed
      --no-tests           Do not run tests after each prompt
      --no-commit          Do not commit after each prompt
  -h, --help               Show this help

Default behaviour:
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
  run-prompt-pack.sh --prompt-dir ../squarespace-to-astro-repair-prompts-v2
  run-prompt-pack.sh --first 01 --last 02
  run-prompt-pack.sh --start=02 --finish=04
  run-prompt-pack.sh --agent codex --model gpt-5.4-mini --automatic -n
  run-prompt-pack.sh --agent opencode --model openai/gpt-5.4-mini --variant xhigh
  run-prompt-pack.sh --agent claude --model sonnet --variant xhigh

Environment:
  TEST_CMD                Test command. Default: python -m pytest -q
USAGE
}

fail() {
  echo "Error: $*" >&2
  exit 1
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

  if [[ "$code" -eq 0 ]]; then
    send_notification "Prompt pack finished" "All selected prompts completed."
  else
    send_notification "Prompt pack failed" "Stopped with exit code $code."
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

    -n|--notify)
      NOTIFY=1
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

    -h|--help)
      usage
      exit 0
      ;;

    *)
      fail "Unknown option: $1"
      ;;
  esac
done

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
      MODEL="gpt-5.4-mini"
      ;;
    opencode)
      MODEL="openai/gpt-5.4-mini"
      ;;
    claude)
      MODEL="sonnet"
      ;;
  esac
fi

[[ -d "$PROMPT_DIR" ]] || fail "Prompt directory not found: $PROMPT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  fail "Run this from inside the repository."
fi

if ! command -v "$AGENT" >/dev/null 2>&1; then
  fail "Agent command not found in PATH: $AGENT"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean:"
  git status --short
  fail "Commit or stash changes before running."
fi

SELECTED_PROMPTS=()

while IFS= read -r prompt_file; do
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
done < <(find "$PROMPT_DIR" -maxdepth 1 -type f -name '[0-9][0-9]-*.md' | sort)

if [[ "${#SELECTED_PROMPTS[@]}" -eq 0 ]]; then
  fail "No prompt files selected."
fi

echo "Prompt directory: $PROMPT_DIR"
echo "Agent: $AGENT"
echo "Model: $MODEL"
echo "Variant/effort: $VARIANT"
echo "Automatic: $AUTOMATIC"
echo "Run tests: $RUN_TESTS"
echo "Commit changes: $COMMIT_CHANGES"
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
        codex exec \
          --cd "$PWD" \
          --model "$MODEL" \
          --dangerously-bypass-approvals-and-sandbox \
          "$prompt_text"
      else
        codex \
          --cd "$PWD" \
          --model "$MODEL" \
          --sandbox workspace-write \
          --ask-for-approval on-request \
          "$prompt_text"
      fi
      ;;

    opencode)
      if [[ "$AUTOMATIC" -eq 1 ]]; then
        opencode run \
          --dir "$PWD" \
          --model "$MODEL" \
          --variant "$VARIANT" \
          --dangerously-skip-permissions \
          "$prompt_text"
      else
        opencode run \
          --dir "$PWD" \
          --model "$MODEL" \
          --variant "$VARIANT" \
          "$prompt_text"
      fi
      ;;

    claude)
      if [[ "$AUTOMATIC" -eq 1 ]]; then
        claude -p \
          --model "$MODEL" \
          --effort "$VARIANT" \
          --dangerously-skip-permissions \
          "$prompt_text"
      else
        claude \
          --model "$MODEL" \
          --effort "$VARIANT" \
          --permission-mode default \
          "$prompt_text"
      fi
      ;;
  esac
}

for prompt_file in "${SELECTED_PROMPTS[@]}"; do
  name="$(basename "$prompt_file" .md)"

  echo
  echo "============================================================"
  echo "Running prompt: $prompt_file"
  echo "============================================================"
  echo

  run_prompt "$prompt_file"

  echo
  echo "Prompt finished: $prompt_file"
  echo

  echo "Current git status:"
  git status --short
  echo

  if [[ "$RUN_TESTS" -eq 1 ]]; then
    echo "Running tests: $TEST_CMD"
    bash -lc "$TEST_CMD"
    echo
  fi

  if [[ "$COMMIT_CHANGES" -eq 1 ]]; then
    if [[ -n "$(git status --porcelain)" ]]; then
      git add -A
      git commit -m "Apply $name"
    else
      echo "No changes to commit for $name."
    fi
  fi

  echo "Completed: $prompt_file"
done

echo
echo "All selected prompts completed."
git status --short
