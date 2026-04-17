#!/bin/bash
set -euo pipefail

# Default to non-destructive mode. Pass --apply or -a to perform changes.
APPLY=0
if [ "${1:-}" = "--apply" ] || [ "${1:-}" = "-a" ]; then
	APPLY=1
	shift
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
	cat <<EOF
Usage: $0 [--apply]

Apply preferred MailMate defaults and create helper symlinks. This script writes
to the com.freron.MailMate domain using 'defaults write' and may overwrite
existing settings.

Default: dry-run (no changes). Pass --apply to actually perform writes.
EOF
	exit 0
fi

run_cmd() {
	if [ "$APPLY" -eq 1 ]; then
		"$@"
	else
		printf "[DRY-RUN]"
		for a in "$@"; do printf " %s" "$a"; done
		echo
	fi
}

# MailMate hidden settings
# tom
# 6 Aug 2025

# Experimental dual mode
# MailMate has a layout class for handling multiple modes in a window. This can be used to provide a dual-mode layout in which one can switch between list mode and message mode. To control it, a key binding is needed for nextMode:. To enable this layout, you need to do the following:
# mkdir -p ~/Library/Application\ Support/MailMate/Resources/Layouts/Mailboxes/
# cp /Applications/MailMate.app/Contents/Resources/Layouts/Mailboxes/dualMode.plist ~/Library/Application\ Support/MailMate/Resources/Layouts/Mailboxes/

# Header string for replies

run_cmd defaults write com.freron.MailMate MmReplyWroteString -string '${from.name:${from.address}} (%F %R):'

run_cmd defaults write com.freron.MailMate MmComposerInitialFocus -string "alwaysTextView"
run_cmd defaults write com.freron.MailMate MmNeverInlineAttachments -bool YES

run_cmd ln -s -F /Applications/MailMate.app/ "$HOME/Library/PDF Services/Send PDF with MailMate"
run_cmd defaults write com.freron.MailMate MmSendMessageDelayEnabled -bool YES

run_cmd defaults write com.freron.MailMate MmAutomaticallyExpandThreadsEnabled -bool YES
run_cmd defaults write com.freron.MailMate MmAutomaticallyExpandOnlyWhenCounted -bool NO

run_cmd defaults write com.freron.MailMate MmDockCounterFontSize -float 50.0
run_cmd defaults write com.freron.MailMate MmShowAttachmentsFirst -bool YES

#defaults delete com.freron.MailMate MmDefaultBccHeader

# Ensure the send message delay is set correctly
run_cmd defaults write com.freron.MailMate MmSendMessageDelayEnabled -bool YES
run_cmd defaults write com.freron.MailMate MmSendMessageDelayString -string "5 minutes"
