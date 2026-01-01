#!/bin/bash
BOT="$1"
CHAT="$2"

curl -s -X POST \
  "https://api.telegram.org/bot$BOT/sendVideo" \
  -F chat_id="$CHAT" \
  -F video=@output.mp4
