# CHANGELOG


## v0.9.0 (2026-03-24)

### Documentation

- Add opinionated-by-design note and private fork guide
  ([`b36e5f4`](https://github.com/tardigrde/openclaw-deploy/commit/b36e5f4a185ffff776f4623ee458ed5b12c403c5))

### Features

- Add ACP + Claude Code addon
  ([`ae66ae9`](https://github.com/tardigrde/openclaw-deploy/commit/ae66ae99ea9a7448d86777924144db41fbea2bd3))

Install and configure ACP runtime with Claude Code as the default coding harness. Enables coding
  from Telegram/Discord without SSH.

Changes: - addons.yml: addon-acp tag (idempotent — skips if installed) -
  docs/addons/acp-claude-code.md: full setup & usage guide - Makefile.local.example: addon-acp
  target - README.md: link to addon doc + mention in addons section

Usage: make addon-acp

Then: /acp spawn claude --mode persistent --thread auto

- Add acpx + claude-code to Dockerfile
  ([`ace1598`](https://github.com/tardigrde/openclaw-deploy/commit/ace15982bf8b6499c89cf11b47d81239a613e53f))

Baked into container for permanent ACP support across rebuilds. Addon-acp Ansible tasks handle
  config patching (separate concern).

### Refactoring

- Rework ACP addon — drop Ansible play, add install-optional.sh pattern
  ([`82c58e6`](https://github.com/tardigrde/openclaw-deploy/commit/82c58e6c13d9f6571e5ec94eb9f4817ecc937d9c))

- Remove addon-acp Ansible play: installing into a running container is ephemeral (lost on restart)
  and patching openclaw.json VPS-side conflicts with make deploy overwriting it from local - Add
  docker/install-optional.sh: no-op script in core, overridden in private forks to bake optional
  packages (acpx, claude-code, etc.) into the image - Wire install-optional.sh into the Dockerfile
  npm install layer with npm cache clean --force after - Remove ARG ACPX_VERSION /
  CLAUDE_CODE_VERSION from core Dockerfile - Remove addon-acp from Makefile.local.example and README
  optional add-ons - Rewrite docs/addons/acp-claude-code.md: setup now follows the correct model
  (install-optional.sh + openclaw.json edit + make deploy REBUILD=1), fix all "Clawdy" → "OpenClaw",
  add language specifiers to code blocks

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.8.1 (2026-03-24)

### Bug Fixes

- Enhance backup and restore scripts for improved safety and validation
  ([`15723e3`](https://github.com/tardigrde/openclaw-deploy/commit/15723e33bbc34fed3659fc7083e49fcea9bd05ff))

- Harden restore play and backup script
  ([`55f8a1c`](https://github.com/tardigrde/openclaw-deploy/commit/55f8a1cc1e06e342d3171d7346480fcabd0709f2))

Backup script: - Include SOPS age key (~/.config/sops) in backup archives Without this, restored
  .env.enc can't be decrypted after restore

Restore play: - Validate compose directory exists before stopping containers - Add set -euo pipefail
  to shell tasks (prevents silent failures) - Validate restored files after extraction (checks
  critical files exist) - Pull latest container images before docker compose up - Wait for gateway
  health endpoint after restart (30s timeout) - Log restore summary with undo instructions

### Chores

- Bump OpenClaw to 2026.3.23
  ([`d7190ba`](https://github.com/tardigrde/openclaw-deploy/commit/d7190ba9fbeeb43d13141e98b0a373cbf6fe2b5b))

### Documentation

- Enhance backup and restore documentation with detailed procedures and safety measures
  ([`ac75a5c`](https://github.com/tardigrde/openclaw-deploy/commit/ac75a5c7bfd82aae840019ec9efe738efb669f10))

- Expand restore section in README with safety features
  ([`450af7e`](https://github.com/tardigrde/openclaw-deploy/commit/450af7eb13d8170ddd559b74fc21ae5a0587dba9))


## v0.8.0 (2026-03-23)

### Bug Fixes

- Add logs-tail to .PHONY and help output
  ([`5018193`](https://github.com/tardigrde/openclaw-deploy/commit/5018193f99512dfd18feb8cf7a33612717dbceb8))

Address CodeRabbit review feedback.

### Chores

- **renovate**: Track clawhub, summarize, and ws version ARGs
  ([`eb59e40`](https://github.com/tardigrde/openclaw-deploy/commit/eb59e403770e29e376d5e4e54c6930577877e4a7))

Add custom managers so Renovate detects and opens PRs when new versions of clawhub,
  @steipete/summarize, and ws are released on npm.

### Features

- Add logs-tail target for non-following log snapshots
  ([`b16c4c1`](https://github.com/tardigrde/openclaw-deploy/commit/b16c4c13560cd12aedbdfe5e163faa4e6cad9fb7))

### Refactoring

- Combine clawhub/ws Renovate managers per code review
  ([`f3dc6ca`](https://github.com/tardigrde/openclaw-deploy/commit/f3dc6cacfb2b0930c7d442979e57f42769de7be7))

Use a single regex manager with alternation for clawhub and ws instead of two separate entries.
  Summarize stays separate due to its scoped npm name not deriving from the ARG name.


## v0.7.1 (2026-03-23)

### Bug Fixes

- **ansible**: Add missing scripts/ copy task in docker playbook
  ([`5e33ffa`](https://github.com/tardigrde/openclaw-deploy/commit/5e33ffa907b80f62ec4326e9475098d0e8a5c924))

The scripts/ directory (including install-sops.sh, backup.sh, etc.) was never copied to the VPS by
  the Ansible docker play. It worked previously because make bootstrap handles it on first run, but
  make deploy alone would miss these files.

### Chores

- **deps**: Pin clawhub, summarize, and ws versions in Dockerfile
  ([`90b5686`](https://github.com/tardigrde/openclaw-deploy/commit/90b56866de3489a3d29111e4674bfbc234b98cd1))

Pin npm package versions alongside openclaw for reproducible builds. Previously only openclaw was
  pinned; clawhub, @steipete/summarize, and ws floated to latest on every rebuild.

- clawhub@0.9.0 - @steipete/summarize@0.12.0 - ws@8.20.0

### Continuous Integration

- Remove unnecessary sudo from SOPS install in example workflows
  ([`676f177`](https://github.com/tardigrde/openclaw-deploy/commit/676f177a0c348cb86918e9295dfd2fc392f20702))


## v0.7.0 (2026-03-23)

### Chores

- Complete Renovate version coverage ([#32](https://github.com/tardigrde/openclaw-deploy/pull/32),
  [`798a2d4`](https://github.com/tardigrde/openclaw-deploy/commit/798a2d4259afc24258161fcc0fbe803e6cb49e5d))

- Add regex manager for uv (astral-sh/uv, Dockerfile ARG) - Add regex manager for cosign sidecar
  COPY --from in Dockerfile (same depName as Ansible cosign so PRs batch together) - Add regex
  manager for python-semantic-release lower bound in release.yml - Add regex manager for Terraform
  CLI version in CI workflows (setup-terraform input) - Pin chromedp/headless-shell from :latest to
  147.0.7727.15 so Renovate can track it

Co-authored-by: Claude Sonnet 4.6 <noreply@anthropic.com>

- **deps**: Update dependency getsops/sops to v3.12.2
  ([#1](https://github.com/tardigrde/openclaw-deploy/pull/1),
  [`f949ac1`](https://github.com/tardigrde/openclaw-deploy/commit/f949ac1864742a5c6748acc4be4a56d76583aa07))

Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

### Features

- **deps**: Update openclaw to 2026.3.22
  ([#33](https://github.com/tardigrde/openclaw-deploy/pull/33),
  [`da57a26`](https://github.com/tardigrde/openclaw-deploy/commit/da57a26b76243c8b92e96c255dec588f3e62ffd6))

Co-authored-by: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.6.6 (2026-03-23)

### Bug Fixes

- Replace hardcoded SOPS SHA256 with cosign signature verification
  ([#31](https://github.com/tardigrde/openclaw-deploy/pull/31),
  [`e897438`](https://github.com/tardigrde/openclaw-deploy/commit/e897438c980414851211b1a1c279a10a366aecd6))

* fix: suppress Renovate lookup error for tflint-ruleset-hcloud

Renovate fails to resolve github-releases for terraform-linters/tflint-ruleset-hcloud referenced in
  .tflint.hcl. Disable the package rule to stop the recurring lookup error.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

* fix: replace hardcoded SOPS SHA256 with cosign signature verification

Removes SOPS_SHA256 from Dockerfile and CI workflow examples. Renovate could bump SOPS_VERSION but
  had no way to update the hash, causing broken PRs. cosign verifies the SOPS release signature
  against the Sigstore transparency log instead — no hardcoded value to maintain.

- Dockerfile: COPY cosign from gcr.io/projectsigstore/cosign (tracked by Renovate's Docker manager)
  and use it to verify the checksums file before installing the binary - deploy.yml.example /
  rollback.yml.example: use sigstore/cosign-installer action + same verification flow -
  renovate.json: drop the prBodyNotes manual SHA256 reminder (no longer needed) and simplify the
  SOPS package rule description

* fix: call install-sops.sh via bash (COPY strips executable bit)

* fix: check sha256 against actual file path, not checksums filename

* fix: address Gemini review — arch comment, Ansible cosign+script, Renovate tracking

- install-sops.sh: remove arm64 support (amd64 only, add comment); sha256 check already uses correct
  tmpdir path (no-op fix) - renovate.json: remove stale "SHA256 must be updated manually" from
  description; add custom manager to track COSIGN_VERSION in Ansible play - CI workflow examples:
  restore SOPS_VERSION= variable so Renovate's regex manager still matches after script refactor -
  ansible/plays/config.yml: replace hardcoded SHA256 install with cosign install + script copy +
  script invocation; add COSIGN_VERSION= var

---------

Co-authored-by: Claude Sonnet 4.6 <noreply@anthropic.com>

### Chores

- **deps**: Update dependency crshdn/mission-control to v2.4.0
  ([#21](https://github.com/tardigrde/openclaw-deploy/pull/21),
  [`7ec707b`](https://github.com/tardigrde/openclaw-deploy/commit/7ec707bafa8ae59bf8b746da8534415c57ed8922))

Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>


## v0.6.5 (2026-03-23)

### Bug Fixes

- Suppress Renovate lookup error for tflint-ruleset-hcloud
  ([#30](https://github.com/tardigrde/openclaw-deploy/pull/30),
  [`7b01b95`](https://github.com/tardigrde/openclaw-deploy/commit/7b01b959a1f3181964523ae3f5cd6af4c9064527))

Renovate fails to resolve github-releases for terraform-linters/tflint-ruleset-hcloud referenced in
  .tflint.hcl. Disable the package rule to stop the recurring lookup error.

Co-authored-by: Claude Sonnet 4.6 <noreply@anthropic.com>

### Chores

- **deps**: Update dependency @martian-engineering/lossless-claw to v0.5.0
  ([`649991e`](https://github.com/tardigrde/openclaw-deploy/commit/649991e264d6148bd825d8dafcdf2695e1264606))


## v0.6.4 (2026-03-22)

### Bug Fixes

- Address security review findings (VULN-001/007/008/009/002/003/010)
  ([`13fbf71`](https://github.com/tardigrde/openclaw-deploy/commit/13fbf714ad97cf811856a5738e08463d2721a24c))

- VULN-001: comment out Docker socket mount in override example; add warning comment so users can
  re-enable consciously - VULN-007: tighten ~/backups directory mode from 0755 to 0700 - VULN-008:
  add assert task in restore.yml to validate backup_file format before tar extraction - VULN-009:
  replace token-in-URL with temp credential file (mode 600) in workspace-sync.sh so PAT is not
  written to .git/config or visible in ps aux - VULN-002/003/010: document journalctl wildcard,
  curl|sh Tailscale install, and unencrypted intra-container WebSocket risks in SECURITY.md

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.6.3 (2026-03-22)

### Bug Fixes

- Scope Ansible sudo, fix Tailscale TF provider -var, add tee/serve sudoers
  ([`a9fef07`](https://github.com/tardigrde/openclaw-deploy/commit/a9fef075fef4c7b1ca03d645e1d8a0172c1c4240))

- ansible/plays/config.yml: replace become:true on Tailscale serve tasks with scoped sudo calls
  (sudo tee + sudo tailscale serve). Avoids requiring broad python3 NOPASSWD in sudoers — Ansible's
  become uses sudo /bin/sh under the hood which cannot be cleanly scoped.

- terraform/modules/hetzner-vps/cloud-init/user-data.yml.tpl: add NOPASSWD entries for
  /usr/bin/tailscale serve * and /usr/bin/tee /etc/tailscale/serve.json, required by the new Ansible
  tasks.

- Makefile: pass Tailscale OAuth credentials via explicit -var flags in plan and apply. The
  Tailscale Terraform provider ignores TF_VAR_* env vars when TAILSCALE_OAUTH_CLIENT_ID/SECRET are
  also set in the environment (e.g. a separate CI OAuth client), causing 401 errors on every
  plan/apply.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.6.2 (2026-03-22)

### Bug Fixes

- Inline plays in site.local.example.yml to allow pre-build insertions
  ([`5a0b094`](https://github.com/tardigrde/openclaw-deploy/commit/5a0b094c0a155ffb3ab7e64e9c208954492597df))

Importing site.yml as a block makes it impossible to insert local plays at specific points (e.g.
  cloning a private repo before the Docker build). Inline all core plays so users can slot in their
  own plays where needed.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.6.1 (2026-03-22)

### Bug Fixes

- Revert ci_runner key resource, document single-tag OAuth requirement
  ([`1e046e4`](https://github.com/tardigrde/openclaw-deploy/commit/1e046e4ccccb2496e4ffc4c9110344c56ee63a73))

Tailscale OAuth clients with 2+ allowed tags require ALL tags simultaneously on every auth key
  request (tailscale/tailscale#12402). A client with both tag:openclaw-vps and tag:ci-runner cannot
  create single-tag keys for either.

Removes tailscale_tailnet_key.ci_runner — the Terraform OAuth client must stay single-tag
  (tag:openclaw-vps only). The GitHub Actions CI client is a separate OAuth client with
  Devices:Write scope and tag:ci-runner only.

Updates docs to correct scope (Devices:Write only per official Tailscale docs) and warn about the
  single-tag requirement.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

### Chores

- Merge main into worktree-pages
  ([`a7b19e9`](https://github.com/tardigrde/openclaw-deploy/commit/a7b19e91b05f84617a75c8f5aff8775a92412461))

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.6.0 (2026-03-22)

### Chores

- **deps**: Update terraform tailscale to ~> 0.28
  ([`5b434a6`](https://github.com/tardigrde/openclaw-deploy/commit/5b434a639b5d7c5fc0db85d250f9dddd4463b6ba))

### Features

- Add Terraform-managed CI runner auth key (tag:ci-runner)
  ([`1f3e1e1`](https://github.com/tardigrde/openclaw-deploy/commit/1f3e1e1af8991a675b452ac17d59da8404c89bfa))

Adds tailscale_tailnet_key.ci_runner — a reusable ephemeral pre-auth key for GitHub Actions CI
  nodes. The OAuth client must have tag:ci-runner in its allowed tags (alongside tag:openclaw-vps)
  for Terraform to create it.

Output tailscale_ci_runner_auth_key stores as GitHub Secret TAILSCALE_AUTH_KEY.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.5.0 (2026-03-22)

### Bug Fixes

- Address review feedback on tailscale serve config and oauth variable
  ([`bf55f67`](https://github.com/tardigrde/openclaw-deploy/commit/bf55f67dd09af797b64e907d7ec29bd0ac39b46a))

- Make tailscale serve apply idempotent: only run `tailscale serve --config` when the template file
  actually changed (register + when: changed) - Update tailscale_oauth_client_id description: add
  dns:write scope, clarify acls:write is only needed when tailscale_enable_acl=true

Note: did not change ACL grants format — `ip` field is correct for Tailscale grants syntax; Gemini
  conflated grants with legacy acls format.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- Rename terraform-plan/apply workflows to .yml.example to stop CI runs
  ([`6c75c9f`](https://github.com/tardigrde/openclaw-deploy/commit/6c75c9fb1161feed2a9b123deed37115bd618fac))

.example.yml still ends in .yml so GitHub Actions picks them up and runs them on every PR touching
  terraform/. Renaming to .yml.example (matching the deploy.yml.example / rollback.yml.example
  convention) makes GitHub ignore them entirely.

Private forks that want live Terraform CI should copy the .yml.example files, rename to .yml, and
  configure their own backend credentials.

Closes #20

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- Simplify tailscale serve template — hardcode 18789, drop Jinja2 var
  ([`469729f`](https://github.com/tardigrde/openclaw-deploy/commit/469729f97666301dcf84a988c0d19b760cd92b48))

Gateway always listens on 18789 internally (docker-compose internal port is fixed;
  OPENCLAW_GATEWAY_PORT only changes the host binding). The Jinja2 variable was unnecessary and
  could cause confusion.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

### Chores

- **deps**: Update terraform-linters/setup-tflint action to v6
  ([#19](https://github.com/tardigrde/openclaw-deploy/pull/19),
  [`b9f92c7`](https://github.com/tardigrde/openclaw-deploy/commit/b9f92c7e6dbd10b8055e1d8e8fa781590182fa3c))

Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

### Documentation

- Address README review comments + add tailscale.md
  ([`69941fb`](https://github.com/tardigrde/openclaw-deploy/commit/69941fbce25784d9de25a431a373d60dc7fe0a4a))

README: - Clarify Tailscale is optional (default: disabled, add anytime) - Fix misleading "no manual
  console step" — key is auto-generated, but OAuth client still needs to be created once - Note make
  apply can be initial or re-run; skips TS resources without creds - Explain SERVER_IP switch is a
  one-time manual edit (can't automate shell config) - Clarify openclaw.json step is optional and
  only needed for dashboard HTTPS access - Add security note: auth key lives in TF state — protect
  like inputs.sh - Point to new docs/tailscale.md for serve config editing reference

docs/tailscale.md (new): - How serve config works (Terraform + Ansible + make) - Default config and
  how to add extra ports - TS_CERT_DOMAIN explanation - Private fork override guidance - ACL
  management, key rotation, troubleshooting

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- Restructure into sections with getting-started funnel
  ([`b72936f`](https://github.com/tardigrde/openclaw-deploy/commit/b72936f94f67bac3b18874bb6269483e4f2ea861))

Reorganize flat 13-page docs into 6 Hugo sections (getting-started, configuration, guides,
  operations, security, addons) with proper navigation. Extract installation and bootstrap guides
  from README. Add aliases on all moved pages to preserve old URLs.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- Update cicd.md to reference renamed .yml.example workflow files
  ([`707c16d`](https://github.com/tardigrde/openclaw-deploy/commit/707c16d6dea4904689bbc5e6ed6a505089ba8202))

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- Update frontmatter, menus, CI workflow, and cross-references
  ([`d8e6b61`](https://github.com/tardigrde/openclaw-deploy/commit/d8e6b615d46db90e8fb1e7e3a7f5b0d78ad09fe7))

- Add aliases to all moved pages for URL backwards compatibility - Reset section-relative weights on
  moved pages - Update hugo.toml menu to 6 section links - Fix CI workflow: SECURITY.md copies to
  docs/security/policy.md - Update internal cross-references to canonical paths

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- **CLAUDE.md**: Add private mirror and worktree guidance
  ([`7996bfa`](https://github.com/tardigrde/openclaw-deploy/commit/7996bfa56bd82475e1ba6f6829815bb5a5e56f94))

- Note that users typically maintain a private fork; docs/local/CLAUDE.md is where fork-specific
  workflow lives - Explain worktree usage (.claude/worktrees/<branch>/) and how to push - Fix CI
  note: terraform-plan/apply are now .yml.example (inactive templates)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- **README**: Update Tailscale setup for OAuth-based auth key generation
  ([`30b3aef`](https://github.com/tardigrde/openclaw-deploy/commit/30b3aefd05bf7309c4a294b14222935ccebbf3bb))

- Replace manual pre-auth key steps with OAuth client flow: set TF_VAR_enable_tailscale + OAuth
  creds → make apply → make bootstrap → make tailscale-enable - Remove manual `tailscale serve --bg`
  instructions — serve config is now deployed declaratively by `make bootstrap` and kept in sync by
  `make deploy` - Note that TAILSCALE_AUTH_KEY is auto-read from terraform output

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

### Features

- Manage Tailscale config via Terraform provider
  ([`7acfe68`](https://github.com/tardigrde/openclaw-deploy/commit/7acfe68c3f539675d6fda606db58cb7cd768bce3))

- Add tailscale/tailscale provider (~> 0.17) - New terraform/modules/tailscale/:
  tailscale_tailnet_key (reusable, pre-authorized, 90d, tag:openclaw-server) + optional
  tailscale_acl - Wire tailscale_auth_key as Terraform output; Makefile reads it automatically — no
  manual key generation after make apply - Add OAuth client vars (tailscale_oauth_client_id/secret)
  - Replace stale TF_VAR_tailscale_auth_key in inputs.example.sh

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- Manage Tailscale via Terraform provider + declarative serve config
  ([`27370c2`](https://github.com/tardigrde/openclaw-deploy/commit/27370c24828ddbc201074b98f09a1a16c3c9c4cb))

- Add tailscale/tailscale provider (~> 0.17) to envs/prod - New terraform/modules/tailscale:
  generates reusable pre-auth key via OAuth client credentials (no more manual key creation in
  console), manages tailnet settings, MagicDNS, and optional ACL policy - Makefile: auto-read
  TAILSCALE_AUTH_KEY from terraform output so `make bootstrap` and `make tailscale-enable` need no
  extra steps - ansible/plays/tailscale.yml: deploy tailscale-serve.json.j2 and apply serve config
  on bootstrap (declarative, no manual ssh needed) - ansible/plays/config.yml: re-apply serve config
  on `make deploy` when changed (idempotent, silently skipped before Tailscale is installed) -
  ansible/templates/tailscale-serve.json.j2: Jinja2 template for tailscale serve --config (proxies
  gateway port 18789 over HTTPS)

Onboarding is now: set OAuth creds -> make apply -> make bootstrap. No manual key generation step.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

### Testing

- Add native Terraform tests for tailscale module + fix fmt + add to CI
  ([`dc77120`](https://github.com/tardigrde/openclaw-deploy/commit/dc77120764a126f976a36dbc79a7abe76990d197))

- terraform/modules/tailscale/tests/tailscale.tftest.hcl: 7 tests covering auth key properties
  (reusable, preauthorized, expiry, tag, description), auth_key sensitive output, MagicDNS always
  on, tailnet settings defaults, and ACL resource created/skipped based on enable_acl flag - Fix
  terraform fmt on modules/tailscale/main.tf (was causing validate to fail) - validate.yml: add
  tailscale module init + test steps to terraform-test job

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.4.2 (2026-03-22)

### Bug Fixes

- Add required_version to hetzner-vps module terraform block
  ([`b07156a`](https://github.com/tardigrde/openclaw-deploy/commit/b07156ad66527c2dd6b2c0d7c2cab7a6b3ac5ca3))

### Chores

- **deps**: Update dependency @martian-engineering/lossless-claw to v0.4.0
  ([`1e18910`](https://github.com/tardigrde/openclaw-deploy/commit/1e1891077c6def1558dba3c0105fd98c731d617c))

- **deps**: Update dependency crshdn/mission-control to v2
  ([`8164913`](https://github.com/tardigrde/openclaw-deploy/commit/816491329d0e454c1c1bdd23a06b1a4f8a6147b9))

### Continuous Integration

- Add tflint to validate workflow
  ([`186a848`](https://github.com/tardigrde/openclaw-deploy/commit/186a8487955843ddc9a1c0d3130ae02482b2f4ae))

- Rename plan/apply workflows to examples, update docs
  ([`89a12a0`](https://github.com/tardigrde/openclaw-deploy/commit/89a12a0aa4f01498df1483cea64ecbebd8ac9669))

### Testing

- Address Gemini review feedback
  ([`58272ce`](https://github.com/tardigrde/openclaw-deploy/commit/58272ce848e4dbadc6bba301531ca351e00b1bb6))

- Remove override_during for Terraform 1.7 compat, split plan/apply tests
  ([`6f782ba`](https://github.com/tardigrde/openclaw-deploy/commit/6f782ba5209dd960fe3e059a99f4ac41b7c1cf07))

- **terraform**: Add native tests for hetzner-vps module
  ([`473a3a0`](https://github.com/tardigrde/openclaw-deploy/commit/473a3a008afb9f79fd3de2e3bbc77a02c6863360))

13 tests covering defaults, variable validation, firewall rules, Tailscale toggle, server labels,
  firewall attachment, SSH key lookup, public networking, and environment naming.

Adds terraform-test job to validate.yml CI workflow.


## v0.4.1 (2026-03-22)

### Bug Fixes

- **renovate**: Suppress false go detection and track Hugo version in pages.yml
  ([`36cb4a1`](https://github.com/tardigrde/openclaw-deploy/commit/36cb4a110cf3079b36f8b8fee2b2a3976e5a93e8))

HUGO_VERSION was being misidentified as a 'go' package dependency, causing a bogus major-version
  update PR. Fix by: - Disabling go package detection in pages.yml via packageRules - Adding a
  custom manager that correctly tracks HUGO_VERSION against gohugoio/hugo releases

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.4.0 (2026-03-22)

### Bug Fixes

- Address Gemini review feedback
  ([`5d1abf6`](https://github.com/tardigrde/openclaw-deploy/commit/5d1abf68042541f80ed3f2e02da2bbbc3b75c9ff))

- Remove stray `-e` lines in .gitignore (were ignoring files named "e") - Fix missing `[]` brackets
  in secrets.md link syntax

- Address SonarQube shell and Dockerfile issues
  ([`5f555c7`](https://github.com/tardigrde/openclaw-deploy/commit/5f555c726edcd3f4db436a1ed59fb05aa25a9b6f))

- Replace '[' with '[[' for conditional tests in validate.sh, post-edit-validate.sh (S7688) - Add
  default case to case statement in post-edit-validate.sh (S131) - Redirect error messages to stderr
  in validate.sh and workspace-sync.sh (S7677) - Merge consecutive RUN instructions in Dockerfile
  (S7031)

- Exclude go.sum from secret scanner (hashes trigger base64 pattern)
  ([`6427166`](https://github.com/tardigrde/openclaw-deploy/commit/64271669e629f11711ec6d7ddd428051889cea03))

- Redirect remaining error output to stderr in validate.sh
  ([`5cfef3a`](https://github.com/tardigrde/openclaw-deploy/commit/5cfef3a37f59e88dfdde87b11726b38627bead3f))

The error context message and grep diagnostic output in the API key detection block were still going
  to stdout. Redirect them to stderr for consistency with the S7677 changes.

- Remove committed doc copies, copy in CI instead
  ([`605b552`](https://github.com/tardigrde/openclaw-deploy/commit/605b552330b2c35689440e3ee89a3ad22fb15e94))

- Remove docs/changelog.md, docs/claude.md, docs/security.md, docs/index.md - CI workflow now copies
  README.md -> docs/index.md and SECURITY.md -> docs/security.md - Remove About (Changelog + Claude)
  from nav - Add docs/index.md and docs/security.md to .gitignore

- Resolve mkdocs --strict build failures in pages workflow
  ([`59da059`](https://github.com/tardigrde/openclaw-deploy/commit/59da05948d956e3eed0b86be981b64a043386528))

- Add sed transforms for SECURITY.md→security.md link in README and ../README.md→index.md link in
  SECURITY.md - Fix broken anchor in SECURITY.md: #firewall-rules → #firewall--network-access
  (matches actual README heading 'Firewall / Network Access')

- Strip docs/ prefix from links in CI copy step
  ([`ec83b6e`](https://github.com/tardigrde/openclaw-deploy/commit/ec83b6ea7ea433ffeeb75034a2259e3fa13ff720))

README.md and SECURITY.md use docs/ prefix in links (e.g. [secrets.md](docs/secrets.md)) for GitHub
  browsing. When copied into docs/ for MkDocs, those links would resolve to docs/docs/secrets.md —
  broken. CI step now strips the prefix with sed.

- **renovate**: Track lossless-claw plugin pinned in entrypoint.sh
  ([`9983a26`](https://github.com/tardigrde/openclaw-deploy/commit/9983a26977304cafcb61554f3bbd98b1eee74c1e))

Add custom regex manager targeting docker/entrypoint.sh so Renovate can detect and update
  @martian-engineering/lossless-claw version.

Closes #10

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

### Chores

- Add Renovate custom managers for docs workflow versions
  ([`dbcb27e`](https://github.com/tardigrde/openclaw-deploy/commit/dbcb27ece38c32e16775a334e8ca3fc1a03ca4b1))

Tracks HUGO_VERSION, DART_SASS_VERSION, GO_VERSION, and NODE_VERSION in .github/workflows/pages.yml
  via regex customManagers.

- Align openclaw.example.json with docs/openclaw-config.md
  ([`1b846c5`](https://github.com/tardigrde/openclaw-deploy/commit/1b846c5a7b9921b00809643ca5e9d0160eb04fbe))

- Add DM allowFrom for extra access layer beyond pairing - Add specific group example
  (requireMention: false) matching doc pattern - Add "bot" to mentionPatterns to match doc

- Remove personal bot name from mentionPatterns example
  ([`6749fa5`](https://github.com/tardigrde/openclaw-deploy/commit/6749fa5047dea5409131bc8ce017524bdbbfd80c))

- **deps**: Update actions/upload-pages-artifact action to v4
  ([#13](https://github.com/tardigrde/openclaw-deploy/pull/13),
  [`03e8be3`](https://github.com/tardigrde/openclaw-deploy/commit/03e8be3af529524591f95b03e421a3b5d79378c3))

Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

- **deps**: Update github actions ([#5](https://github.com/tardigrde/openclaw-deploy/pull/5),
  [`13688a5`](https://github.com/tardigrde/openclaw-deploy/commit/13688a55e08967036a01fd14bc01e5bfbb7d0483))

Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>

### Documentation

- Note that docs/local/CLAUDE.md should be loaded if present
  ([`0dd1d73`](https://github.com/tardigrde/openclaw-deploy/commit/0dd1d73fd1a8fb6ce930520fc1d13488aaa2939a))

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

- **CLAUDE.md**: Never commit to main; use PR branches with semantic commits
  ([`6107683`](https://github.com/tardigrde/openclaw-deploy/commit/61076836edcf85c97eb1fe73e2a1c25b061b0300))

Closes #11

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>

### Features

- Add GitHub Pages documentation site
  ([`943b7b1`](https://github.com/tardigrde/openclaw-deploy/commit/943b7b1a2159a3fbcf12503aa0f26f41d55f9978))

- Add mkdocs.yml with Material theme (dark/light toggle, search, code blocks) - Copy README,
  SECURITY, CHANGELOG, CLAUDE into docs/ for MkDocs access - Clean internal links in docs/index.md
  for flat docs/ structure - Add .github/workflows/pages.yml — builds on push to main, deploys via
  GitHub Pages - Add site/ to .gitignore (MkDocs build output)

Nav: Getting Started → Architecture → Deployment → Security → Addons → About

- Switch from MkDocs to Hugo + PaperMod
  ([`ecbd0a6`](https://github.com/tardigrde/openclaw-deploy/commit/ecbd0a627b7f79794991dcab55c680bc03e481fa))

- Replace mkdocs.yml with hugo.toml (PaperMod theme via Hugo modules) - Replace pages.yml workflow
  with Hugo build (Go, Dart Sass, Node.js) - Add YAML front matter to all docs/*.md files for Hugo -
  Add docs/_index.md and docs/addons/_index.md section bundles - Add go.mod/go.sum for Hugo module
  dependencies - Update .gitignore: site/ → public/, add resources/ and .hugo_build.lock - CI copies
  README.md → docs/index.md and SECURITY.md → docs/security.md with link transforms (same sed
  approach as before)


## v0.3.0 (2026-03-21)

### Features

- Add agent workspace templates support and entrypoint extension hook
  ([`919d36f`](https://github.com/tardigrde/openclaw-deploy/commit/919d36f5c98d0dafd124a20dc03ee98ae9a4e7d2))

- Copy agent-workspace-templates/ into image at /opt/agent-workspace-templates/ - Seed templates
  into workspace/agents/ on startup (no-clobber) - Source /usr/local/bin/entrypoint.local.sh if
  present (private deployment hook) - Add empty docker/agent-workspace-templates/.gitkeep as
  placeholder

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


## v0.2.0 (2026-03-21)

### Features

- Add bootstrap-check and deploy-check dry-run targets
  ([`96748d9`](https://github.com/tardigrde/openclaw-deploy/commit/96748d9a8b8b197e91b93df5de1528787505d8b8))


## v0.1.0 (2026-03-21)

### Features

- Make terraform.tfvars overridable like backend.tf
  ([`4defed0`](https://github.com/tardigrde/openclaw-deploy/commit/4defed037690ff8816d9e7074776abca0667e1f7))

Rename terraform.tfvars → terraform.tfvars.example so personal infrastructure variables
  (ssh_allowed_cidrs, etc.) are gitignored in the OSS repo and tracked only in private forks.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>


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
