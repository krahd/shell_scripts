#!/bin/bash

DOMAIN="com.freron.MailMate"

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
