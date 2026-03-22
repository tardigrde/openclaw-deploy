# =============================================================================
# OpenClaw Infrastructure Makefile
# =============================================================================
# Usage: make <target> [ENV=prod]

SHELL := /bin/bash
.PHONY: init plan apply destroy ssh ssh-root tunnel output ip fmt validate clean help \
        bootstrap bootstrap-check deploy deploy-check setup-auth backup-now backup-pull restore logs status shell exec \
        tailscale-enable tailscale-setup tailscale-status tailscale-ip tailscale-up \
        workspace-sync \
        secrets-generate-key secrets-encrypt secrets-decrypt secrets-edit

-include Makefile.local

# Default target
.DEFAULT_GOAL := help

# Default values
ENV ?= prod
TERRAFORM_DIR := terraform/envs/$(ENV)

# Auto-source secrets (if exists)
-include secrets/inputs.sh

# Re-export TF vars via bash subshell — Make misparses quoted shell values (e.g. "token" → literal quotes)
export TF_VAR_hcloud_token        := $(shell bash -c 'source secrets/inputs.sh 2>/dev/null && echo "$$HCLOUD_TOKEN"')
export TF_VAR_ssh_key_fingerprint := $(shell bash -c 'source secrets/inputs.sh 2>/dev/null && echo "$$SSH_KEY_FINGERPRINT"')

# Tailscale OAuth credentials — the Tailscale Terraform provider ignores TF_VAR_* env vars and
# reads TAILSCALE_OAUTH_CLIENT_ID/SECRET directly, which may conflict when a separate OAuth client
# is set for other purposes (e.g. CI). Pass credentials explicitly via -var to bypass this.
# Only added when the values are non-empty (i.e. Tailscale is configured in secrets/inputs.sh).
_TAILSCALE_OAUTH_ID     := $(shell bash -c 'source secrets/inputs.sh 2>/dev/null && echo "$$TF_VAR_tailscale_oauth_client_id"')
_TAILSCALE_OAUTH_SECRET := $(shell bash -c 'source secrets/inputs.sh 2>/dev/null && echo "$$TF_VAR_tailscale_oauth_client_secret"')
TAILSCALE_TF_VARS       := $(if $(_TAILSCALE_OAUTH_ID),-var="tailscale_oauth_client_id=$(_TAILSCALE_OAUTH_ID)" -var="tailscale_oauth_client_secret=$(_TAILSCALE_OAUTH_SECRET)")

# Auto-read Tailscale auth key from Terraform output when not set in the environment.
# This means after `make apply`, bootstrap/tailscale-enable work with no extra steps.
# To override (e.g. use an existing key): export TAILSCALE_AUTH_KEY=tskey-... before running make.
TAILSCALE_AUTH_KEY ?= $(shell cd $(TERRAFORM_DIR) && terraform output -raw tailscale_auth_key 2>/dev/null)

# Server IP - read from secrets or Terraform state
# Note: If using Tailscale, set SERVER_IP="openclaw-prod" in secrets/inputs.sh.
SERVER_IP ?= $(shell cd $(TERRAFORM_DIR) && terraform output -raw server_ip 2>/dev/null)
SSH_KEY ?= ~/.ssh/id_rsa

# Ansible
ANSIBLE_CONFIG := ansible/ansible.cfg
PLAYBOOK := $(shell [ -f ansible/site.local.yml ] && echo ansible/site.local.yml || echo ansible/site.yml)
ANSIBLE := ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-playbook -i "$(SERVER_IP)," --private-key $(SSH_KEY)

# Deploy tags: default config+start, set REBUILD=1 to add docker rebuild
DEPLOY_TAGS := config,start
ifdef REBUILD
DEPLOY_TAGS := docker,config,start
endif

# Guard: fail fast with a clear message if SERVER_IP is empty
# Used by all SSH/Ansible targets. $(call check-server-ip) at the start of a recipe.
define check-server-ip
@if [[ -z "$(SERVER_IP)" ]]; then \
	echo -e "$(RED)[ERROR]$(NC) SERVER_IP is not set and could not be auto-detected from Terraform state."; \
	echo "  → Option 1: provision the VPS first: make apply"; \
	echo "  → Option 2: set SERVER_IP in secrets/inputs.sh and run: source secrets/inputs.sh"; \
	exit 1; \
