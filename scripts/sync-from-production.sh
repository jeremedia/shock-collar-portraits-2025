#!/bin/bash
# Sync production databases back to local development
# This is for the unique workflow where production is the source of truth

set -e

echo "🔄 Syncing databases FROM production TO local development..."
echo "⚠️  This will overwrite your local development databases!"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cancelled."
    exit 1
fi

# Create backup of current local databases
BACKUP_DIR="storage/backups/$(date +%Y%m%d_%H%M%S)"
echo "📦 Backing up current local databases to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp storage/development*.sqlite3* "$BACKUP_DIR/" 2>/dev/null || true

# Sync from production
echo "⬇️  Downloading production databases..."
rsync -avz --progress \
  jeremy@jer-serve:/home/jeremy/apps/shock-collar-portraits-2025/storage/production*.sqlite3 \
  storage/

# Copy production databases to development names
echo "📝 Copying to development database names..."
cp storage/production.sqlite3 storage/development.sqlite3
cp storage/production_cache.sqlite3 storage/development_cache.sqlite3
cp storage/production_queue.sqlite3 storage/development_queue.sqlite3

echo "✅ Sync complete! Local development now matches production."
echo "💡 Backup saved in: $BACKUP_DIR"