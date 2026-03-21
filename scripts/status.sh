#!/bin/bash
# =============================================================================
# OpenClaw Status Script
# =============================================================================
# Purpose: Check the status of OpenClaw on the VPS.
# Usage: ./scripts/status.sh [VPS_IP]
#
# This script:
#   1. Shows Docker Compose container status
#   2. Shows recent container logs
#   3. Shows system info (disk, memory, uptime)
#   4. Shows Tailscale VPN status (if installed)
#   5. Shows backup status
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/vps.sh"

# -----------------------------------------------------------------------------
# Get VPS IP
# -----------------------------------------------------------------------------

VPS_IP=$(get_vps_ip "${1:-}") || exit 1

echo -e "${BOLD}OpenClaw Status${NC}  ${DIM}$VPS_IP${NC}"
echo ""

# -----------------------------------------------------------------------------
# Check status on VPS
# -----------------------------------------------------------------------------

ssh_to_vps "$VPS_IP" bash -s << 'REMOTE_SCRIPT'

G='\033[0;32m'
Y='\033[1;33m'
R='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
# -----------------------------------------------------------------------------
# Docker Compose status
# -----------------------------------------------------------------------------

cd "$HOME/openclaw" 2>/dev/null || {
    echo -e "${R}Error:${NC} ~/openclaw directory not found. Run bootstrap first."
    exit 1
}

echo -e "${BOLD}Containers${NC}"
echo ""
echo -e "  ${DIM}NAME                          STATUS${NC}"

if [[ -f "docker-compose.yml" ]]; then
    while IFS= read -r line; do
        NAME=$(echo "$line" | cut -f1)
        STATUS=$(echo "$line" | cut -f2-)
        if echo "$STATUS" | grep -q "Up"; then
            echo -e "  ${G}●${NC} ${NAME}  ${G}${STATUS}${NC}"
        elif echo "$STATUS" | grep -q "Restarting\|Exit"; then
            echo -e "  ${R}●${NC} ${NAME}  ${R}${STATUS}${NC}"
        else
            echo -e "  ○ ${NAME}  ${STATUS}"
        fi
    done < <(docker compose ps --format '{{.Name}}\t{{.Status}}' 2>/dev/null)
else
    echo -e "  ${Y}No docker-compose.yml found${NC}"
fi

# -----------------------------------------------------------------------------
# Container logs
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Recent Logs${NC}"
echo ""

if docker compose ps --quiet 2>/dev/null | grep -q .; then
    docker compose logs --tail=10 --no-log-prefix 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${DIM}${line}${NC}"
    done
else
    echo -e "  ${Y}No running containers${NC}"
fi

# -----------------------------------------------------------------------------
# System info
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}System${NC}"
echo ""

# Disk
DISK_LINE=$(df -h / | tail -1)
DISK_USED=$(echo "$DISK_LINE" | awk '{print $5}' | tr -d '%')
DISK_INFO=$(echo "$DISK_LINE" | awk '{printf "%s / %s (%s)", $3, $2, $5}')
if [ "$DISK_USED" -gt 90 ] 2>/dev/null; then
    echo -e "  ${R}Disk:${NC}    $DISK_INFO"
elif [ "$DISK_USED" -gt 70 ] 2>/dev/null; then
    echo -e "  ${Y}Disk:${NC}    $DISK_INFO"
else
    echo -e "  ${G}Disk:${NC}    $DISK_INFO"
fi

# Memory
MEM_INFO=$(free -h | awk 'NR==2{printf "%s / %s", $3, $2}')
echo -e "  ${G}Memory:${NC}  $MEM_INFO"

# Uptime
UP=$(uptime | sed 's/.*up /up /' | sed 's/,.*user.*//')
echo -e "  ${G}Uptime:${NC}  $UP"

# -----------------------------------------------------------------------------
# Tailscale status
# -----------------------------------------------------------------------------

