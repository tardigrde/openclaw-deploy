#!/usr/bin/env bash
# =============================================================================
# OpenClaw Doctor — Prerequisite & Configuration Health Checker
# =============================================================================
# Usage: make doctor
#        bash scripts/doctor.sh [--tools-only]
#
# Checks required tools, versions, and configuration files.
# Exit code: 0 if no errors, 1 if any errors (warnings are OK).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Counters
PASS=0
WARN=0
FAIL=0

# Options
TOOLS_ONLY=false
[[ "${1:-}" == "--tools-only" ]] && TOOLS_ONLY=true

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

pass() {
  local msg="$1"
  echo -e "  ${GREEN}[OK]${NC}    $msg"
  PASS=$((PASS + 1))
  return 0
}

warn() {
  local msg="$1"
  echo -e "  ${YELLOW}[WARN]${NC}  $msg"
  WARN=$((WARN + 1))
  return 0
}

fail() {
  local msg="$1"
  echo -e "  ${RED}[FAIL]${NC}  $msg"
  FAIL=$((FAIL + 1))
  return 0
}

# version_gte returns 0 if $1 >= $2 (semantic version comparison)
version_gte() {
  local actual="$1" required="$2"
  # If they're equal, it's >= by definition
  [[ "$actual" == "$required" ]] && return 0
  # Use sort -V: if required sorts first, then actual >= required
  local smaller
  smaller="$(printf '%s\n%s' "$actual" "$required" | sort -V | head -1)"
  [[ "$smaller" == "$required" ]]
}

# extract_version strips everything except digits and dots from a version string
extract_version() {
  local ver="$1"
  echo "$ver" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
  return 0
}

# check_tool verifies a tool exists and optionally meets a minimum version
# Usage: check_tool <cmd> [min_version] [version_cmd] [install_hint]
check_tool() {
  local cmd="$1"
  local min_version="${2:-}"
  local version_cmd="${3:-$cmd --version}"
  local install_hint="${4:-}"

  if ! command -v "$cmd" &>/dev/null; then
    local msg="$cmd — not installed"
    [[ -n "$install_hint" ]] && msg="$msg ($install_hint)"
    fail "$msg"
    return
  fi

  if [[ -z "$min_version" ]]; then
    local ver_output
    ver_output="$(eval "$version_cmd" 2>&1 | head -1 || true)"
    pass "$cmd ${DIM}${ver_output}${NC}"
    return
  fi

  local raw_version actual_version
  raw_version="$(eval "$version_cmd" 2>&1 | head -1 || true)"
  actual_version="$(extract_version "$raw_version" || true)"

  if [[ -z "$actual_version" ]]; then
    warn "$cmd — installed but could not detect version (>= $min_version required)"
    return
  fi

  if version_gte "$actual_version" "$min_version"; then
    pass "$cmd v${actual_version} ${DIM}(>= $min_version required)${NC}"
  else
    fail "$cmd v${actual_version} — too old (>= $min_version required)"
  fi
  return 0
}

# check_file verifies a file exists
check_file() {
  local path="$1" label="${2:-$1}" hint="${3:-}"

  if [[ -f "$REPO_ROOT/$path" ]]; then
    pass "$label"
  else
    local msg="$label — not found"
    [[ -n "$hint" ]] && msg="$msg ($hint)"
    fail "$msg"
  fi
  return 0
}

# check_no_placeholder verifies a file doesn't still contain placeholder values
check_no_placeholder() {
  local path="$1" label="$2" pattern="$3" hint="${4:-}"

  if [[ ! -f "$REPO_ROOT/$path" ]]; then
    return # already reported by check_file
  fi

  if grep -qE "$pattern" "$REPO_ROOT/$path" 2>/dev/null; then
    local msg="$label — still has placeholder values"
    [[ -n "$hint" ]] && msg="$msg ($hint)"
    warn "$msg"
  else
    pass "$label"
  fi
  return 0
}

