# Local Addon Scripts

Optional utilities that enhance the OpenClaw setup. These are **not** required for core deployment.

## Setup

Copy this directory to `scripts/local/` (gitignored) to use:

```bash
cp -r scripts/local.example scripts/local
```

The Makefile and Ansible plays reference `scripts/local/` — the example directory is a tracked template only.

## Scripts

### `morning-weather.py`

Morning weather notification script. Sends a daily weather summary to Telegram.

Install on VPS via:

```bash
make addon-weather  # requires scripts/local/morning-weather.py
```

### `hello.sh`

A simple shell script that prints a greeting.

---

*Add your own scripts to `scripts/local/` (gitignored). They won't be tracked by git.*
