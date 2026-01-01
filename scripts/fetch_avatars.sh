#!/bin/bash
BOT="$1"
shift
mkdir -p avatars

for ID in "$@"; do
  FILE_ID=$(curl -s "https://api.telegram.org/bot$BOT/getUserProfilePhotos?user_id=$ID&limit=1" | jq -r '.result.photos[0][0].file_id')
  FILE_PATH=$(curl -s "https://api.telegram.org/bot$BOT/getFile?file_id=$FILE_ID" | jq -r '.result.file_path')
  curl -s "https://api.telegram.org/file/bot$BOT/$FILE_PATH" -o avatars/$ID.jpg
done
