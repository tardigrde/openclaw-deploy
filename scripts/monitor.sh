#!/usr/bin/env bash
# =============================================================================
# OpenClaw Health Monitor — VPS Health Checks with Telegram Alerts
# =============================================================================
# Deployed to VPS by: make monitor-enable
# Runs via systemd timer every 5 minutes.
#
# Checks: container health, HTTP endpoint, disk, memory, backup recency.
# Alerts via Telegram when checks fail (with cooldown to prevent storms).
#
# Credentials are resolved at runtime (no plaintext secrets stored):
#   TELEGRAM_BOT_TOKEN  — from ~/.openclaw/.env or sops-decrypted .env.enc
#   MONITOR_CHAT_ID     — from ~/.openclaw/openclaw.json allowFrom[0]
#
# State file: ~/.openclaw/monitor-state.json
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
ALERT_COOLDOWN_SECONDS=3600    # 1 hour between repeated alerts per check
CONSECUTIVE_FAILURES_BEFORE_ALERT=2
DISK_WARN_PERCENT=85
DISK_CRIT_PERCENT=95
MEMORY_WARN_PERCENT=90
BACKUP_MAX_AGE_HOURS=48
HEALTH_URL="http://127.0.0.1:18789/health"
HEALTH_TIMEOUT=5

STATE_FILE="${HOME}/.openclaw/monitor-state.json"

# -----------------------------------------------------------------------------
# Resolve credentials (no plaintext secrets on disk)
# -----------------------------------------------------------------------------
load_credentials() {
  # Telegram bot token — try decrypted .env first, then decrypt .env.enc on the fly
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    TELEGRAM_BOT_TOKEN="$(
      grep -E '^TELEGRAM_BOT_TOKEN=' ~/.openclaw/.env 2>/dev/null | head -1 | cut -d= -f2-
    )" || true
  fi

  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    local env_enc="${HOME}/openclaw/secrets/.env.enc"
    local sops_key="${HOME}/.config/sops/age/keys.txt"
    if [[ -f "$env_enc" && -f "$sops_key" ]] && command -v sops &>/dev/null; then
      TELEGRAM_BOT_TOKEN="$(
        SOPS_AGE_KEY_FILE="$sops_key" \
          sops -d --input-type dotenv --output-type dotenv "$env_enc" 2>/dev/null \
          | grep -E '^TELEGRAM_BOT_TOKEN=' | head -1 | cut -d= -f2-
      )" || true
    fi
  fi

  # Chat ID — read from openclaw.json (no secrets involved)
  if [[ -z "${MONITOR_CHAT_ID:-}" ]]; then
    MONITOR_CHAT_ID="$(
      jq -r '.channels.telegram.allowFrom[0] // empty' ~/.openclaw/openclaw.json 2>/dev/null
    )" || true
  fi

  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${MONITOR_CHAT_ID:-}" ]]; then
    echo "[monitor] ERROR: Could not resolve TELEGRAM_BOT_TOKEN or MONITOR_CHAT_ID"
    echo "  Ensure ~/.openclaw/.env (or .env.enc + sops) and ~/.openclaw/openclaw.json are configured."
    exit 1
  fi
}

load_credentials

# -----------------------------------------------------------------------------
# State Management
# -----------------------------------------------------------------------------

init_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # Validate existing state file — reinitialize if corrupted
    if ! jq . "$STATE_FILE" > /dev/null 2>&1; then
      echo "[monitor] WARNING: State file corrupted, reinitializing"
      rm -f "$STATE_FILE"
    fi
  fi
  if [[ ! -f "$STATE_FILE" ]]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    echo '{"last_alerts":{},"failures":{},"previously_failing":{}}' > "$STATE_FILE"
  fi
}

get_state_value() {
  local key="$1"
  jq -r "$key // empty" "$STATE_FILE" 2>/dev/null || true
}

set_state_value() {
  local key="$1" value="$2"
  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  jq "$key = $value" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

get_failure_count() {
  local check="$1"
  get_state_value ".failures.\"$check\" // 0"
}

increment_failures() {
  local check="$1"
  local count
  count="$(get_failure_count "$check")"
  set_state_value ".failures.\"$check\"" "$(( count + 1 ))"
}

reset_failures() {
  local check="$1"
  set_state_value ".failures.\"$check\"" "0"
}

was_previously_failing() {
  local check="$1"
  local val
  val="$(get_state_value ".previously_failing.\"$check\"")"
  [[ "$val" == "true" ]]
}

set_previously_failing() {
  local check="$1" value="$2"
  set_state_value ".previously_failing.\"$check\"" "$value"
}

# should_alert returns 0 if we should send an alert for this check
should_alert() {
  local check="$1"
  local failures
  failures="$(get_failure_count "$check")"

  # Need consecutive failures before alerting
  if [[ "$failures" -lt "$CONSECUTIVE_FAILURES_BEFORE_ALERT" ]]; then
    return 1
  fi

  # Check cooldown
  local last_alert
  last_alert="$(get_state_value ".last_alerts.\"$check\"")"
  if [[ -n "$last_alert" ]]; then
    local now last_epoch
    now="$(date +%s)"
    last_epoch="$(date -d "$last_alert" +%s 2>/dev/null)" || last_epoch=0
    if (( now - last_epoch < ALERT_COOLDOWN_SECONDS )); then
      return 1
    fi
  fi

  return 0
}

record_alert() {
  local check="$1"
  set_state_value ".last_alerts.\"$check\"" "\"$(date -Iseconds)\""
}

# -----------------------------------------------------------------------------
# Telegram Alerting
# -----------------------------------------------------------------------------