# check_env_var verifies a variable is set and not empty/placeholder in a shell file.
# Uses grep to parse — never sources the file (safe against arbitrary code execution).
check_env_var() {
  local file="$1" var_name="$2"
  local label="${3:-$var_name}"

  if [[ ! -f "$REPO_ROOT/$file" ]]; then
    return # already reported by check_file
  fi

  # Match: export VAR="..." or VAR="..." or VAR=...
  local val
  val="$(grep -E "^(export )?${var_name}=" "$REPO_ROOT/$file" 2>/dev/null \
    | head -1 | sed -E "s/^(export )?${var_name}=[\"']?//;s/[\"']?$//")" || true

  if [[ -z "$val" ]]; then
    fail "$label — not set in $file"
  elif [[ "$val" =~ CHANGE_ME|your-.*-here|your_.*_here ]]; then
    warn "$label — still has placeholder value in $file"
  else
    pass "$label ${DIM}(set in $file)${NC}"
  fi
  return 0
}

# check_dotenv_var verifies a KEY=VALUE exists and is not empty in a dotenv file
check_dotenv_var() {
  local file="$1" var_name="$2"
  local label="${3:-$var_name}" required="${4:-true}"

  if [[ ! -f "$REPO_ROOT/$file" ]]; then
    return
  fi

  local val
  val="$(grep -E "^${var_name}=" "$REPO_ROOT/$file" 2>/dev/null | head -1 | cut -d= -f2-)" || true

  if [[ -z "$val" ]]; then
    if [[ "$required" == "true" ]]; then
      fail "$label — not set in $file"
    else
      pass "$label ${DIM}(optional, not set)${NC}"
    fi
  else
    pass "$label ${DIM}(set in $file)${NC}"
  fi
  return 0
}

# check_encrypted_dotenv_var verifies a KEY=VALUE in a SOPS-encrypted dotenv file.
# Falls back to plaintext .env if the encrypted file is missing or decryption fails.
check_encrypted_dotenv_var() {
  local var_name="$1"
  local label="${2:-$var_name}" required="${3:-true}"
  local enc_file="$REPO_ROOT/secrets/.env.enc"
  local plain_file="$REPO_ROOT/secrets/.env"
  local age_key="$REPO_ROOT/secrets/age-key.txt"

  local val="" source=""

  # Try decrypting from .env.enc (requires age key)
  if [[ -f "$enc_file" ]] && [[ -f "$age_key" ]] && command -v sops &>/dev/null; then
    val="$(SOPS_AGE_KEY_FILE="$age_key" sops --decrypt --input-type dotenv --output-type dotenv "$enc_file" 2>/dev/null \
      | grep -E "^${var_name}=" | head -1 | cut -d= -f2-)" || true
    [[ -n "$val" ]] && source="secrets/.env.enc"
  fi

  # Fallback to plaintext .env
  if [[ -z "$val" && -f "$plain_file" ]]; then
    val="$(grep -E "^${var_name}=" "$plain_file" 2>/dev/null | head -1 | cut -d= -f2-)" || true
    [[ -n "$val" ]] && source="secrets/.env"
  fi

  if [[ -z "$val" ]]; then
    if [[ "$required" == "true" ]]; then
      fail "$label — not set in secrets/.env.enc"
    else
      pass "$label ${DIM}(optional, not set)${NC}"
    fi
  else
    pass "$label ${DIM}(set in $source)${NC}"
  fi
  return 0
}

# =============================================================================
# Main
# =============================================================================

echo ""
echo -e "${BOLD}OpenClaw Doctor${NC}"
echo "==============="
echo ""

# ---- Tool Checks ----
echo -e "${BOLD}Checking required tools...${NC}"
echo ""

check_tool "terraform" "1.7" "terraform version" \
  "https://developer.hashicorp.com/terraform/install"

check_tool "ansible-playbook" "2.15" "ansible-playbook --version" \
  "pip install ansible-core"

check_tool "age" "" "age --version" \
  "https://github.com/FiloSottile/age#installation"

check_tool "sops" "3.7" "sops --version" \
  "https://github.com/getsops/sops#install"

check_tool "jq" "" "jq --version" \
  "https://jqlang.github.io/jq/download/"

