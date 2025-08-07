#!/bin/bash

# MailMate hidden settings
# tom
# 6 Aug 2025

# Experimental dual mode
# MailMate has a layout class for handling multiple modes in a window. This can be used to provide a dual-mode layout in which one can switch between list mode and message mode. To control it, a key binding is needed for nextMode:. To enable this layout, you need to do the following:
# mkdir -p ~/Library/Application\ Support/MailMate/Resources/Layouts/Mailboxes/
# cp /Applications/MailMate.app/Contents/Resources/Layouts/Mailboxes/dualMode.plist ~/Library/Application\ Support/MailMate/Resources/Layouts/Mailboxes/

# Header string for replies
defaults write com.freron.MailMate MmReplyWroteString -string '${from.name:${from.address}} (%F %R):'

defaults write com.freron.MailMate MmComposerInitialFocus -string "alwaysTextView"
defaults write com.freron.MailMate MmNeverInlineAttachments -bool YES

ln -s -F /Applications/MailMate.app/ ~/Library/PDF\ Services/'Send PDF with MailMate'
defaults write com.freron.MailMate MmSendMessageDelayEnabled -bool YES

defaults write com.freron.MailMate MmAutomaticallyExpandThreadsEnabled -bool YES
defaults write com.freron.MailMate MmAutomaticallyExpandOnlyWhenCounted -bool NO

defaults write com.freron.MailMate MmDockCounterFontSize -float 50.0
defaults write com.freron.MailMate MmShowAttachmentsFirst -bool YES

#defaults delete com.freron.MailMate MmDefaultBccHeader

# Ensure the send message delay is set correctly
defaults write com.freron.MailMate MmSendMessageDelayEnabled -bool YES
defaults write com.freron.MailMate MmSendMessageDelayString -string "5 minutes"