if command -v tailscale &> /dev/null; then
    echo ""
    echo -e "${BOLD}Tailscale${NC}"
    echo ""

    TS_STATE=$(sudo tailscale status --json 2>/dev/null | jq -r '.BackendState' 2>/dev/null || echo "unknown")
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "N/A")

    if [ "$TS_STATE" = "Running" ]; then
        echo -e "  ${G}Status:${NC}  Connected"
        echo -e "  ${G}IP:${NC}      $TS_IP"
    elif [ "$TS_STATE" = "NeedsLogin" ]; then
        echo -e "  ${Y}Status:${NC}  Not authenticated"
        echo -e "  ${DIM}Run 'sudo tailscale up' to authenticate${NC}"
    else
        echo -e "  ${Y}Status:${NC}  $TS_STATE"
        echo -e "  ${DIM}IP:      $TS_IP${NC}"
    fi
fi

# -----------------------------------------------------------------------------
# Fail2ban status
# -----------------------------------------------------------------------------

if command -v fail2ban-client &> /dev/null; then
    echo ""
    echo -e "${BOLD}Fail2ban${NC}"
    echo ""

    F2B_STATUS=$(sudo fail2ban-client status sshd 2>/dev/null || true)
    if [ -n "$F2B_STATUS" ]; then
        CURRENTLY=$(echo "$F2B_STATUS" | grep "Currently banned" | awk '{print $NF}')
        TOTAL=$(echo "$F2B_STATUS" | grep "Total banned" | awk '{print $NF}')
        if [ "${CURRENTLY:-0}" -gt 0 ] 2>/dev/null; then
            echo -e "  ${Y}Banned:${NC}  $CURRENTLY currently (${TOTAL:-0} total)"
        else
            echo -e "  ${G}Banned:${NC}  0 currently (${TOTAL:-0} total)"
        fi
    else
        echo -e "  ${DIM}sshd jail not active${NC}"
    fi
fi

# -----------------------------------------------------------------------------
# Backup status
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}Backups${NC}"
echo ""

LATEST=$(ls -1t "$HOME/backups"/openclaw_backup_*.tar.gz 2>/dev/null | head -1 || true)
if [ -n "$LATEST" ]; then
    COUNT=$(ls -1 "$HOME/backups"/openclaw_backup_*.tar.gz 2>/dev/null | wc -l || echo "0")
    SIZE=$(du -sh "$LATEST" 2>/dev/null | awk '{print $1}')
    NAME=$(basename "$LATEST")
    echo -e "  ${G}Latest:${NC}  $NAME ($SIZE)"
    echo -e "  ${DIM}Total:   $COUNT backup(s)${NC}"
else
    echo -e "  ${DIM}No backups found${NC}"
fi

# -----------------------------------------------------------------------------
# Dropbox bisync status
# -----------------------------------------------------------------------------

if systemctl list-units --all rclone-bisync.timer 2>/dev/null | grep -q rclone-bisync; then
    echo -e "${BOLD}Dropbox Sync${NC}"
    echo ""

    # Remote path from the service ExecStart line
    REMOTE_PATH=$(systemctl show rclone-bisync.service --property=ExecStart 2>/dev/null \
        | grep -oP 'bisync \K[^ ]+' || echo "unknown")
    echo -e "  ${G}Remote:${NC}  $REMOTE_PATH"

    # Last run time + result from systemd
    LAST_RUN=$(systemctl show rclone-bisync.service --property=ExecMainExitTimestamp 2>/dev/null \
        | cut -d= -f2)
    LAST_RESULT=$(systemctl show rclone-bisync.service --property=Result 2>/dev/null \
        | cut -d= -f2)

    if [[ -z "$LAST_RUN" || "$LAST_RUN" == "n/a" ]]; then
        echo -e "  ${DIM}Last run: not yet run since boot${NC}"
    elif [[ "$LAST_RESULT" == "success" ]]; then
        echo -e "  ${G}Last run:${NC} $LAST_RUN  ${G}✓${NC}"
    else
        echo -e "  ${R}Last run:${NC} $LAST_RUN  ${R}✗ ($LAST_RESULT)${NC}"
    fi

    # Next scheduled run
    NEXT=$(systemctl list-timers rclone-bisync --no-pager 2>/dev/null \
        | awk 'NR==2 {print $1, $2, $3}')
    [[ -n "$NEXT" ]] && echo -e "  ${DIM}Next run: $NEXT${NC}"

    echo ""
fi

echo ""
REMOTE_SCRIPT