send_telegram() {
  local message="$1"
  curl -sf --max-time 10 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${MONITOR_CHAT_ID}" \
    -d "text=${message}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1 || echo "[monitor] WARNING: Failed to send Telegram alert"
}

# alert sends a failure notification (with cooldown + consecutive failure check)
alert() {
  local check="$1" message="$2"

  increment_failures "$check"

  if should_alert "$check"; then
    local hostname
    hostname="$(hostname 2>/dev/null || echo "unknown")"
    send_telegram "<b>[OpenClaw Monitor]</b> ${hostname}
${message}"
    record_alert "$check"
    set_previously_failing "$check" "true"
  fi
}

# recover sends a recovery notification if the check was previously failing
recover() {
  local check="$1" message="$2"

  if was_previously_failing "$check"; then
    local hostname
    hostname="$(hostname 2>/dev/null || echo "unknown")"
    send_telegram "<b>[OpenClaw Monitor]</b> ${hostname}
${message}"
    set_previously_failing "$check" "false"
  fi

  reset_failures "$check"
}

# -----------------------------------------------------------------------------
# Health Checks
# -----------------------------------------------------------------------------

check_container_health() {
  local check_name="container_health"

  # Check if docker is available
  if ! command -v docker &>/dev/null; then
    alert "$check_name" "Docker not found on this host."
    return
  fi

  # Check if the gateway container is running
  local container_id
  container_id="$(docker ps -q -f label=com.docker.compose.service=openclaw-gateway 2>/dev/null)" || true

  if [[ -z "$container_id" ]]; then
    alert "$check_name" "Gateway container is not running."
    return
  fi

  # Check container health status
  local health_status
  health_status="$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null)" || health_status="unknown"

  case "$health_status" in
    healthy)
      recover "$check_name" "Gateway container is healthy again."
      ;;
    unhealthy)
      alert "$check_name" "Gateway container is <b>unhealthy</b>."
      ;;
    starting)
      # Don't alert during startup — wait for next cycle
      ;;
    *)
      # No healthcheck configured or unknown — check if running
      local state
      state="$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null)" || state="unknown"
      if [[ "$state" == "running" ]]; then
        recover "$check_name" "Gateway container is running again."
      else
        alert "$check_name" "Gateway container state: <b>${state}</b>"
      fi
      ;;
  esac
}

check_http_health() {
  local check_name="http_health"

  if curl -sf --max-time "$HEALTH_TIMEOUT" "$HEALTH_URL" > /dev/null 2>&1; then
    recover "$check_name" "Gateway HTTP endpoint is responding again."
  else
    alert "$check_name" "Gateway HTTP health check failed (${HEALTH_URL})."
  fi
}

check_disk_usage() {
  local check_name="disk_usage"

  local usage_percent
  usage_percent="$(df / --output=pcent 2>/dev/null | tail -1 | tr -d ' %')" || usage_percent=0

  if (( usage_percent >= DISK_CRIT_PERCENT )); then
    alert "$check_name" "Disk usage is <b>CRITICAL: ${usage_percent}%</b> (>= ${DISK_CRIT_PERCENT}%)."
  elif (( usage_percent >= DISK_WARN_PERCENT )); then
    alert "$check_name" "Disk usage is <b>high: ${usage_percent}%</b> (>= ${DISK_WARN_PERCENT}%)."
  else
    recover "$check_name" "Disk usage is back to normal: ${usage_percent}%."
  fi
}

check_memory() {
  local check_name="memory"

  local mem_info
  mem_info="$(free | grep '^Mem:')" || true

  if [[ -z "$mem_info" ]]; then
    return
  fi

  local total available
  total="$(echo "$mem_info" | awk '{print $2}')"
  available="$(echo "$mem_info" | awk '{print $7}')"

  if [[ "$total" -eq 0 ]]; then
    return
  fi

  local used_percent
  used_percent=$(( (total - available) * 100 / total ))

  if (( used_percent >= MEMORY_WARN_PERCENT )); then
    local avail_mb=$(( available / 1024 ))
    alert "$check_name" "Memory usage is <b>high: ${used_percent}%</b> (${avail_mb}MB available)."
  else
    recover "$check_name" "Memory usage is back to normal: ${used_percent}%."
  fi
}

check_backup_recency() {
  local check_name="backup_recency"
  local backup_dir="${HOME}/backups"

  if [[ ! -d "$backup_dir" ]]; then
    return # No backup dir — backups not configured
  fi

  local latest_backup
  latest_backup="$(find "$backup_dir" -name '*.tar.gz' -type f -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)" || true

  if [[ -z "$latest_backup" ]]; then
    alert "$check_name" "No backups found in ${backup_dir}."
    return
  fi

  local backup_age_seconds now_epoch backup_epoch
  now_epoch="$(date +%s)"
  backup_epoch="$(stat -c %Y "$latest_backup" 2>/dev/null)" || backup_epoch=0
  backup_age_seconds=$(( now_epoch - backup_epoch ))
  local max_age_seconds=$(( BACKUP_MAX_AGE_HOURS * 3600 ))

  if (( backup_age_seconds > max_age_seconds )); then
    local hours_ago=$(( backup_age_seconds / 3600 ))
    alert "$check_name" "Latest backup is <b>${hours_ago}h old</b> (threshold: ${BACKUP_MAX_AGE_HOURS}h)."
  else
    recover "$check_name" "Backup is recent (within ${BACKUP_MAX_AGE_HOURS}h)."
  fi
}

# =============================================================================
# Main
# =============================================================================

init_state

echo "[monitor] Running health checks at $(date -Iseconds) ..."

check_container_health
check_http_health
check_disk_usage
check_memory
check_backup_recency

echo "[monitor] Health checks complete."
