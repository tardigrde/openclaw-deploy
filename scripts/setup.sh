#!/usr/bin/env bash
# =============================================================================
# OpenClaw Setup Wizard — Interactive First-Time Configuration
# =============================================================================
# Usage: make setup
#        bash scripts/setup.sh
#
# Walks through copying example files, prompting for required values,
# generating keys, and encrypting secrets. Idempotent — safe to re-run.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Track what we did
STEPS_DONE=0

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

info()  { local msg="$1"; echo -e "${GREEN}[INFO]${NC}  $msg"; return 0; }
step()  { local msg="$1"; echo -e "${BLUE}[STEP]${NC}  ${BOLD}$msg${NC}"; return 0; }
skip()  { local msg="$1"; echo -e "${DIM}        $msg — already exists, skipping${NC}"; return 0; }
done_msg() { echo -e "  ${GREEN}Done.${NC}"; return 0; }

# prompt_value asks for a value with an optional default.
# Usage: prompt_value "Enter token" "default_val" result_var
prompt_value() {
  local prompt_text="$1"
  local default="$2"
  local var_name="$3"

  if [[ -n "$default" && ! "$default" =~ CHANGE_ME ]]; then
    echo -en "  ${prompt_text} [${DIM}${default}${NC}]: "
    read -r input
    printf -v "$var_name" '%s' "${input:-$default}"
  else
    echo -en "  ${prompt_text}: "
    read -r input
    printf -v "$var_name" '%s' "${input}"
  fi
  return 0
}

# prompt_yn asks a yes/no question. Returns 0 for yes, 1 for no.
prompt_yn() {
  local prompt_text="$1" default="${2:-n}"
  local yn_hint
  if [[ "$default" == "y" ]]; then yn_hint="[Y/n]"; else yn_hint="[y/N]"; fi

  echo -en "  ${prompt_text} ${yn_hint}: "
  read -r input
  input="${input:-$default}"
  [[ "$input" =~ ^[Yy] ]]
  local result=$?
  return $result
}

# copy_example copies an example file if the target doesn't exist
copy_example() {
  local src="$1" dest="$2"
  local label="${3:-$dest}"

  if [[ -f "$REPO_ROOT/$dest" ]]; then
    skip "$label"
    return 1
  fi

  cp "$REPO_ROOT/$src" "$REPO_ROOT/$dest"
  info "Created $label"
  return 0
}

# sed_replace replaces a pattern in a file (portable for both GNU and BSD sed).
# Escapes \, &, and | in the replacement string so tokens with special chars are safe.
sed_replace() {
  local file="$1" pattern="$2" replacement="$3"
  # Escape sed replacement special chars: \ → \\, & → \&, | → \| (for | delimiter)
  local escaped
  escaped="${replacement//\\/\\\\}"
  escaped="${escaped//&/\\&}"
  escaped="${escaped//|/\\|}"
  if sed --version &>/dev/null 2>&1; then
    sed -i "s|${pattern}|${escaped}|g" "$file"
  else
    sed -i '' "s|${pattern}|${escaped}|g" "$file"
  fi
  return 0
}

# get_current_value extracts a variable's current value from a shell file.
# Uses grep to parse — never sources the file (safe against arbitrary code execution).
get_current_value() {
  local file="$1" var="$2"
  grep -E "^(export )?${var}=" "$file" 2>/dev/null \
    | head -1 | sed -E "s/^(export )?${var}=[\"']?//;s/[\"']?$//" || true
  return 0
}

# get_dotenv_value extracts a KEY=VALUE from a dotenv file
get_dotenv_value() {
  local file="$1" key="$2"
  grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- || true
  return 0
}

# set_dotenv_value sets a KEY=VALUE in a dotenv file
set_dotenv_value() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    sed_replace "$file" "^${key}=.*" "${key}=${value}"
  else
    echo "${key}=${value}" >> "$file"
  fi
  return 0
}

# =============================================================================
# Main
# =============================================================================

