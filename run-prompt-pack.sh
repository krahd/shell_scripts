#!/usr/bin/env bash
set -euo pipefail

PROMPT_DIR="audit-prompts"
AGENT="codex"
FIRST=""
LAST=""
NOTIFY=0
RUN_TESTS=1
COMMIT_CHANGES=1

MODEL=""
VARIANT="xhigh"
TEST_CMD="${TEST_CMD:-python -m pytest -q}"

usage() {
  cat <<'EOF'
Usage:
  scripts/run-prompt-pack.sh [OPTIONS]

Runs numbered Markdown prompt files one at a time, waiting for each agent run
to finish before starting the next.

Options:
  -d, --prompt-dir DIR     Directory containing prompt files. Default: audit-prompts
  -a, --agent AGENT        Agent to use: codex, opencode, claude. Default: codex
  -f, --first NUM          First prompt number to run, e.g. 01
      --start NUM          Alias for --first
  -l, --last NUM           Last prompt number to run, e.g. 04
      --finish NUM         Alias for --last
  -m, --model MODEL        Override model name
      --variant VALUE      Reasoning/variant value. Default: xhigh
  -n, --notify             Show a macOS notification when finished or failed
      --no-tests           Do not run tests after each prompt
      --no-commit          Do not commit after each prompt
  -h, --help               Show this help

Examples:
  scripts/run-prompt-pack.sh
  scripts/run-prompt-pack.sh --first 01 --last 02
  scripts/run-prompt-pack.sh --first=01 --last=02
  scripts/run-prompt-pack.sh --start 02 --finish 04
  scripts/run-prompt-pack.sh --agent codex --model gpt-5.4-mini
  scripts/run-prompt-pack.sh --agent opencode --model openai/gpt-5.4-mini --variant xhigh
  scripts/run-prompt-pack.sh --agent claude --model sonnet --variant xhigh
  scripts/run-prompt-pack.sh -a codex -f 02 -l 04 -n

Environment:
  TEST_CMD                Test command. Default: python -m pytest -q
EOF
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

  /usr/bin/osascript <<EOF >/dev/null 2>&1 || true
display notification "$escaped_message" with title "$escaped_title"
EOF
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

  if [[ -n "$FIRST" && "$((10#$num))" -lt "$((10#$FIRST))" ]]; then
    continue
  fi

  if [[ -n "$LAST" && "$((10#$num))" -gt "$((10#$LAST))" ]]; then
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

  case "$AGENT" in
    codex)
      codex exec \
        --cd "$PWD" \
        --model "$MODEL" \
        --sandbox workspace-write \        
        - < "$prompt_file"
      ;;
    
    opencode)
      prompt_text="$(cat "$prompt_file")"
      opencode run \
        --dir "$PWD" \
        --model "$MODEL" \
        --variant "$VARIANT" \
        --dangerously-skip-permissions \
        "$prompt_text"
      ;;

    claude)
      prompt_text="$(cat "$prompt_file")"
      claude -p \
        --model "$MODEL" \
        --effort "$VARIANT" \
        --permission-mode bypassPermissions \
        "$prompt_text"
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