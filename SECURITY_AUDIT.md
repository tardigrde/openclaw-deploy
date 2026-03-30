# Security Audit Findings

> **Last Updated:** March 2026
> **Repository:** openclaw-deploy

This document records security findings from auditing the openclaw-deploy repository and their resolution status.

---

## Resolved Findings

### 1. Backup includes SOPS age key (CRITICAL) ✅ FIXED

**Location:** `scripts/backup.sh`

**Issue:** The backup script included `~/.config/sops` which contains the SOPS age key. This defeats the entire encryption mechanism - a stolen backup could be decrypted by simply extracting the age key.

**Resolution:** Backup now excludes the age key. Restore requires either:
1. Original age key (kept separately)
2. Re-encryption with new age key after restore

---

### 2. allowInsecureAuth in example config (CRITICAL) ✅ FIXED

**Location:** `openclaw.example.json`, `README.md`

**Issue:** Example config contained `"allowInsecureAuth": true` which is a security downgrade per OpenClaw documentation. This setting allows Control UI auth without HTTPS.

**Resolution:** Removed from example. For new users:
- Tailscale Serve provides HTTPS automatically (recommended)
- SSH tunnel for local-only access (`ssh -L 18789:127.0.0.1:18789 user@vps`)

---

### 3. Missing sandbox configuration guidance (HIGH) ✅ ADDRESSED

**Location:** New file `docs/guides/sandboxing.md`

**Issue:** No sandbox configuration in example, users didn't know how to enable it.

**Resolution:** Added comprehensive sandboxing guide with mode/scope/workspace access explanations.

---

### 4. Workspace sync token handling (HIGH) ✅ IMPROVED

**Location:** `scripts/workspace-sync.sh`

**Issue:** Token appeared in URL format `https://token:XXX@github.com` which could leak to logs.

**Resolution:** Changed to use GitHub's recommended format `https://x-access-token:TOKEN@github.com` and added documentation recommending deploy keys instead of personal tokens.

---

### 5. SSH default CIDR too permissive (MEDIUM) ✅ DOCUMENTED

**Location:** `secrets/inputs.example.sh`

**Issue:** Default `["0.0.0.0/0"]` allows SSH from anywhere.

**Resolution:** Added prominent warning comment requiring users to change this value.

---

## Deferred Findings

These issues are lower priority or require app-level changes outside this repository:

### 6. Backup not encrypted at rest (HIGH)

**Description:** Backups are stored as plain tar.gz in `~/backups/`

**Status:** Deferred. Would require additional complexity for encryption.

**Mitigation:** Document that backups should be stored in encrypted cloud storage.

---

### 7. No rate limiting on gateway (MEDIUM)

**Description:** OpenClaw gateway has no rate limiting (per threat model T-IMPACT-002)

**Status:** This is an OpenClaw app-level concern, not deploy repo

**Mitigation:** Document as known gap in OpenClaw security posture.

---

### 8. Terraform state local by default (LOW)

**Description:** State files may contain sensitive values

**Status:** Remote state is optional; local default is fine for single-user setups

**Mitigation:** Document in docs/operations/remote-state.md

---

## Known Gaps (OpenClaw App-Level)

These are outside the scope of this deploy repository:

1. **Prompt injection mitigation** - handled by OpenClaw core
2. **ClawHub skill scanning** - VirusTotal integration in progress per threat model
3. **Token encryption at rest** - T-ACCESS-003 in threat model

---

## Security Best Practices Applied

Many security controls ARE properly implemented:

- ✅ fail2ban with 3 retries → 1hr ban
- ✅ SSH key-only auth, root login disabled
- ✅ UFW default-deny inbound
- ✅ IPv6 disabled at OS level
- ✅ Scoped sudo permissions (7 specific commands only)
- ✅ SOPS + age encryption for secrets
- ✅ Automatic security updates (unattended-upgrades)
- ✅ Container port bound to 127.0.0.1 (no public exposure)
- ✅ Tailscale-only mode supported
- ✅ Tailscale Serve for HTTPS in tailnet
- ✅ GitHub Actions with SOPS decrypt + cleanup
- ✅ File permissions (0600/0700) throughout
- ✅ No root login via SSH

---

## Reporting Security Issues

If you find a security vulnerability in this repository:

1. **Do NOT open a public issue**
2. Email: security@openclaw.ai (or check OpenClaw docs for current contact)
3. Include details:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

---

## Changelog

| Date | Change |
|------|--------|
| 2026-03-30 | Initial security audit |
| 2026-03-30 | Fixed critical: backup age key inclusion |
| 2026-03-30 | Fixed critical: allowInsecureAuth removal |
| 2026-03-30 | Fixed high: sandboxing documentation added |
| 2026-03-30 | Fixed high: workspace token handling |
| 2026-03-30 | Fixed medium: SSH CIDR warning added |