echo ""
echo -e "${BOLD}OpenClaw Setup Wizard${NC}"
echo "====================="
echo ""
echo "This wizard will walk you through first-time configuration."
echo "It creates config files, prompts for required values, and generates keys."
echo -e "${DIM}(Press Ctrl+C at any time to abort — your files are saved as you go.)${NC}"
echo ""

# ---- Step 1: Prerequisite Check ----
step "1/9  Checking prerequisites..."
echo ""

if [[ -f "$REPO_ROOT/scripts/doctor.sh" ]]; then
  if ! bash "$REPO_ROOT/scripts/doctor.sh" --tools-only; then
    echo ""
    echo -e "${RED}Install the missing tools above, then re-run: make setup${NC}"
    exit 1
  fi
else
  info "doctor.sh not found — skipping tool checks"
fi

echo ""

# ---- Step 2: Copy Example Files ----
step "2/9  Copying example configuration files..."
echo ""

copy_example "secrets/inputs.example.sh" "secrets/inputs.sh" "secrets/inputs.sh" && STEPS_DONE=$((STEPS_DONE + 1)) || true
if [[ -f "$REPO_ROOT/secrets/.env.enc" ]]; then
  skip "secrets/.env.enc"
  STEPS_DONE=$((STEPS_DONE + 1))
else
  copy_example "secrets/.env.example" "secrets/.env" "secrets/.env" && STEPS_DONE=$((STEPS_DONE + 1)) || true
fi
copy_example "openclaw.example.json" "openclaw.json" "openclaw.json" && STEPS_DONE=$((STEPS_DONE + 1)) || true
copy_example "terraform/envs/prod/terraform.tfvars.example" \
  "terraform/envs/prod/terraform.tfvars" "terraform.tfvars" && STEPS_DONE=$((STEPS_DONE + 1)) || true
copy_example "terraform/envs/prod/backend.tf.example" \
  "terraform/envs/prod/backend.tf" "backend.tf" && STEPS_DONE=$((STEPS_DONE + 1)) || true

echo ""

# ---- Step 3: Hetzner Cloud Token ----
step "3/9  Hetzner Cloud API Token"
echo ""
echo -e "  ${DIM}Get yours at: https://console.hetzner.cloud/ -> Project -> API Tokens${NC}"

INPUTS_FILE="$REPO_ROOT/secrets/inputs.sh"
current_token="$(get_current_value "$INPUTS_FILE" HCLOUD_TOKEN)"

if [[ -n "$current_token" && ! "$current_token" =~ CHANGE_ME ]]; then
  masked="${current_token:0:8}...${current_token: -4}"
  echo -e "  Current token: ${DIM}${masked}${NC}"
  if ! prompt_yn "Change it?"; then
    echo ""
    skip "Keeping existing Hetzner token"
    HCLOUD_TOKEN="$current_token"
  else
    prompt_value "Hetzner API token" "" "HCLOUD_TOKEN"
  fi
else
  prompt_value "Hetzner API token" "" "HCLOUD_TOKEN"
fi

if [[ -n "${HCLOUD_TOKEN:-}" ]]; then
  sed_replace "$INPUTS_FILE" 'CHANGE_ME_your-hcloud-token-here' "$HCLOUD_TOKEN"
  # Also handle case where the user already replaced the placeholder but wants to update
  sed_replace "$INPUTS_FILE" "^export HCLOUD_TOKEN=.*" "export HCLOUD_TOKEN=\"${HCLOUD_TOKEN}\""
  sed_replace "$INPUTS_FILE" "^export TF_VAR_hcloud_token=.*" 'export TF_VAR_hcloud_token="$HCLOUD_TOKEN"'
  STEPS_DONE=$((STEPS_DONE + 1))
fi

echo ""

# ---- Step 4: SSH Key Fingerprint ----
step "4/9  SSH Key Fingerprint"
echo ""

current_fp="$(get_current_value "$INPUTS_FILE" TF_VAR_ssh_key_fingerprint)"
SSH_FP=""

