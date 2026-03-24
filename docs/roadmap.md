# Roadmap

## Top Feature: Built-in Web UI Channel

**Why it matters**

Every new user hits the same wall: you need a Telegram account, a bot token, and a paired phone number before you can type a single message to your agent. For most developers evaluating OpenClaw, this friction kills the trial before it starts. Telegram is also a non-starter in many organizations where it's blocked or banned.

A built-in browser-based chat UI — served directly from the gateway — removes that dependency entirely. You deploy, open `localhost:18789` (or your Tailscale URL), and you're talking to your agent. No third-party accounts required.

**What it looks like**

- Minimal single-page app served by the existing gateway on a `/ui` route
- Connects to the gateway via the existing WebSocket/REST API (same protocol Mission Control already uses)
- Auth via the existing gateway token (same `Authorization: Bearer` header)
- Markdown rendering for agent responses, code blocks with syntax highlighting
- Mobile-friendly for on-the-go access over Tailscale

**Rough implementation plan**

1. Add a `/ui` static file route to the gateway serving a small bundled SPA (React or plain HTML — keep the bundle small)
2. Reuse the existing REST/WebSocket message API; no new backend protocol needed
3. Add `webui` to `openclaw.json` channel config (enable/disable, title, welcome message)
4. Document in `docs/guides/` alongside the Telegram guide
5. Update `docker-compose.yml` to expose the port comment clearly for the web UI case

Telegram stays fully supported — this is additive.

---

## Top Fix: Automated Version Updates

**Why it matters**

The Dockerfile pins hard versions for `openclaw`, `clawhub`, and `uv`:

```dockerfile
RUN npm install -g openclaw@2026.3.22 clawhub@0.9.0
```

When a new OpenClaw release ships, staying current requires manually editing the Dockerfile, rebuilding, and redeploying. Miss an update and you're running outdated agent code — potentially with unfixed bugs or missing model support. The repo already has Renovate configured, but it only covers base images and system packages, not the npm packages installed inline.

**What it looks like**

- Renovate picks up `openclaw` and `clawhub` npm version bumps automatically
- A PR is opened, CI validates the build, and the maintainer merges — or auto-merge fires for patch bumps
- Optionally: a `make update` target that pulls latest versions, bumps the Dockerfile, and triggers a redeploy in one command

**Rough implementation plan**

1. Extend `renovate.json` with an `npm` manager entry pointing at the `RUN npm install -g` line in the Dockerfile (Renovate supports this via `regexManagers`)
2. Add a `postUpgradeTasks` hook to run `make validate` in CI on Renovate PRs
3. Add a `make update` convenience target that: fetches latest npm dist-tags, patches the Dockerfile, and optionally triggers `make deploy REBUILD=1`
4. Document the update flow in `docs/operations/`
