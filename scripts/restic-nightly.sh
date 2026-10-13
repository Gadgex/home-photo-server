#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin
LOG=$HOME/restic-nightly.log
{
echo "=== $(date) backup start ==="
restic -r rclone:onedrive:immich-restic --password-file $HOME/.restic-pass backup \
  $HOME/immich-app/library \
  --exclude $HOME/immich-app/library/thumbs \
  --exclude $HOME/immich-app/library/encoded-video
rc=$?
echo "=== $(date) backup finished, exit code $rc ==="
} >> "$LOG" 2>&1