if [[ -n "$current_fp" && ! "$current_fp" =~ CHANGE_ME ]]; then
  echo -e "  Current fingerprint: ${DIM}${current_fp}${NC}"
  if ! prompt_yn "Change it?"; then
    SSH_FP="$current_fp"
    skip "Keeping existing SSH key fingerprint"
  fi
fi

if [[ -z "$SSH_FP" ]]; then
  # Try auto-detect from Hetzner API
  if [[ -n "${HCLOUD_TOKEN:-}" ]] && command -v curl &>/dev/null && command -v jq &>/dev/null; then
    echo -e "  ${DIM}Querying Hetzner API for your SSH keys...${NC}"
    API_RESPONSE="$(curl -sf -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
      https://api.hetzner.cloud/v1/ssh_keys 2>/dev/null)" || true

    if [[ -n "$API_RESPONSE" ]]; then
      KEY_COUNT="$(echo "$API_RESPONSE" | jq '.ssh_keys | length' 2>/dev/null)" || KEY_COUNT=0
      if [[ "$KEY_COUNT" -gt 0 ]]; then
        echo ""
        echo "  Available SSH keys:"
        echo "$API_RESPONSE" | jq -r '.ssh_keys[] | "    \(.name)  \(.fingerprint)"' 2>/dev/null
        echo ""

        if [[ "$KEY_COUNT" -eq 1 ]]; then
          SSH_FP="$(echo "$API_RESPONSE" | jq -r '.ssh_keys[0].fingerprint')"
          echo -e "  ${GREEN}Auto-selected:${NC} $SSH_FP (only key available)"
        else
          prompt_value "Paste the fingerprint from above" "" "SSH_FP"
        fi
      else
        echo -e "  ${YELLOW}No SSH keys found in Hetzner.${NC} Upload one first at console.hetzner.cloud"
        prompt_value "SSH key fingerprint" "" "SSH_FP"
      fi
    else
      echo -e "  ${YELLOW}Could not reach Hetzner API.${NC}"
      prompt_value "SSH key fingerprint (from Hetzner console)" "" "SSH_FP"
    fi
  else
    prompt_value "SSH key fingerprint (from Hetzner console)" "" "SSH_FP"
  fi
fi

if [[ -n "${SSH_FP:-}" ]]; then
  sed_replace "$INPUTS_FILE" 'CHANGE_ME_your-ssh-key-fingerprint' "$SSH_FP"
  sed_replace "$INPUTS_FILE" \
    "^export TF_VAR_ssh_key_fingerprint=.*" \
    "export TF_VAR_ssh_key_fingerprint=\"${SSH_FP}\""
  STEPS_DONE=$((STEPS_DONE + 1))
fi

echo ""

# ---- Decrypt existing .env.enc if .env is missing ----
if [[ ! -f "$DOTENV_FILE" && -f "$REPO_ROOT/secrets/.env.enc" && -f "$REPO_ROOT/secrets/age-key.txt" ]] && command -v sops &>/dev/null; then
    info "Decrypting secrets/.env.enc -> secrets/.env ..."
    SOPS_AGE_KEY_FILE="$REPO_ROOT/secrets/age-key.txt" sops --decrypt \
      --input-type dotenv --output-type dotenv \
      "$REPO_ROOT/secrets/.env.enc" > "$DOTENV_FILE"
fi

# ---- Step 5: Telegram Bot Token ----
step "5/9  Telegram Bot Token"
echo ""
echo -e "  ${DIM}Create a bot: open Telegram, message @BotFather, send /newbot${NC}"

DOTENV_FILE="$REPO_ROOT/secrets/.env"
current_bot_token="$(get_dotenv_value "$DOTENV_FILE" TELEGRAM_BOT_TOKEN)"

if [[ -n "$current_bot_token" ]]; then
  masked="${current_bot_token:0:8}..."
  echo -e "  Current token: ${DIM}${masked}${NC}"
  if ! prompt_yn "Change it?"; then
    skip "Keeping existing Telegram bot token"
    BOT_TOKEN="$current_bot_token"
  else
    prompt_value "Telegram bot token" "" "BOT_TOKEN"
  fi
else
  prompt_value "Telegram bot token" "" "BOT_TOKEN"
