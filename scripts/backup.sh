#!/bin/bash
# =============================================================================
# OpenClaw Backup Script
# =============================================================================
# Purpose: Creates a backup of ~/.openclaw directory.
# Usage: Run on the VPS directly, or called by systemd timer.
#
# This script:
#   1. Creates a timestamped tar.gz of ~/.openclaw + SOPS age key (~/.config/sops)
#   2. Stores it in ~/backups/
#   3. Backs up Mission Control database from Docker volume (if present)
#   4. Removes backups older than 7 days
#
# Note: This script is meant to run ON the VPS, not from your laptop.
#       For remote backup, use: ssh openclaw@VPS ./scripts/backup.sh
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BACKUP_DIR="$HOME/backups"
SOURCE_DIR="$HOME/.openclaw"
RETENTION_DAYS=7

# -----------------------------------------------------------------------------
# Create backup directory
# -----------------------------------------------------------------------------

mkdir -p "$BACKUP_DIR"

# -----------------------------------------------------------------------------
# Check if source exists
# -----------------------------------------------------------------------------

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Warning: Source directory $SOURCE_DIR does not exist"
    echo "Nothing to backup"
    exit 0
fi

# -----------------------------------------------------------------------------
# Create backup
# -----------------------------------------------------------------------------

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/openclaw_backup_$TIMESTAMP.tar.gz"

echo "=== OpenClaw Backup ==="
echo "Source: $SOURCE_DIR"
echo "Destination: $BACKUP_FILE"
echo ""

echo "[...] Creating backup..."

# Create tar.gz archive — includes .openclaw and SOPS age key (if present)
# The age key is critical: without it, encrypted secrets (.env.enc) can't
# be decrypted after restore. Including it makes backups self-contained.
BACKUP_PATHS=(".openclaw")
if [[ -d "$HOME/.config/sops" ]]; then
    BACKUP_PATHS+=(".config/sops")
fi
tar -czf "$BACKUP_FILE" -C "$HOME" "${BACKUP_PATHS[@]}"

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "[OK] Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# -----------------------------------------------------------------------------
# Backup Mission Control database from Docker volume
# -----------------------------------------------------------------------------

MC_BACKUP_FILE="$BACKUP_DIR/mc_backup_$TIMESTAMP.db"

echo ""
echo "[...] Backing up Mission Control database..."

if docker volume inspect openclaw_mission-control-data > /dev/null 2>&1; then
    docker run --rm \
        -v openclaw_mission-control-data:/data \
        -v "$BACKUP_DIR":/backup \
        alpine sh -c "apk add -q sqlite > /dev/null 2>&1 && sqlite3 /data/mission-control.db '.backup /backup/mc_backup_${TIMESTAMP}.db'"
    MC_SIZE=$(du -h "$MC_BACKUP_FILE" | cut -f1)
    echo "[OK] MC database backed up: $MC_BACKUP_FILE ($MC_SIZE)"
else
    echo "[SKIP] Mission Control volume not found — skipping"
fi

# -----------------------------------------------------------------------------
# Clean up old backups
# -----------------------------------------------------------------------------

echo ""
echo "[...] Cleaning up backups older than $RETENTION_DAYS days..."

# Find and delete old backups
OLD_COUNT=$(find "$BACKUP_DIR" -name "openclaw_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS | wc -l)

if [[ $OLD_COUNT -gt 0 ]]; then
    find "$BACKUP_DIR" -name "openclaw_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "mc_backup_*.db" -type f -mtime +$RETENTION_DAYS -delete
    echo "[OK] Deleted $OLD_COUNT old backup(s)"
else
    echo "[OK] No old backups to delete"
fi

# -----------------------------------------------------------------------------
# List current backups
# -----------------------------------------------------------------------------

echo ""
echo "=== Current Backups ==="
ls -lh "$BACKUP_DIR"/openclaw_backup_*.tar.gz 2>/dev/null || echo "No backups found"

echo ""
echo "=== Backup Complete ==="
