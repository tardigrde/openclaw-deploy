# ============================================
# Tailscale Module — Native Terraform Tests
# Run: cd terraform/modules/tailscale && terraform test
# ============================================

mock_provider "tailscale" {
  mock_resource "tailscale_tailnet_key" {
    defaults = {
      id  = "abc123"
      key = "tskey-auth-mock000000000000-AAAAAAAAAAAAAAAAAAAAAA"
    }
  }

  mock_resource "tailscale_tailnet_settings" {
    defaults = {
      id = "tailnet-settings"
    }
  }

  mock_resource "tailscale_dns_preferences" {
    defaults = {
      id = "dns-preferences"
    }
  }

  mock_resource "tailscale_acl" {
    defaults = {
      id = "acl"
    }
  }
}

# --------------------------------------------
# Default config — ACL disabled, key created
# --------------------------------------------
run "default_config" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = tailscale_tailnet_key.openclaw.reusable == true
    error_message = "Auth key must be reusable so re-runs don't require a new key"
  }

  assert {
    condition     = tailscale_tailnet_key.openclaw.ephemeral == false
    error_message = "Auth key must not be ephemeral — node should persist after reboot"
  }

  assert {
    condition     = tailscale_tailnet_key.openclaw.preauthorized == true
    error_message = "Auth key must be preauthorized to skip device approval"
  }

  assert {
    condition     = tailscale_tailnet_key.openclaw.expiry == 7776000
    error_message = "Auth key expiry should be 90 days (7776000 seconds)"
  }

  assert {
    condition     = tailscale_tailnet_key.openclaw.description == "openclaw-prod bootstrap key"
    error_message = "Key description should embed the environment name"
  }

  assert {
    condition     = tailscale_tailnet_key.openclaw.tags == toset(["tag:openclaw-vps"])
    error_message = "Auth key must be tagged tag:openclaw-vps"
  }

  # ACL disabled by default — resource should not be created
  assert {
    condition     = length(tailscale_acl.main) == 0
    error_message = "ACL resource should not be created when enable_acl = false"
  }
}

# --------------------------------------------
# Computed output (apply — mock fills key)
# --------------------------------------------
run "auth_key_output" {
  command = apply

  variables {
    environment = "prod"
  }

  assert {
    condition     = output.auth_key != ""
    error_message = "auth_key output must not be empty after apply"
  }

  assert {
    condition     = startswith(output.auth_key, "tskey-")
    error_message = "auth_key output should start with tskey-"
  }
}

# --------------------------------------------
# Environment name embedded in key description
# --------------------------------------------
run "environment_in_description" {
  command = plan

  variables {
    environment = "staging"
  }

  assert {
    condition     = tailscale_tailnet_key.openclaw.description == "openclaw-staging bootstrap key"
    error_message = "Key description should embed the environment variable"
  }
}

# --------------------------------------------
# MagicDNS always enabled
# --------------------------------------------
run "magic_dns_enabled" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = tailscale_dns_preferences.main.magic_dns == true
    error_message = "MagicDNS must always be enabled"
  }
}

# --------------------------------------------
# Tailnet settings — device approval off by default
# --------------------------------------------
run "tailnet_settings_defaults" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = tailscale_tailnet_settings.main.devices_approval_on == false
    error_message = "Device approval should be off by default (tagged nodes auto-approve)"
  }

  assert {
    condition     = tailscale_tailnet_settings.main.devices_auto_updates_on == false
    error_message = "Auto-updates should be off by default"
  }
}

# --------------------------------------------
# ACL enabled — resource created with tag model
# --------------------------------------------
run "acl_enabled" {
  command = plan

  variables {
    environment = "prod"
    enable_acl  = true
  }

  assert {
    condition     = length(tailscale_acl.main) == 1
    error_message = "ACL resource should be created when enable_acl = true"
  }

  assert {
    condition     = can(jsondecode(tailscale_acl.main[0].acl).tagOwners["tag:openclaw-vps"])
    error_message = "ACL must define tagOwners for tag:openclaw-vps"
  }

  assert {
    condition     = can(jsondecode(tailscale_acl.main[0].acl).tagOwners["tag:ci-runner"])
    error_message = "ACL must define tagOwners for tag:ci-runner"
  }

  assert {
    condition     = length(jsondecode(tailscale_acl.main[0].acl).grants) == 2
    error_message = "ACL should have 2 grant rules: catch-all + ci-runner SSH"
  }

  assert {
    condition     = length(jsondecode(tailscale_acl.main[0].acl).ssh) == 1
    error_message = "ACL should have 1 SSH rule for tailnet members"
  }
}

# --------------------------------------------
# ACL disabled (explicit) — resource not created
# --------------------------------------------
run "acl_disabled_explicit" {
  command = plan

  variables {
    environment = "prod"
    enable_acl  = false
  }

  assert {
    condition     = length(tailscale_acl.main) == 0
    error_message = "ACL resource should not be created when enable_acl = false"
  }
}
