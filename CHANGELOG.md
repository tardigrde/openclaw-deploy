# CHANGELOG


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