check_tool "shellcheck" "0.7" "shellcheck --version | grep 'version:'" \
  "https://github.com/koalaman/shellcheck#installing"

check_tool "ssh" "" "ssh -V 2>&1" ""
check_tool "ssh-keygen" "" "ssh-keygen -V 2>&1 || echo 'available'" ""

echo ""

if $TOOLS_ONLY; then
  echo -e "${BOLD}Summary:${NC} ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL errors${NC}"
  echo ""
  [[ $FAIL -gt 0 ]] && exit 1
  exit 0
fi

# ---- Configuration File Checks ----
echo -e "${BOLD}Checking configuration files...${NC}"
echo ""

check_file "secrets/inputs.sh" \
  "secrets/inputs.sh" \
  "cp secrets/inputs.example.sh secrets/inputs.sh"

check_file "secrets/age-key.txt" \
  "secrets/age-key.txt" \
  "make secrets-generate-key"

check_file "secrets/.env.enc" \
  "secrets/.env.enc" \
  "make secrets-encrypt"

check_file "openclaw.json" \
  "openclaw.json" \
  "cp openclaw.example.json openclaw.json"

check_file "terraform/envs/prod/terraform.tfvars" \
  "terraform/envs/prod/terraform.tfvars" \
  "cp terraform/envs/prod/terraform.tfvars.example terraform/envs/prod/terraform.tfvars"

check_file "terraform/envs/prod/backend.tf" \
  "terraform/envs/prod/backend.tf" \
  "cp terraform/envs/prod/backend.tf.example terraform/envs/prod/backend.tf"

# Check .sops.yaml has a real age key (not null)
if [[ -f "$REPO_ROOT/.sops.yaml" ]]; then
  if grep -q 'age: null' "$REPO_ROOT/.sops.yaml"; then
    warn ".sops.yaml — age key is still null (run make secrets-generate-key, then update .sops.yaml)"
  else
    pass ".sops.yaml ${DIM}(age key configured)${NC}"
  fi
fi

# Check openclaw.json for placeholders
check_no_placeholder "openclaw.json" \
  "openclaw.json ${DIM}(no placeholders)${NC}" \
  '<your-' \
  "replace <your-...> placeholders with real values"

# Validate openclaw.json is valid JSON
if [[ -f "$REPO_ROOT/openclaw.json" ]] && command -v jq &>/dev/null; then
  if jq . "$REPO_ROOT/openclaw.json" > /dev/null 2>&1; then
    pass "openclaw.json ${DIM}(valid JSON)${NC}"
  else
    fail "openclaw.json — invalid JSON syntax"
  fi
fi

echo ""

# ---- Secrets Checks ----
echo -e "${BOLD}Checking secrets...${NC}"
echo ""

INPUTS_FILE="secrets/inputs.sh"
check_env_var "$INPUTS_FILE" "HCLOUD_TOKEN" "HCLOUD_TOKEN"
check_env_var "$INPUTS_FILE" "TF_VAR_ssh_key_fingerprint" "SSH_KEY_FINGERPRINT"

check_encrypted_dotenv_var "TELEGRAM_BOT_TOKEN" "TELEGRAM_BOT_TOKEN"
check_encrypted_dotenv_var "OPENCLAW_GATEWAY_TOKEN" "OPENCLAW_GATEWAY_TOKEN"
check_encrypted_dotenv_var "ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY" "false"

echo ""

# ---- Summary ----
echo "─────────────────────────────────────────"
echo -e "${BOLD}Summary:${NC} ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN warnings${NC}, ${RED}$FAIL errors${NC}"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo -e "${RED}Fix the errors above before proceeding.${NC}"
  echo -e "Run ${BOLD}make setup${NC} for interactive guided configuration."
  echo ""
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo ""
  echo -e "${YELLOW}Warnings found — review above before deploying.${NC}"
  echo ""
  exit 0
else
  echo ""
  echo -e "${GREEN}Everything looks good!${NC} Ready for: make init && make plan && make apply"
  echo ""
  exit 0
fi