fi
endef

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
BLUE   := \033[0;34m
BOLD   := \033[1m
NC     := \033[0m

# =============================================================================
# Terraform Commands
# =============================================================================

init: ## Initialize Terraform backend
	@echo -e "$(GREEN)[INFO]$(NC) Initializing Terraform for $(ENV)..."
	@cd $(TERRAFORM_DIR) && terraform init

plan: ## Preview Terraform changes
	@echo -e "$(GREEN)[INFO]$(NC) Planning Terraform changes for $(ENV)..."
	@cd $(TERRAFORM_DIR) && terraform plan $(TAILSCALE_TF_VARS)

apply: ## Apply Terraform changes
	@echo -e "$(YELLOW)[WARN]$(NC) This will modify infrastructure for $(ENV)"
	@cd $(TERRAFORM_DIR) && terraform apply $(TAILSCALE_TF_VARS)

destroy: ## Destroy all managed infrastructure
	@echo -e "$(RED)[DANGER]$(NC) This will DESTROY all infrastructure for $(ENV)!"
	@cd $(TERRAFORM_DIR) && terraform destroy

fmt: ## Format Terraform files
	@echo -e "$(GREEN)[INFO]$(NC) Formatting Terraform files..."
	@terraform fmt -recursive terraform/

output: ## Show all Terraform outputs
	@cd $(TERRAFORM_DIR) && terraform output

# =============================================================================
# Utility Commands
# =============================================================================

ssh: ## SSH into the server as the openclaw user
	$(call check-server-ip)
	@echo -e "$(GREEN)[INFO]$(NC) Connecting to $(SERVER_IP)..."
	ssh -i $(SSH_KEY) openclaw@$(SERVER_IP)

# ssh-root is intentionally disabled: root login is blocked by sshd (cloud-init) and
# any failed attempt counts toward fail2ban (maxretry=3, bantime=1h).
# Use the Hetzner web console for emergency root access instead.
# ssh-root: ## SSH into the server as root
# 	@echo -e "$(YELLOW)[WARN]$(NC) Connecting as root to $(SERVER_IP)..."
# 	ssh -i $(SSH_KEY) root@$(SERVER_IP)

tunnel: ## Open SSH tunnel to OpenClaw gateway (localhost:18789)
	$(call check-server-ip)
	@echo -e "$(GREEN)[INFO]$(NC) Opening tunnel to $(SERVER_IP):18789..."
	@echo -e "  Gateway available at $(BOLD)http://localhost:18789$(NC)"
	@echo -e "  $(BOLD)Ctrl+C$(NC) to close"
	@echo ""
	@ssh -i $(SSH_KEY) -N -L 18789:127.0.0.1:18789 openclaw@$(SERVER_IP)


ip: ## Show server IP address
	@cd $(TERRAFORM_DIR) && terraform output -raw server_ip

clean: ## Clean up Terraform files (keeps state)
	rm -rf $(TERRAFORM_DIR)/.terraform/
	rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl

validate: ## Validate Terraform configuration, shell scripts, and config
	@echo -e "$(GREEN)[INFO]$(NC) Validating Terraform..."
	@terraform fmt -check -recursive terraform/
	@cd $(TERRAFORM_DIR) && terraform init -backend=false -input=false > /dev/null 2>&1 && terraform validate
	@echo ""
	@echo -e "$(GREEN)[INFO]$(NC) Running ShellCheck..."
	@shellcheck --severity=warning scripts/*.sh scripts/lib/*.sh scripts/local.example/*.sh
	@if ls scripts/local/*.sh >/dev/null 2>&1; then shellcheck --severity=warning scripts/local/*.sh; fi
	@echo ""
	@echo -e "$(GREEN)[INFO]$(NC) Validating config..."
	@bash scripts/validate.sh
	@echo ""
	@echo -e "$(GREEN)[INFO]$(NC) Validating Ansible playbook..."
	@ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-playbook --syntax-check -i localhost, $(PLAYBOOK)
	@echo ""
	@echo -e "$(GREEN)All validations passed!$(NC)"

# =============================================================================
# Deploy Commands
# =============================================================================

bootstrap: ## First-time VPS setup: dirs, Tailscale, docker build, config push, start
	$(call check-server-ip)
	@echo -e "$(BLUE)[DEPLOY]$(NC) Bootstrapping OpenClaw on VPS..."
	@$(ANSIBLE) $(PLAYBOOK) --extra-vars "tailscale_auth_key=$${TAILSCALE_AUTH_KEY:-}"

bootstrap-check: ## Dry-run of bootstrap (--check --diff), shows what would change
	$(call check-server-ip)
	@echo -e "$(BLUE)[CHECK]$(NC) Dry-run bootstrap on VPS (check + diff)..."
	@$(ANSIBLE) $(PLAYBOOK) --check --diff --extra-vars "tailscale_auth_key=$${TAILSCALE_AUTH_KEY:-}"

deploy: ## Push config/env to VPS and restart containers (REBUILD=1 to also rebuild Docker images)
	$(call check-server-ip)
	@echo -e "$(BLUE)[DEPLOY]$(NC) Deploying to VPS (tags: $(DEPLOY_TAGS))..."
	@$(ANSIBLE) $(PLAYBOOK) --tags $(DEPLOY_TAGS)

deploy-check: ## Dry-run of deploy (--check --diff), shows what would change (REBUILD=1 to include docker)
	$(call check-server-ip)
	@echo -e "$(BLUE)[CHECK]$(NC) Dry-run deploy on VPS (tags: $(DEPLOY_TAGS), check + diff)..."
	@$(ANSIBLE) $(PLAYBOOK) --tags $(DEPLOY_TAGS) --check --diff

setup-auth: ## Set up Claude subscription auth on the VPS
	$(call check-server-ip)
	@echo -e "$(BLUE)[AUTH]$(NC) Setting up Claude subscription auth..."
	@$(ANSIBLE) $(PLAYBOOK) --tags setup_auth

backup-now: ## Run backup now on the VPS
	$(call check-server-ip)
	@echo -e "$(GREEN)[INFO]$(NC) Running backup on $(SERVER_IP)..."
	@$(ANSIBLE) $(PLAYBOOK) --tags backup_now

backup-pull: ## Download the latest backup from VPS to ./backups/ locally
	$(call check-server-ip)
	@echo -e "$(GREEN)[INFO]$(NC) Downloading latest backup from $(SERVER_IP)..."
	@$(ANSIBLE) $(PLAYBOOK) --tags backup_pull

restore: ## List available backups (dry-run). EXECUTE=1 BACKUP=filename to actually restore.
	$(call check-server-ip)
	@echo -e "$(GREEN)[INFO]$(NC) Restore target on $(SERVER_IP)..."
ifdef EXECUTE
	@if [ -z "$(BACKUP)" ]; then \
		echo -e "$(RED)[ERROR]$(NC) BACKUP variable required when EXECUTE=1"; \
		echo "Usage: make restore EXECUTE=1 BACKUP=<filename>"; \
		exit 1; \
	fi
	@$(ANSIBLE) $(PLAYBOOK) --tags restore --extra-vars '{"execute":true,"backup_file":"$(BACKUP)"}'
else
	@$(ANSIBLE) $(PLAYBOOK) --tags restore
endif

logs: ## Stream Docker logs from the VPS
	$(call check-server-ip)
	@echo -e "$(GREEN)[INFO]$(NC) Streaming logs from $(SERVER_IP)..."
	@echo "Press Ctrl+C to exit"
	@ssh -i $(SSH_KEY) -o StrictHostKeyChecking=accept-new openclaw@$(SERVER_IP) \
		'docker logs -f --tail 100 $$(docker ps -q -f label=com.docker.compose.service=openclaw-gateway)'

status: ## Check OpenClaw status on the VPS (includes Tailscale if enabled)
	$(call check-server-ip)
	@echo -e "$(GREEN)[INFO]$(NC) Checking VPS status..."
	@./scripts/status.sh $(SERVER_IP)

workspace-sync: ## Sync workspace to GitHub now
	@echo -e "$(GREEN)[INFO]$(NC) Syncing workspace on $(SERVER_IP)..."
	ssh -i $(SSH_KEY) -o StrictHostKeyChecking=accept-new openclaw@$(SERVER_IP) \
		'~/openclaw/workspace-sync.sh'


shell: ## Open interactive shell in OpenClaw container
	@echo -e "$(GREEN)[INFO]$(NC) Opening shell in container on $(SERVER_IP)..."
	@ssh -i $(SSH_KEY) -t openclaw@$(SERVER_IP) \
		'docker exec -it $$(docker ps -q -f label=com.docker.compose.service=openclaw-gateway) /bin/bash'

exec: ## Execute command in OpenClaw container (use CMD="command")
ifndef CMD
	@echo -e "$(RED)[ERROR]$(NC) CMD variable required"
	@echo "Usage: make exec CMD=\"openclaw --version\""
	@echo "   or: make exec CMD=\"ls -la /app\""
	@exit 1
endif
	@echo -e "$(GREEN)[INFO]$(NC) Executing in container on $(SERVER_IP)..."
	@ssh -i $(SSH_KEY) openclaw@$(SERVER_IP) \
		'docker exec $$(docker ps -q -f label=com.docker.compose.service=openclaw-gateway) $(CMD)'

# =============================================================================
# SOPS / Secrets Commands
# =============================================================================

secrets-generate-key: ## Generate a new age key for SOPS encryption
	@if [ -f secrets/age-key.txt ]; then \
		echo -e "$(RED)[ERROR]$(NC) secrets/age-key.txt already exists. Delete it first to regenerate."; \
		exit 1; \
	fi
	@echo -e "$(GREEN)[INFO]$(NC) Generating age key..."
	@age-keygen -o secrets/age-key.txt
	@echo ""
	@echo -e "$(GREEN)Key generated!$(NC) Add this to GitHub Secrets as $(BOLD)SOPS_AGE_KEY$(NC):"
	@cat secrets/age-key.txt

secrets-encrypt: ## Encrypt secrets/.env to secrets/.env.enc (requires age key)
	@if [ ! -f secrets/age-key.txt ]; then \
		echo -e "$(RED)[ERROR]$(NC) secrets/age-key.txt not found. Run: make secrets-generate-key"; \
		exit 1; \
	fi
	@if [ ! -f secrets/.env ]; then \
		echo -e "$(RED)[ERROR]$(NC) secrets/.env not found."; \
		exit 1; \
	fi
	@if grep -q 'age: null' .sops.yaml; then \
		echo -e "$(RED)[ERROR]$(NC) .sops.yaml still has 'age: null'. Run: make secrets-generate-key, then paste your public key into .sops.yaml"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)[INFO]$(NC) Encrypting secrets/.env → secrets/.env.enc..."
	@export SOPS_AGE_KEY_FILE=secrets/age-key.txt && \
		sops --encrypt --input-type dotenv --age "$$(age-keygen -y secrets/age-key.txt)" \
		secrets/.env > secrets/.env.enc
	@echo -e "$(GREEN)Encrypted!$(NC) secrets/.env.enc is safe to commit."

secrets-decrypt: ## Decrypt secrets/.env.enc to secrets/.env (requires age key)
	@if [ ! -f secrets/age-key.txt ]; then \
		echo -e "$(RED)[ERROR]$(NC) secrets/age-key.txt not found. Run: make secrets-generate-key"; \
		exit 1; \
	fi
	@if [ ! -f secrets/.env.enc ]; then \
		echo -e "$(RED)[ERROR]$(NC) secrets/.env.enc not found. Run: make secrets-encrypt"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)[INFO]$(NC) Decrypting secrets/.env.enc → secrets/.env..."
	@export SOPS_AGE_KEY_FILE=secrets/age-key.txt && \
		sops --decrypt --input-type dotenv --output-type dotenv secrets/.env.enc > secrets/.env
	@echo -e "$(GREEN)Decrypted!$(NC) secrets/.env ready for local use."

secrets-edit: ## Edit encrypted secrets/.env.enc in-place (opens $EDITOR)
	@if [ ! -f secrets/age-key.txt ]; then \
		echo -e "$(RED)[ERROR]$(NC) secrets/age-key.txt not found. Run: make secrets-generate-key"; \
		exit 1; \
	fi
	@export SOPS_AGE_KEY_FILE=secrets/age-key.txt && sops --input-type dotenv --output-type dotenv secrets/.env.enc

# =============================================================================
# Tailscale Commands
# =============================================================================

tailscale-enable: ## Install Tailscale, verify it works, then lock down public SSH via Terraform
	$(call check-server-ip)
	@if [[ -z "$(TAILSCALE_AUTH_KEY)" ]]; then \
		echo -e "$(RED)[ERROR]$(NC) TAILSCALE_AUTH_KEY is not set and could not be read from Terraform output."; \
		echo "  → Run 'make apply' first (with enable_tailscale=true and OAuth creds set), or"; \
		echo "  → Set TAILSCALE_AUTH_KEY manually: export TAILSCALE_AUTH_KEY=tskey-..."; \
		exit 1; \
	fi
	@echo -e "$(BLUE)[DEPLOY]$(NC) Installing and registering Tailscale..."
	@$(ANSIBLE) $(PLAYBOOK) --tags tailscale --extra-vars "tailscale_auth_key=$(TAILSCALE_AUTH_KEY)"
	@echo -e "$(GREEN)[INFO]$(NC) Verifying Tailscale connection..."
	@ssh -i $(SSH_KEY) openclaw@$(SERVER_IP) 'sudo tailscale status' || { \
		echo -e "$(RED)[ERROR]$(NC) Tailscale not connected. Public SSH is still open. Fix the issue and retry."; \
		exit 1; \
	}
	@echo -e "$(YELLOW)[INFO]$(NC) Tailscale verified. Closing public SSH in terraform.tfvars..."
	@sed -i 's/^ssh_allowed_cidrs = .*/ssh_allowed_cidrs = []/' terraform/envs/prod/terraform.tfvars
	@echo -e "$(GREEN)[INFO]$(NC) Applying Terraform to enforce SSH lockdown..."
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	@echo -e "$(GREEN)[OK]$(NC) Done! SSH is now Tailscale-only."
	@echo -e "$(YELLOW)[TIP]$(NC) Set SERVER_IP=\"openclaw-prod\" in secrets/inputs.sh to use MagicDNS for all make commands."

tailscale-setup: ## Install and register Tailscale on VPS (TAILSCALE_AUTH_KEY auto-read from Terraform output)
	@if [[ -z "$(TAILSCALE_AUTH_KEY)" ]]; then \
		echo -e "$(RED)[ERROR]$(NC) TAILSCALE_AUTH_KEY is not set and could not be read from Terraform output."; \
		echo "  → Run 'make apply' first (with enable_tailscale=true and OAuth creds set), or"; \
		echo "  → Set TAILSCALE_AUTH_KEY manually: export TAILSCALE_AUTH_KEY=tskey-..."; \
		exit 1; \
	fi
	@echo -e "$(BLUE)[DEPLOY]$(NC) Installing and registering Tailscale on VPS..."
	@$(ANSIBLE) $(PLAYBOOK) --tags tailscale --extra-vars "tailscale_auth_key=$(TAILSCALE_AUTH_KEY)"

tailscale-status: ## Show detailed Tailscale status and peers
	@echo -e "$(GREEN)[INFO]$(NC) Checking Tailscale status..."
	@ssh -i $(SSH_KEY) openclaw@$(SERVER_IP) 'sudo tailscale status'

tailscale-ip: ## Get Tailscale IP address
	@ssh -i $(SSH_KEY) openclaw@$(SERVER_IP) 'tailscale ip -4'

tailscale-up: ## Manually authenticate Tailscale
	@echo -e "$(GREEN)[INFO]$(NC) Authenticating Tailscale..."
	@ssh -i $(SSH_KEY) -t openclaw@$(SERVER_IP) 'sudo tailscale up'

# =============================================================================
# Help
# =============================================================================

help: ## Show this help message
	@echo -e "$(BOLD)OpenClaw Infrastructure$(NC)"
	@echo ""
	@echo -e "Usage: make <target> [ENV=prod]"
	@echo ""
	@echo -e "$(BOLD)Terraform:$(NC)"
	@echo -e "  $(GREEN)init$(NC)            Initialize Terraform backend"
	@echo -e "  $(GREEN)plan$(NC)            Preview Terraform changes"
	@echo -e "  $(YELLOW)apply$(NC)           Apply Terraform changes"
	@echo -e "  $(RED)destroy$(NC)         Destroy all managed infrastructure"
	@echo -e "  $(GREEN)fmt$(NC)             Format Terraform files"
	@echo ""
	@echo -e "$(BOLD)Deploy:$(NC)"
	@echo -e "  $(BLUE)bootstrap$(NC)           First-time VPS setup (dirs, timers, Docker build, config push, start)"
	@echo -e "  $(BLUE)bootstrap-check$(NC)     Dry-run bootstrap (--check --diff), shows what would change"
	@echo -e "  $(BLUE)deploy$(NC)              Push config/env to VPS and restart containers"
	@echo -e "  $(BLUE)deploy-check$(NC)        Dry-run deploy (--check --diff), shows what would change"
	@echo -e "  $(BLUE)deploy REBUILD=1$(NC)    Also rebuild Docker images before restart"
	@echo -e "  $(BLUE)setup-auth$(NC)          Set up Claude subscription auth"
	@echo ""
	@echo -e "$(BOLD)Operations:$(NC)"
	@echo -e "  $(GREEN)ssh$(NC)             SSH as openclaw user"
	@echo -e "  $(GREEN)tunnel$(NC)          SSH tunnel to gateway (localhost:18789)"
	@echo -e "  $(GREEN)status$(NC)          Check VPS status"
	@echo -e "  $(GREEN)logs$(NC)            Stream Docker logs"
	@echo -e "  $(GREEN)backup-now$(NC)      Run backup now on VPS"
	@echo -e "  $(GREEN)backup-pull$(NC)     Download latest VPS backup to ./backups/ locally"
	@echo -e "  $(GREEN)restore$(NC)         List available backups (dry-run)"
	@echo -e "  $(GREEN)restore EXECUTE=1 BACKUP=<file>$(NC)  Actually restore from backup"
	@echo -e "  $(GREEN)workspace-sync$(NC)  Sync workspace to GitHub now"
	@echo -e "  $(GREEN)output$(NC)          Show Terraform outputs"
	@echo -e "  $(GREEN)ip$(NC)              Show server IP"
	@echo -e "  $(GREEN)clean$(NC)           Clean Terraform cache files"
	@echo -e "  $(GREEN)validate$(NC)        Validate Terraform + shell scripts + config + Ansible"
	@echo ""
	@echo -e "$(BOLD)Tailscale:$(NC)"
	@echo -e "  $(BLUE)tailscale-enable$(NC)  Install Tailscale, verify, and lock down public SSH (requires TAILSCALE_AUTH_KEY)"
	@echo -e "  $(BLUE)tailscale-setup$(NC)   Install and register Tailscale only, no SSH lockdown (requires TAILSCALE_AUTH_KEY)"
	@echo -e "  $(GREEN)tailscale-status$(NC)  Show Tailscale status and peers"
	@echo -e "  $(GREEN)tailscale-ip$(NC)      Get Tailscale IP address"
	@echo -e "  $(GREEN)tailscale-up$(NC)      Manually authenticate Tailscale"
	@echo ""
	@echo -e "$(BOLD)Secrets (SOPS):$(NC)"
	@echo -e "  $(GREEN)secrets-generate-key$(NC)  Generate age key (first-time setup)"
	@echo -e "  $(GREEN)secrets-encrypt$(NC)       Encrypt secrets/.env → secrets/.env.enc"
	@echo -e "  $(GREEN)secrets-decrypt$(NC)       Decrypt secrets/.env.enc → secrets/.env"
	@echo -e "  $(GREEN)secrets-edit$(NC)          Edit encrypted secrets in-place"
	@echo ""
	@echo -e "$(BOLD)Quick Start:$(NC)"
	@echo "  source secrets/inputs.sh"
	@echo "  make init && make plan && make apply"
	@echo "  make bootstrap"
	@echo "  make deploy          # day-to-day config push + restart"
	@echo "  make deploy REBUILD=1  # after docker/ or docker-compose.yml changes"
	@echo "  make status"
	@if [ -f Makefile.local ]; then echo ""; echo -e "$(BOLD)Local (from Makefile.local):$(NC)"; grep -E '^[a-zA-Z_-]+:.*?## ' Makefile.local | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'; fi
