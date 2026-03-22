---
title: "Security"
weight: 5
---

Key security properties of this deployment:

- Default SSH is open to `0.0.0.0/0` — restrict before production (see [Security Hardening](/security/hardening/))
- Never commit `secrets/inputs.sh` or `secrets/.env`
- Gateway binds to `127.0.0.1` — never directly exposed to the internet
- Use Tailscale for zero public SSH exposure

## Docs

| Topic | Doc |
|-------|-----|
| Firewall, SSH hardening, SOPS, fail2ban, sudo scoping | [Security Hardening](/security/hardening/) |
| Vulnerability reporting, threat model, best practices | [Security Policy](/security/policy/) |
