#!/bin/bash
set -euo pipefail

usage() {
	echo "Usage: $0 [--help]"
	echo
	echo "Generate a Brewfile for installed Homebrew packages via 'brew bundle dump'."
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	usage
	exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
	echo "Error: Homebrew not found. Install Homebrew first: https://brew.sh" >&2
	exit 1
fi

# Dump the current Homebrew bundle to Brewfile in the current directory
brew bundle dump
