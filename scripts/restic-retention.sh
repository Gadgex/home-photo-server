#!/bin/bash
export PATH=/usr/local/bin:/usr/bin:/bin
LOG=$HOME/restic-retention.log
{
echo "=== $(date) retention start ==="
restic -r rclone:onedrive:immich-restic --password-file $HOME/.restic-pass forget \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 3 --prune
rc=$?
echo "=== $(date) retention finished, exit code $rc ==="
} >> "$LOG" 2>&1
