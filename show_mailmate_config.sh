#!/bin/bash
# show_mailmate_config.sh — print selected MailMate defaults
# Usage: show_mailmate_config.sh [DOMAIN] [-h|--help]
# Default DOMAIN: com.freron.MailMate
# Note: Read-only — this prints selected keys from the `defaults` domain.

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<EOF
Usage: $0 [DOMAIN]

Print selected MailMate defaults for a domain (default: com.freron.MailMate).
EOF
  exit 0
fi

DOMAIN="${1:-com.freron.MailMate}"

keys=(
  "MmReplyWroteString"
  "MmComposerInitialFocus"
  "MmNeverInlineAttachments"
  "MmSendMessageDelayEnabled"
  "MmSendMessageDelayString"
  "MmAutomaticallyExpandThreadsEnabled"
  "MmAutomaticallyExpandOnlyWhenCounted"
  "MmDockCounterFontSize"
  "MmShowAttachmentsFirst"
  "MmDefaultBccHeader"
)

echo "📬 MailMate configuration for domain: $DOMAIN"
echo "---------------------------------------------"

for key in "${keys[@]}"; do
  value=$(defaults read "$DOMAIN" "$key" 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "$key = $value"
  else
    echo "$key is not set"
  fi
done
