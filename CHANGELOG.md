# CHANGELOG


## v0.13.3 (2026-03-27)

### Bug Fixes

- Address PR review comments
  ([`eb80f26`](https://github.com/tardigrde/openclaw-deploy/commit/eb80f2640fcbf079270413fc6a0ff2dfb5147736))

### Documentation

- Fix broken links, stale content, and documentation inconsistencies
  ([`b54f389`](https://github.com/tardigrde/openclaw-deploy/commit/b54f389eb35d668f12c5bf761f16972e3d8de6d4))


## v0.13.2 (2026-03-26)

### Bug Fixes

- Pre-create .config dir so Chrome crash reports work with volume mounts
  ([`6124901`](https://github.com/tardigrde/openclaw-deploy/commit/61249012e34ed8832d3d4d4572ef35ce135bd06e))


## v0.13.1 (2026-03-26)

### Bug Fixes

- Explicitly install Chromium system libs instead of relying on --with-deps
  ([`12bc276`](https://github.com/tardigrde/openclaw-deploy/commit/12bc2764461b4173e919c2b1c272e7017c4f97d2))

- Install sudo so agent-browser install --with-deps works in slim image
  ([`ca4c73d`](https://github.com/tardigrde/openclaw-deploy/commit/ca4c73dd6246232da88af5c48cb4dfd3121e2f23))


## v0.13.0 (2026-03-26)

### Features

- Migrate from chromedp sidecar to agent-browser embedded Chromium
  ([`821fea3`](https://github.com/tardigrde/openclaw-deploy/commit/821fea39eaa6b13e8e84caa7ea7e86193673b453))


## v0.12.0 (2026-03-26)

### Chores

- **deps**: Update actions/deploy-pages action to v5
  ([#56](https://github.com/tardigrde/openclaw-deploy/pull/56),
  [`5a7802c`](https://github.com/tardigrde/openclaw-deploy/commit/5a7802c44f1317881d7297ec3450524bcc19db89))

- **deps**: Update chromedp/headless-shell docker tag to v147.0.7727.24
  ([#49](https://github.com/tardigrde/openclaw-deploy/pull/49),
  [`fa903e9`](https://github.com/tardigrde/openclaw-deploy/commit/fa903e9734ac3a76e2c72d01bc16be29416e2eaf))

- **deps**: Update chromedp/headless-shell docker tag to v148
  ([#59](https://github.com/tardigrde/openclaw-deploy/pull/59),
  [`584468c`](https://github.com/tardigrde/openclaw-deploy/commit/584468c263a6cc966cf8b80b87c0a960d3a25926))

- **deps**: Update dependency @martian-engineering/lossless-claw to v0.5.2
  ([#47](https://github.com/tardigrde/openclaw-deploy/pull/47),
  [`37afc39`](https://github.com/tardigrde/openclaw-deploy/commit/37afc39e61e02716bbb07e6e91af829305e77ff4))

- **deps**: Update dependency ansible-core to v2.20.4
  ([#48](https://github.com/tardigrde/openclaw-deploy/pull/48),
  [`58816e7`](https://github.com/tardigrde/openclaw-deploy/commit/58816e765b1425a34d41a656fc8ef778e25584b6))

- **deps**: Update dependency astral-sh/uv to v0.11.1
  ([#51](https://github.com/tardigrde/openclaw-deploy/pull/51),
  [`67ac074`](https://github.com/tardigrde/openclaw-deploy/commit/67ac074de3b76e93c9c29a9a1f9562737b485c60))

- **deps**: Update dependency gohugoio/hugo to v0.159.0
  ([#52](https://github.com/tardigrde/openclaw-deploy/pull/52),
  [`d79a2ea`](https://github.com/tardigrde/openclaw-deploy/commit/d79a2ea8ffb114ad11d27e0f1b68e69392e08eea))

- **deps**: Update dependency hashicorp/terraform to v1.14.8
  ([#53](https://github.com/tardigrde/openclaw-deploy/pull/53),
  [`c541f81`](https://github.com/tardigrde/openclaw-deploy/commit/c541f81573e9528f9b2fbf01c6e33dc53c90a957))

- **deps**: Update dependency python-semantic-release to v10
  ([#57](https://github.com/tardigrde/openclaw-deploy/pull/57),
  [`c8237d6`](https://github.com/tardigrde/openclaw-deploy/commit/c8237d6323be8aed32e2c4509a2d5e00c57b49bd))

- **deps**: Update dependency python-semantic-release to v9.21.1
  ([#54](https://github.com/tardigrde/openclaw-deploy/pull/54),
  [`802b2fd`](https://github.com/tardigrde/openclaw-deploy/commit/802b2fd1df39cc1305d17453c5013111b9ed4dc5))

- **deps**: Update dependency sigstore/cosign to v2.6.2
  ([#55](https://github.com/tardigrde/openclaw-deploy/pull/55),
  [`5c42bbe`](https://github.com/tardigrde/openclaw-deploy/commit/5c42bbe8d9bf9721e226f8700cbe2f98428afac4))

- **deps**: Update dependency sigstore/cosign to v3
  ([#58](https://github.com/tardigrde/openclaw-deploy/pull/58),
  [`06f4308`](https://github.com/tardigrde/openclaw-deploy/commit/06f43086b10ad3a564fe234eb37096585015e856))

- **deps**: Update node.js to v24.14.1 ([#50](https://github.com/tardigrde/openclaw-deploy/pull/50),
  [`b8ab1c7`](https://github.com/tardigrde/openclaw-deploy/commit/b8ab1c7a01630e6d8125a5730584bcbd938dd9b5))

- **renovate**: Group patch and minor updates to reduce PR noise
  ([#60](https://github.com/tardigrde/openclaw-deploy/pull/60),
  [`9306936`](https://github.com/tardigrde/openclaw-deploy/commit/9306936275d1c6a73ebbf0c51fff6d41ad78dc88))

### Features

- Migrate to agent-browser, add agentmail SDK
  ([`b7d54a6`](https://github.com/tardigrde/openclaw-deploy/commit/b7d54a679ae23a687b82337cf520630e07bdc65d))


## v0.11.0 (2026-03-26)

### Features

- Bump OpenClaw to 2026.3.24
  ([`7e3dd35`](https://github.com/tardigrde/openclaw-deploy/commit/7e3dd359c52eaa9590017f9a934c236641f2e996))


## v0.10.0 (2026-03-24)

### Features

- Add swappiness configuration and swapfile setup for improved memory management
  ([`d1883e7`](https://github.com/tardigrde/openclaw-deploy/commit/d1883e711978503559350e9c34b7f5232b825d18))


## v0.9.2 (2026-03-24)

### Bug Fixes

- Remove DOCKER_SOCKET_GID now that dashboard is gone
  ([`474f6de`](https://github.com/tardigrde/openclaw-deploy/commit/474f6de8dd5756c4799e919112e5f43349477287))


## v0.9.1 (2026-03-24)

### Bug Fixes

- Remove openclaw-dashboard service
  ([`c12d3fd`](https://github.com/tardigrde/openclaw-deploy/commit/c12d3fd3d0d577789267a0d22257acdfb655b0a0))


## v0.9.0 (2026-03-24)

### Documentation

- Add opinionated-by-design note and private fork guide
  ([`b36e5f4`](https://github.com/tardigrde/openclaw-deploy/commit/b36e5f4a185ffff776f4623ee458ed5b12c403c5))

### Features

- Add ACP + Claude Code addon
  ([`ae66ae9`](https://github.com/tardigrde/openclaw-deploy/commit/ae66ae99ea9a7448d86777924144db41fbea2bd3))

- Add acpx + claude-code to Dockerfile
  ([`ace1598`](https://github.com/tardigrde/openclaw-deploy/commit/ace15982bf8b6499c89cf11b47d81239a613e53f))

### Refactoring

- Rework ACP addon — drop Ansible play, add install-optional.sh pattern
  ([`82c58e6`](https://github.com/tardigrde/openclaw-deploy/commit/82c58e6c13d9f6571e5ec94eb9f4817ecc937d9c))


## v0.8.1 (2026-03-24)

### Bug Fixes

- Enhance backup and restore scripts for improved safety and validation
  ([`15723e3`](https://github.com/tardigrde/openclaw-deploy/commit/15723e33bbc34fed3659fc7083e49fcea9bd05ff))

- Harden restore play and backup script
  ([`55f8a1c`](https://github.com/tardigrde/openclaw-deploy/commit/55f8a1cc1e06e342d3171d7346480fcabd0709f2))

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

### Chores

- **renovate**: Track clawhub, summarize, and ws version ARGs
  ([`eb59e40`](https://github.com/tardigrde/openclaw-deploy/commit/eb59e403770e29e376d5e4e54c6930577877e4a7))

### Features

- Add logs-tail target for non-following log snapshots
  ([`b16c4c1`](https://github.com/tardigrde/openclaw-deploy/commit/b16c4c13560cd12aedbdfe5e163faa4e6cad9fb7))

### Refactoring

- Combine clawhub/ws Renovate managers per code review
  ([`f3dc6ca`](https://github.com/tardigrde/openclaw-deploy/commit/f3dc6cacfb2b0930c7d442979e57f42769de7be7))


## v0.7.1 (2026-03-23)

### Bug Fixes

- **ansible**: Add missing scripts/ copy task in docker playbook
  ([`5e33ffa`](https://github.com/tardigrde/openclaw-deploy/commit/5e33ffa907b80f62ec4326e9475098d0e8a5c924))

### Chores

- **deps**: Pin clawhub, summarize, and ws versions in Dockerfile
  ([`90b5686`](https://github.com/tardigrde/openclaw-deploy/commit/90b56866de3489a3d29111e4674bfbc234b98cd1))

### Continuous Integration

- Remove unnecessary sudo from SOPS install in example workflows
  ([`676f177`](https://github.com/tardigrde/openclaw-deploy/commit/676f177a0c348cb86918e9295dfd2fc392f20702))


## v0.7.0 (2026-03-23)

### Chores

- Complete Renovate version coverage ([#32](https://github.com/tardigrde/openclaw-deploy/pull/32),
  [`798a2d4`](https://github.com/tardigrde/openclaw-deploy/commit/798a2d4259afc24258161fcc0fbe803e6cb49e5d))

- **deps**: Update dependency getsops/sops to v3.12.2
  ([#1](https://github.com/tardigrde/openclaw-deploy/pull/1),
  [`f949ac1`](https://github.com/tardigrde/openclaw-deploy/commit/f949ac1864742a5c6748acc4be4a56d76583aa07))

### Features

- **deps**: Update openclaw to 2026.3.22
  ([#33](https://github.com/tardigrde/openclaw-deploy/pull/33),
  [`da57a26`](https://github.com/tardigrde/openclaw-deploy/commit/da57a26b76243c8b92e96c255dec588f3e62ffd6))


## v0.6.6 (2026-03-23)

### Bug Fixes

- Replace hardcoded SOPS SHA256 with cosign signature verification
  ([#31](https://github.com/tardigrde/openclaw-deploy/pull/31),
  [`e897438`](https://github.com/tardigrde/openclaw-deploy/commit/e897438c980414851211b1a1c279a10a366aecd6))

### Chores

- **deps**: Update dependency crshdn/mission-control to v2.4.0
  ([#21](https://github.com/tardigrde/openclaw-deploy/pull/21),
  [`7ec707b`](https://github.com/tardigrde/openclaw-deploy/commit/7ec707bafa8ae59bf8b746da8534415c57ed8922))


## v0.6.5 (2026-03-23)

### Bug Fixes

- Suppress Renovate lookup error for tflint-ruleset-hcloud
  ([#30](https://github.com/tardigrde/openclaw-deploy/pull/30),
  [`7b01b95`](https://github.com/tardigrde/openclaw-deploy/commit/7b01b959a1f3181964523ae3f5cd6af4c9064527))

### Chores

- **deps**: Update dependency @martian-engineering/lossless-claw to v0.5.0
  ([`649991e`](https://github.com/tardigrde/openclaw-deploy/commit/649991e264d6148bd825d8dafcdf2695e1264606))


## v0.6.4 (2026-03-22)

### Bug Fixes

- Address security review findings (VULN-001/007/008/009/002/003/010)
  ([`13fbf71`](https://github.com/tardigrde/openclaw-deploy/commit/13fbf714ad97cf811856a5738e08463d2721a24c))


## v0.6.3 (2026-03-22)

### Bug Fixes

- Scope Ansible sudo, fix Tailscale TF provider -var, add tee/serve sudoers
  ([`a9fef07`](https://github.com/tardigrde/openclaw-deploy/commit/a9fef075fef4c7b1ca03d645e1d8a0172c1c4240))


## v0.6.2 (2026-03-22)

### Bug Fixes

- Inline plays in site.local.example.yml to allow pre-build insertions
  ([`5a0b094`](https://github.com/tardigrde/openclaw-deploy/commit/5a0b094c0a155ffb3ab7e64e9c208954492597df))


## v0.6.1 (2026-03-22)

### Bug Fixes

- Revert ci_runner key resource, document single-tag OAuth requirement
  ([`1e046e4`](https://github.com/tardigrde/openclaw-deploy/commit/1e046e4ccccb2496e4ffc4c9110344c56ee63a73))

### Chores

- Merge main into worktree-pages
  ([`a7b19e9`](https://github.com/tardigrde/openclaw-deploy/commit/a7b19e91b05f84617a75c8f5aff8775a92412461))


## v0.6.0 (2026-03-22)

### Chores

- **deps**: Update terraform tailscale to ~> 0.28
  ([`5b434a6`](https://github.com/tardigrde/openclaw-deploy/commit/5b434a639b5d7c5fc0db85d250f9dddd4463b6ba))

### Features

- Add Terraform-managed CI runner auth key (tag:ci-runner)
  ([`1f3e1e1`](https://github.com/tardigrde/openclaw-deploy/commit/1f3e1e1af8991a675b452ac17d59da8404c89bfa))


## v0.5.0 (2026-03-22)

### Bug Fixes

- Address review feedback on tailscale serve config and oauth variable
  ([`bf55f67`](https://github.com/tardigrde/openclaw-deploy/commit/bf55f67dd09af797b64e907d7ec29bd0ac39b46a))

- Rename terraform-plan/apply workflows to .yml.example to stop CI runs
  ([`6c75c9f`](https://github.com/tardigrde/openclaw-deploy/commit/6c75c9fb1161feed2a9b123deed37115bd618fac))

- Simplify tailscale serve template — hardcode 18789, drop Jinja2 var
  ([`469729f`](https://github.com/tardigrde/openclaw-deploy/commit/469729f97666301dcf84a988c0d19b760cd92b48))

### Chores

- **deps**: Update terraform-linters/setup-tflint action to v6
  ([#19](https://github.com/tardigrde/openclaw-deploy/pull/19),
  [`b9f92c7`](https://github.com/tardigrde/openclaw-deploy/commit/b9f92c7e6dbd10b8055e1d8e8fa781590182fa3c))

### Documentation

- Address README review comments + add tailscale.md
  ([`69941fb`](https://github.com/tardigrde/openclaw-deploy/commit/69941fbce25784d9de25a431a373d60dc7fe0a4a))

- Restructure into sections with getting-started funnel
  ([`b72936f`](https://github.com/tardigrde/openclaw-deploy/commit/b72936f94f67bac3b18874bb6269483e4f2ea861))

- Update cicd.md to reference renamed .yml.example workflow files
  ([`707c16d`](https://github.com/tardigrde/openclaw-deploy/commit/707c16d6dea4904689bbc5e6ed6a505089ba8202))

- Update frontmatter, menus, CI workflow, and cross-references
  ([`d8e6b61`](https://github.com/tardigrde/openclaw-deploy/commit/d8e6b615d46db90e8fb1e7e3a7f5b0d78ad09fe7))

- **CLAUDE.md**: Add private mirror and worktree guidance
  ([`7996bfa`](https://github.com/tardigrde/openclaw-deploy/commit/7996bfa56bd82475e1ba6f6829815bb5a5e56f94))

- **README**: Update Tailscale setup for OAuth-based auth key generation
  ([`30b3aef`](https://github.com/tardigrde/openclaw-deploy/commit/30b3aefd05bf7309c4a294b14222935ccebbf3bb))

### Features

- Manage Tailscale config via Terraform provider
  ([`7acfe68`](https://github.com/tardigrde/openclaw-deploy/commit/7acfe68c3f539675d6fda606db58cb7cd768bce3))

- Manage Tailscale via Terraform provider + declarative serve config
  ([`27370c2`](https://github.com/tardigrde/openclaw-deploy/commit/27370c24828ddbc201074b98f09a1a16c3c9c4cb))

### Testing

- Add native Terraform tests for tailscale module + fix fmt + add to CI
  ([`dc77120`](https://github.com/tardigrde/openclaw-deploy/commit/dc77120764a126f976a36dbc79a7abe76990d197))


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


## v0.4.1 (2026-03-22)

### Bug Fixes

- **renovate**: Suppress false go detection and track Hugo version in pages.yml
  ([`36cb4a1`](https://github.com/tardigrde/openclaw-deploy/commit/36cb4a110cf3079b36f8b8fee2b2a3976e5a93e8))


## v0.4.0 (2026-03-22)

### Bug Fixes

- Address Gemini review feedback
  ([`5d1abf6`](https://github.com/tardigrde/openclaw-deploy/commit/5d1abf68042541f80ed3f2e02da2bbbc3b75c9ff))

- Address SonarQube shell and Dockerfile issues
  ([`5f555c7`](https://github.com/tardigrde/openclaw-deploy/commit/5f555c726edcd3f4db436a1ed59fb05aa25a9b6f))

- Exclude go.sum from secret scanner (hashes trigger base64 pattern)
  ([`6427166`](https://github.com/tardigrde/openclaw-deploy/commit/64271669e629f11711ec6d7ddd428051889cea03))

- Redirect remaining error output to stderr in validate.sh
  ([`5cfef3a`](https://github.com/tardigrde/openclaw-deploy/commit/5cfef3a37f59e88dfdde87b11726b38627bead3f))

- Remove committed doc copies, copy in CI instead
  ([`605b552`](https://github.com/tardigrde/openclaw-deploy/commit/605b552330b2c35689440e3ee89a3ad22fb15e94))

- Resolve mkdocs --strict build failures in pages workflow
  ([`59da059`](https://github.com/tardigrde/openclaw-deploy/commit/59da05948d956e3eed0b86be981b64a043386528))

- Strip docs/ prefix from links in CI copy step
  ([`ec83b6e`](https://github.com/tardigrde/openclaw-deploy/commit/ec83b6ea7ea433ffeeb75034a2259e3fa13ff720))

- **renovate**: Track lossless-claw plugin pinned in entrypoint.sh
  ([`9983a26`](https://github.com/tardigrde/openclaw-deploy/commit/9983a26977304cafcb61554f3bbd98b1eee74c1e))

### Chores

- Add Renovate custom managers for docs workflow versions
  ([`dbcb27e`](https://github.com/tardigrde/openclaw-deploy/commit/dbcb27ece38c32e16775a334e8ca3fc1a03ca4b1))

- Align openclaw.example.json with docs/openclaw-config.md
  ([`1b846c5`](https://github.com/tardigrde/openclaw-deploy/commit/1b846c5a7b9921b00809643ca5e9d0160eb04fbe))

- Remove personal bot name from mentionPatterns example
  ([`6749fa5`](https://github.com/tardigrde/openclaw-deploy/commit/6749fa5047dea5409131bc8ce017524bdbbfd80c))

- **deps**: Update actions/upload-pages-artifact action to v4
  ([#13](https://github.com/tardigrde/openclaw-deploy/pull/13),
  [`03e8be3`](https://github.com/tardigrde/openclaw-deploy/commit/03e8be3af529524591f95b03e421a3b5d79378c3))

- **deps**: Update github actions ([#5](https://github.com/tardigrde/openclaw-deploy/pull/5),
  [`13688a5`](https://github.com/tardigrde/openclaw-deploy/commit/13688a55e08967036a01fd14bc01e5bfbb7d0483))

### Documentation

- Note that docs/local/CLAUDE.md should be loaded if present
  ([`0dd1d73`](https://github.com/tardigrde/openclaw-deploy/commit/0dd1d73fd1a8fb6ce930520fc1d13488aaa2939a))

- **CLAUDE.md**: Never commit to main; use PR branches with semantic commits
  ([`6107683`](https://github.com/tardigrde/openclaw-deploy/commit/61076836edcf85c97eb1fe73e2a1c25b061b0300))

### Features

- Add GitHub Pages documentation site
  ([`943b7b1`](https://github.com/tardigrde/openclaw-deploy/commit/943b7b1a2159a3fbcf12503aa0f26f41d55f9978))

- Switch from MkDocs to Hugo + PaperMod
  ([`ecbd0a6`](https://github.com/tardigrde/openclaw-deploy/commit/ecbd0a627b7f79794991dcab55c680bc03e481fa))


## v0.3.0 (2026-03-21)

### Features

- Add agent workspace templates support and entrypoint extension hook
  ([`919d36f`](https://github.com/tardigrde/openclaw-deploy/commit/919d36f5c98d0dafd124a20dc03ee98ae9a4e7d2))


## v0.2.0 (2026-03-21)

### Features

- Add bootstrap-check and deploy-check dry-run targets
  ([`96748d9`](https://github.com/tardigrde/openclaw-deploy/commit/96748d9a8b8b197e91b93df5de1528787505d8b8))


## v0.1.0 (2026-03-21)

### Features

- Make terraform.tfvars overridable like backend.tf
  ([`4defed0`](https://github.com/tardigrde/openclaw-deploy/commit/4defed037690ff8816d9e7074776abca0667e1f7))


## v0.0.1 (2026-03-21)

- Initial Release
