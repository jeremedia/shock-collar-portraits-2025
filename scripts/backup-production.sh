#!/bin/bash
# Backup production databases
# Run this periodically to preserve production data

set -e

echo "🔒 Backing up production databases..."

# Create timestamped backup on production server
ssh jeremy@jer-serve "
  cd /home/jeremy/apps/shock-collar-portraits-2025
  BACKUP_DIR=storage/backups/\$(date +%Y%m%d_%H%M%S)
  mkdir -p \$BACKUP_DIR
  cp storage/production*.sqlite3 \$BACKUP_DIR/
  echo \"✅ Production backed up to: \$BACKUP_DIR\"

  # Keep only last 10 backups
  ls -dt storage/backups/* | tail -n +11 | xargs rm -rf 2>/dev/null || true
"

# Optional: Pull backup to local
read -p "Download backup to local machine? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    LOCAL_BACKUP_DIR="storage/production-backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOCAL_BACKUP_DIR"
    echo "⬇️  Downloading backup to $LOCAL_BACKUP_DIR..."
    rsync -avz --progress \
      jeremy@jer-serve:/home/jeremy/apps/shock-collar-portraits-2025/storage/production*.sqlite3 \
      "$LOCAL_BACKUP_DIR/"
    echo "✅ Backup downloaded!"
fi