fi

if [[ -n "${BOT_TOKEN:-}" ]]; then
  set_dotenv_value "$DOTENV_FILE" "TELEGRAM_BOT_TOKEN" "$BOT_TOKEN"
  STEPS_DONE=$((STEPS_DONE + 1))
fi

echo ""

# ---- Step 6: Gateway Token (auto-generated) ----
step "6/9  Gateway Token"
echo ""

current_gw_token="$(get_dotenv_value "$DOTENV_FILE" OPENCLAW_GATEWAY_TOKEN)"

if [[ -n "$current_gw_token" ]]; then
  echo -e "  ${DIM}Gateway token already set — keeping existing.${NC}"
else
  GW_TOKEN="$(openssl rand -hex 32)"
  set_dotenv_value "$DOTENV_FILE" "OPENCLAW_GATEWAY_TOKEN" "$GW_TOKEN"
  info "Generated gateway token (saved to secrets/.env)"
  STEPS_DONE=$((STEPS_DONE + 1))
fi

echo ""

# ---- Step 7: Telegram User ID ----
step "7/9  Telegram User ID"
echo ""
echo -e "  ${DIM}To find your ID: message @userinfobot on Telegram, or send a message${NC}"
echo -e "  ${DIM}to your bot and visit: https://api.telegram.org/bot<TOKEN>/getUpdates${NC}"

CONFIG_FILE="$REPO_ROOT/openclaw.json"
TELEGRAM_ID=""

if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
  current_id="$(jq -r '.channels.telegram.allowFrom[0] // ""' "$CONFIG_FILE" 2>/dev/null)" || true
  if [[ -n "$current_id" && "$current_id" != "<your-telegram-user-id>" ]]; then
    echo -e "  Current user ID: ${DIM}${current_id}${NC}"
    if ! prompt_yn "Change it?"; then
      skip "Keeping existing Telegram user ID"
      TELEGRAM_ID="$current_id"
    fi
  fi
fi

if [[ -z "$TELEGRAM_ID" ]]; then
  prompt_value "Your Telegram numeric user ID" "" "TELEGRAM_ID"
fi

if [[ -n "${TELEGRAM_ID:-}" && -f "$CONFIG_FILE" ]]; then
  # Replace all placeholder instances in openclaw.json
  sed_replace "$CONFIG_FILE" '<your-telegram-user-id>' "$TELEGRAM_ID"
  STEPS_DONE=$((STEPS_DONE + 1))
fi

echo ""

# ---- Step 8: Age Key + SOPS Encryption ----
step "8/9  Secrets Encryption (SOPS + age)"
echo ""

AGE_KEY_FILE="$REPO_ROOT/secrets/age-key.txt"
SOPS_YAML="$REPO_ROOT/.sops.yaml"

if [[ -f "$AGE_KEY_FILE" ]]; then
  info "Age key already exists at secrets/age-key.txt"
else
  if command -v age-keygen &>/dev/null; then
    age-keygen -o "$AGE_KEY_FILE" 2>&1
    info "Generated age key"
    STEPS_DONE=$((STEPS_DONE + 1))
  else
    echo -e "  ${RED}age-keygen not found — install age first${NC}"
  fi
fi

# Update .sops.yaml with the public key
if [[ -f "$AGE_KEY_FILE" && -f "$SOPS_YAML" ]]; then
  if grep -q 'age: null' "$SOPS_YAML"; then
    if command -v age-keygen &>/dev/null; then
      AGE_PUBLIC_KEY="$(age-keygen -y "$AGE_KEY_FILE" 2>/dev/null)" || true
      if [[ -n "$AGE_PUBLIC_KEY" ]]; then
        sed_replace "$SOPS_YAML" "age: null" "age: $AGE_PUBLIC_KEY"
        info "Updated .sops.yaml with age public key"
      fi
    fi
  else
    echo -e "  ${DIM}.sops.yaml already has an age key configured${NC}"
  fi
fi

