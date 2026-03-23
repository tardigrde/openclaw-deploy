#!/usr/bin/env bash
# install-sops.sh — Download, verify (via cosign), and install SOPS
#
# Requires cosign to be in PATH.
# Usage: install-sops.sh <version> <install-path>
#   version       e.g. 3.9.4
#   install-path  default: /usr/local/bin/sops
set -euo pipefail

SOPS_VERSION="${1:?Usage: install-sops.sh <version> [install-path]}"
INSTALL_PATH="${2:-/usr/local/bin/sops}"
SOPS_BASE="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}"

# amd64 only — arm64 is not supported
SOPS_ASSET="sops-v${SOPS_VERSION}.linux.amd64"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL "${SOPS_BASE}/${SOPS_ASSET}"              -o "${tmpdir}/sops"
curl -fsSL "${SOPS_BASE}/sops-v${SOPS_VERSION}.checksums.txt" -o "${tmpdir}/checksums.txt"
curl -fsSL "${SOPS_BASE}/sops-v${SOPS_VERSION}.checksums.sig" -o "${tmpdir}/checksums.sig"
curl -fsSL "${SOPS_BASE}/sops-v${SOPS_VERSION}.checksums.pem" -o "${tmpdir}/checksums.pem"

cosign verify-blob \
  --certificate "${tmpdir}/checksums.pem" \
  --signature   "${tmpdir}/checksums.sig" \
  --certificate-identity "https://github.com/getsops/sops/.github/workflows/release.yml@refs/tags/v${SOPS_VERSION}" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${tmpdir}/checksums.txt"

expected=$(grep "${SOPS_ASSET}$" "${tmpdir}/checksums.txt" | awk '{print $1}')
echo "${expected}  ${tmpdir}/sops" | sha256sum --check

install -m 0755 "${tmpdir}/sops" "${INSTALL_PATH}"
