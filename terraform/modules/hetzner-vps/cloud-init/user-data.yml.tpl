#cloud-config

# -----------------------------------------------------------------------------
# OpenClaw VPS Cloud-Init Configuration
# -----------------------------------------------------------------------------

package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - git
  - jq
  - ufw
  - software-properties-common
  - unattended-upgrades
  - apt-listchanges
  - fail2ban

# -----------------------------------------------------------------------------
# Write Files
# -----------------------------------------------------------------------------

write_files:
  # Disable IPv6 — UFW only handles IPv4, leaving IPv6 exposed
  - path: /etc/sysctl.d/99-disable-ipv6.conf
    content: |
      net.ipv6.conf.all.disable_ipv6 = 1
      net.ipv6.conf.default.disable_ipv6 = 1
      net.ipv6.conf.lo.disable_ipv6 = 1
    permissions: '0644'

  # fail2ban — brute-force SSH protection
  - path: /etc/fail2ban/jail.local
    content: |
      [sshd]
      enabled = true
      port = ssh
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 3
      bantime = 1h
      findtime = 600
    permissions: '0644'

  # SSH hardening — drop-in overrides (idempotent, survives package upgrades)
  - path: /etc/ssh/sshd_config.d/99-hardening.conf
    content: |
      PasswordAuthentication no
      PermitRootLogin no
      MaxAuthTries 3
      LoginGraceTime 30
      X11Forwarding no
    permissions: '0600'

# -----------------------------------------------------------------------------
# Run Commands
# -----------------------------------------------------------------------------

runcmd:
  # -----------------------------------------------------------------------------
  # Disable IPv6 (applies sysctl settings from write_files)
  # -----------------------------------------------------------------------------
  - sysctl --system

  # -----------------------------------------------------------------------------
  # Create Application User
  # -----------------------------------------------------------------------------
  - useradd -m -s /bin/bash -u 1000 ${app_user}
  - usermod -aG sudo ${app_user}
  # Scoped sudo — allow only commands needed for OpenClaw operations
  # Note: containers are managed via docker compose (no sudo needed, user is in docker group).
  # These are for system-level operations only.
  - |
    cat > /etc/sudoers.d/${app_user} << EOF
    # OpenClaw user sudo permissions — scoped for security
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/tailscale status
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/tailscale up
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/tailscale serve *
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/tee /etc/tailscale/serve.json
    ${app_user} ALL=(root) NOPASSWD: /usr/sbin/ufw status
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/journalctl *
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/systemctl daemon-reload
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/systemctl start docker
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/systemctl enable docker
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/systemctl restart docker
    ${app_user} ALL=(root) NOPASSWD: /usr/bin/fail2ban-client status *
    EOF
  - chmod 440 /etc/sudoers.d/${app_user}

  # Copy SSH authorized keys from root to application user
  - mkdir -p /home/${app_user}/.ssh
  - cp /root/.ssh/authorized_keys /home/${app_user}/.ssh/authorized_keys
  - chown -R ${app_user}:${app_user} /home/${app_user}/.ssh
  - chmod 700 /home/${app_user}/.ssh
  - chmod 600 /home/${app_user}/.ssh/authorized_keys

  # -----------------------------------------------------------------------------
  # Configure UFW Firewall
  # -----------------------------------------------------------------------------
  # Note: Tailscale (UFW rule + install) is handled by Ansible during bootstrap,
  # not here. The Hetzner external firewall (UDP 41641) is managed by Terraform.
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw --force enable

  # -----------------------------------------------------------------------------
  # Start fail2ban and restart sshd with hardened config
  # -----------------------------------------------------------------------------
  - systemctl enable --now fail2ban
  - systemctl restart sshd

  # -----------------------------------------------------------------------------
  # Enable unattended security upgrades
  # -----------------------------------------------------------------------------
  - systemctl enable --now unattended-upgrades

  # -----------------------------------------------------------------------------
  # Final cleanup
  # -----------------------------------------------------------------------------
  - apt-get autoremove -y
  - apt-get clean

# -----------------------------------------------------------------------------
# Final Message
# -----------------------------------------------------------------------------

final_message: "OpenClaw VPS initialization completed after $UPTIME seconds"
