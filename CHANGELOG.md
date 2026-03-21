# CHANGELOG


## v0.0.1 (2026-03-21)

### Bug Fixes

- Rename example workflows to .yml.example, add automated releases
  ([`45dc5c6`](https://github.com/tardigrde/openclaw-deploy/commit/45dc5c6dfa6412781f1932307554896512e6445a))

- Rename deploy.example.yml → deploy.yml.example and rollback.example.yml → rollback.yml.example so
  GitHub Actions no longer picks them up as real workflows - Add release.yml:
  python-semantic-release on push to main, creates GitHub Releases + CHANGELOG from conventional
  commits, no PyPI publishing - Add pyproject.toml with [tool.semantic_release] config - Fix stale
  secret names in security-hardening.md (CI_SSH_PRIVATE_KEY → SSH_PRIVATE_KEY,
  VPS_TAILSCALE_HOSTNAME → SERVER_IP) - Fix VPS_TAILSCALE_HOSTNAME → SERVER_IP in
  gitops-auto-deploy.md - Update docs/cicd.md to reference new template filename

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
