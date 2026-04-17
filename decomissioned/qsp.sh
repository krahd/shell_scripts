#!/bin/bash
# qsp.sh — tiny UI automation using `cliclick`
# Usage: qsp.sh [-h|--help]
# Note: Requires /opt/homebrew/bin/cliclick to be installed. This script sends a sequence
# of GUI key events; use with care as it drives the active UI.

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	cat <<EOF
Usage: $0

Run a short cliclick script that issues keyboard events. Ensure you have
installed cliclick and given accessibility permissions if required.
EOF
	exit 0
fi

/opt/homebrew/bin/cliclick kd:cmd kp:space ku:cmd t:"." kd:cmd t:"v" ku:cmd kp:tab t:"p" kp:enter
