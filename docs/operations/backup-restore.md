---
title: "Backup & Restore"
weight: 3
---

Backups run daily at **03:00 UTC** via systemd timer and are stored in `~/backups/` on the VPS.

## Make Targets

```bash
make backup-now   # Trigger backup immediately
make backup-pull  # Download latest backup archive locally
make restore      # List available backups (dry-run — safe)
make restore EXECUTE=1 BACKUP=<file>  # Restore from backup
```

`make restore` without `EXECUTE=1` is always safe — it just lists available backups.

## Backup Contents

Each archive (`openclaw_backup_*.tar.gz`) includes:

- `~/.openclaw/` — full OpenClaw state (config, workspace, LCM history)
- `~/.config/sops/` — SOPS age key (required to decrypt secrets)

## Restore Procedure

```bash
make restore        # list available backups (safe, no changes)
make restore EXECUTE=1 BACKUP=openclaw_backup_20260101_030000.tar.gz
```

With `EXECUTE=1`, the restore play:

1. Validates the backup file and compose directory
2. Stops containers
3. Creates a safety backup of current state (including SOPS age key)
4. Extracts the archive
5. Validates critical files exist after extraction
6. Pulls latest container images
7. Restarts containers
8. Waits for gateway health endpoint (30s timeout)
10. Prints a summary with undo instructions

## Undoing a Restore

If a restore goes wrong, use the safety backup created in step 3:

```bash
make restore EXECUTE=1 BACKUP=openclaw_pre_restore_<timestamp>.tar.gz
```

The safety backup is stored at `~/backups/openclaw_pre_restore_*.tar.gz` on the VPS.

## Before Upgrading

Always back up before bumping the OpenClaw version:

```bash
make backup-now
# Edit docker/Dockerfile — bump OPENCLAW_VERSION
make deploy REBUILD=1
```