# Encrypt .env if .env exists and .env.enc is outdated or missing
if [[ -f "$DOTENV_FILE" && -f "$AGE_KEY_FILE" ]]; then
  if command -v sops &>/dev/null && command -v age-keygen &>/dev/null; then
    if ! grep -q 'age: null' "$SOPS_YAML" 2>/dev/null; then
      echo ""
      info "Encrypting secrets/.env -> secrets/.env.enc ..."
      AGE_PUB="$(age-keygen -y "$AGE_KEY_FILE")"
      SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops --encrypt \
        --input-type dotenv --age "$AGE_PUB" \
        "$DOTENV_FILE" > "$REPO_ROOT/secrets/.env.enc"
      info "Encrypted! secrets/.env.enc is safe to commit."
      STEPS_DONE=$((STEPS_DONE + 1))
    fi
  else
    echo -e "  ${YELLOW}sops or age-keygen not found — skipping encryption.${NC}"
    echo -e "  ${DIM}Run 'make secrets-encrypt' later to encrypt your secrets.${NC}"
  fi
fi

echo ""

# ---- Step 9: Optional — Tailscale ----
step "9/9  Tailscale VPN (optional)"
echo ""
echo -e "  ${DIM}Tailscale provides secure private networking — no public SSH needed.${NC}"

if prompt_yn "Enable Tailscale?" "n"; then
  echo ""
  echo -e "  ${DIM}Create OAuth client at: https://login.tailscale.com/admin/settings/oauth${NC}"
  echo -e "  ${DIM}Required scope: auth_keys:write${NC}"
  echo ""

  prompt_value "Tailscale OAuth client ID" "" "TS_CLIENT_ID"
  prompt_value "Tailscale OAuth client secret" "" "TS_CLIENT_SECRET"

  if [[ -n "${TS_CLIENT_ID:-}" && -n "${TS_CLIENT_SECRET:-}" ]]; then
    sed_replace "$INPUTS_FILE" \
      "^export TF_VAR_enable_tailscale=.*" \
      "export TF_VAR_enable_tailscale=true"
    sed_replace "$INPUTS_FILE" \
      'CHANGE_ME_tskey-client-...' "$TS_CLIENT_ID"
    sed_replace "$INPUTS_FILE" \
      'CHANGE_ME_tskey-secret-...' "$TS_CLIENT_SECRET"
    sed_replace "$INPUTS_FILE" \
      "^export TF_VAR_tailscale_oauth_client_id=.*" \
      "export TF_VAR_tailscale_oauth_client_id=\"${TS_CLIENT_ID}\""
    sed_replace "$INPUTS_FILE" \
      "^export TF_VAR_tailscale_oauth_client_secret=.*" \
      "export TF_VAR_tailscale_oauth_client_secret=\"${TS_CLIENT_SECRET}\""
    info "Tailscale enabled in secrets/inputs.sh"
    STEPS_DONE=$((STEPS_DONE + 1))
  fi
else
  skip "Tailscale — skipped"
fi

echo ""

# ---- Summary ----
echo "============================================="
echo -e "${BOLD}Setup Complete!${NC} ($STEPS_DONE changes made)"
echo "============================================="
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "  1. Review your config files:"
echo -e "     ${DIM}secrets/inputs.sh    — infrastructure credentials${NC}"
echo -e "     ${DIM}secrets/.env         — application secrets${NC}"
echo -e "     ${DIM}openclaw.json        — OpenClaw configuration${NC}"
echo ""
echo "  2. Source your environment:"
echo -e "     ${GREEN}source secrets/inputs.sh${NC}"
echo ""
echo "  3. Provision and deploy:"
echo -e "     ${GREEN}make init${NC}            # initialize Terraform"
echo -e "     ${GREEN}make plan${NC}            # preview infrastructure changes"
echo -e "     ${GREEN}make apply${NC}           # create VPS + firewall"
echo -e "     ${GREEN}make bootstrap${NC}       # deploy OpenClaw to VPS"
echo ""
echo "  4. Verify everything works:"
echo -e "     ${GREEN}make doctor${NC}          # check configuration health"
echo -e "     ${GREEN}make status${NC}          # check VPS status"
echo ""
