#!/usr/bin/env zsh
# Run a given executable script once per subsequent argument.
# Usage:
#   run_script_on.sh <script> <arg1> [arg2 ...]

set -u

usage() {
  echo "Usage: $0 <script> <arg1> [arg2 ...]" >&2
  exit 1
}

# Need at least the script and one arg
[[ $# -ge 2 ]] || usage

script_spec="$1"
shift

# Resolve script path (support either absolute/relative path or PATH lookup)
if [[ "$script_spec" == */* ]]; then
  script="$script_spec"
else
  script="$(command -v -- "$script_spec" 2>/dev/null || true)"
fi

if [[ -z "${script:-}" ]]; then
  echo "Error: script '$script_spec' not found in PATH." >&2
  exit 2
fi
if [[ ! -x "$script" ]]; then
  echo "Error: '$script' is not executable." >&2
  exit 3
fi

fail=0
for arg in "$@"; do
  echo "------------------------------------------------------------------------"
  echo "→ Running: $script" "$arg"
  "$script" "$arg" || { echo "✗ Failed with argument: $arg" >&2; fail=1; }
done

exit $fail