# ============================================
# Hetzner VPS Module — Native Terraform Tests
# Run: cd terraform/modules/hetzner-vps && terraform test
# ============================================

mock_provider "hcloud" {
  mock_data "hcloud_ssh_key" {
    defaults = {
      id          = "12345"
      name        = "test-key"
      fingerprint = "aa:bb:cc:dd:ee:ff"
      public_key  = "ssh-ed25519 AAAA... test"
    }
  }

  mock_resource "hcloud_server" {
    defaults = {
      id           = "12345"
      status       = "running"
      ipv4_address = "1.2.3.4"
      ipv6_address = "2001:db8::1"
      ssh_keys     = ["12345"]
    }
    override_during = plan
  }

  mock_resource "hcloud_firewall" {
    defaults = {
      id   = "67890"
      name = "test-fw"
    }
    override_during = plan
  }

  mock_resource "hcloud_firewall_attachment" {
    defaults = {
      id          = "11111"
      firewall_id = "67890"
    }
    override_during = plan
  }
}

# --------------------------------------------
# Default configuration
# --------------------------------------------
run "default_config" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "prod"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
  }

  assert {
    condition     = hcloud_server.main.name == "openclaw-prod"
    error_message = "Server name should be {project}-{environment}"
  }

  assert {
    condition     = hcloud_server.main.ipv4_address == "1.2.3.4"
    error_message = "Server IPv4 should match mock"
  }

  assert {
    condition     = var.enable_tailscale == false
    error_message = "Tailscale should be disabled by default"
  }

  assert {
    condition     = hcloud_server.main.server_type == "cx23"
    error_message = "Default server type should be cx23"
  }

  assert {
    condition     = hcloud_server.main.image == "ubuntu-24.04"
    error_message = "Default image should be ubuntu-24.04"
  }

  assert {
    condition     = hcloud_server.main.location == "nbg1"
    error_message = "Default location should be nbg1"
  }
}

# --------------------------------------------
# Custom server type and location
# --------------------------------------------
run "custom_server_config" {
  command = plan

  variables {
    project_name        = "myapp"
    environment         = "staging"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
    server_type         = "cx33"
    server_location     = "fsn1"
    server_image        = "ubuntu-22.04"
  }

  assert {
    condition     = hcloud_server.main.server_type == "cx33"
    error_message = "Server type should match custom value"
  }

  assert {
    condition     = hcloud_server.main.location == "fsn1"
    error_message = "Server location should match custom value"
  }

  assert {
    condition     = hcloud_server.main.image == "ubuntu-22.04"
    error_message = "Server image should match custom value"
  }

  assert {
    condition     = hcloud_server.main.name == "myapp-staging"
    error_message = "Server name should reflect custom project and environment"
  }
}

# --------------------------------------------
# Invalid environment — expect validation error
# --------------------------------------------
run "invalid_environment" {
  command = plan

  variables {
    project_name        = "test"
    environment         = "invalid"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
  }

  expect_failures = [
    var.environment,
  ]
}

# --------------------------------------------
# Invalid server location — expect validation error
# --------------------------------------------
run "invalid_location" {
  command = plan

  variables {
    project_name        = "test"
    environment         = "dev"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
    server_location     = "us-west-1"
  }

  expect_failures = [
    var.server_location,
  ]
}

# --------------------------------------------
# SSH firewall rules from CIDRs
# --------------------------------------------
run "ssh_cidr_rules" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "prod"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
    ssh_allowed_cidrs   = ["10.0.0.0/8", "192.168.1.0/24"]
  }

  # 2 SSH inbound + 3 egress (tcp, udp, icmp) = 5 rules
  assert {
    condition     = length(hcloud_firewall.main.rule) == 5
    error_message = "Should have 2 SSH + 3 egress rules"
  }
}

# --------------------------------------------
# No SSH CIDRs — only egress rules
# --------------------------------------------
run "no_ssh_cidrs" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "prod"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
    ssh_allowed_cidrs   = []
  }

  # 0 SSH inbound + 3 egress (tcp, udp, icmp) = 3 rules
  assert {
    condition     = length(hcloud_firewall.main.rule) == 3
    error_message = "Should have only 3 egress rules when no SSH CIDRs"
  }
}

# --------------------------------------------
# Tailscale enabled — adds UDP 41641 rule
# --------------------------------------------
run "tailscale_enabled" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "prod"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
    ssh_allowed_cidrs   = ["0.0.0.0/0"]
    enable_tailscale    = true
  }

  # 1 SSH + 1 Tailscale + 3 egress = 5 rules
  assert {
    condition     = length(hcloud_firewall.main.rule) == 5
    error_message = "Should have SSH + Tailscale + 3 egress rules"
  }
}

# --------------------------------------------
# Server labels
# --------------------------------------------
run "server_labels" {
  command = plan

  variables {
    project_name        = "myapp"
    environment         = "dev"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
  }

  assert {
    condition     = hcloud_server.main.labels["project"] == "myapp"
    error_message = "Project label should match project_name"
  }

  assert {
    condition     = hcloud_server.main.labels["environment"] == "dev"
    error_message = "Environment label should match environment"
  }

  assert {
    condition     = hcloud_server.main.labels["managed_by"] == "terraform"
    error_message = "managed_by label should be terraform"
  }
}

# --------------------------------------------
# Firewall attachment links firewall to server
# --------------------------------------------
run "firewall_attachment" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "prod"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
  }

  assert {
    condition     = hcloud_firewall_attachment.main.firewall_id != null
    error_message = "Firewall attachment should reference a firewall"
  }

  assert {
    condition     = length(hcloud_firewall_attachment.main.server_ids) == 1
    error_message = "Firewall should be attached to exactly one server"
  }
}

# --------------------------------------------
# SSH key lookup uses correct fingerprint
# --------------------------------------------
run "ssh_key_lookup" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "prod"
    ssh_key_fingerprint = "ff:ee:dd:cc:bb:aa"
  }

  assert {
    condition     = data.hcloud_ssh_key.main.fingerprint == "ff:ee:dd:cc:bb:aa"
    error_message = "SSH key data source should use provided fingerprint"
  }

  assert {
    condition     = length(hcloud_server.main.ssh_keys) > 0
    error_message = "Server should have at least one SSH key"
  }
}

# --------------------------------------------
# Public networking — IPv4 and IPv6 enabled
# --------------------------------------------
run "public_net" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "prod"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
  }

  assert {
    condition     = one([for pn in hcloud_server.main.public_net : pn.ipv4_enabled if pn.ipv4_enabled != null])
    error_message = "IPv4 should be enabled"
  }

  assert {
    condition     = one([for pn in hcloud_server.main.public_net : pn.ipv6_enabled if pn.ipv6_enabled != null])
    error_message = "IPv6 should be enabled"
  }
}

# --------------------------------------------
# All three valid environments
# --------------------------------------------
run "environment_dev" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "dev"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
  }

  assert {
    condition     = hcloud_server.main.name == "openclaw-dev"
    error_message = "Dev server name should be openclaw-dev"
  }
}

run "environment_staging" {
  command = plan

  variables {
    project_name        = "openclaw"
    environment         = "staging"
    ssh_key_fingerprint = "aa:bb:cc:dd:ee:ff"
  }

  assert {
    condition     = hcloud_server.main.name == "openclaw-staging"
    error_message = "Staging server name should be openclaw-staging"
  }
}
