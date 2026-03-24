#!/bin/bash
# =============================================================================
# Optional npm packages — runs at Docker build time after the core install.
# =============================================================================
# This file is intentionally empty in the public template.
#
# In your private fork, add any extra npm packages here. They will be baked
# into the image and survive container restarts/rebuilds.
#
# Example (ACP + Claude Code):
#
#   npm install -g \
#     acpx@0.3.1 \
#     @anthropic-ai/claude-code@2.1.81
#
# After editing, rebuild with: make deploy REBUILD=1
# =============================================================================
