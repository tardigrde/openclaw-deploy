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

curl -fsSL --proto =https "${SOPS_BASE}/${SOPS_ASSET}"              -o "${tmpdir}/sops"
curl -fsSL --proto =https "${SOPS_BASE}/sops-v${SOPS_VERSION}.checksums.txt" -o "${tmpdir}/checksums.txt"

if curl -fsSL --proto =https "${SOPS_BASE}/sops-v${SOPS_VERSION}.checksums.sigstore.json" -o "${tmpdir}/bundle.json" 2>/dev/null; then
  # sops >= 3.13 publishes a cosign bundle instead of the classic
  # .sig/.pem pair. Requires cosign >= 2.6 — cosign v3.1.x cannot verify
  # this bundle ("bundle does not contain cert" / "unsupported tlog public
  # key type: PKIX_ED25519").
  cosign verify-blob \
    --bundle "${tmpdir}/bundle.json" \
    --certificate-identity "https://github.com/getsops/sops/.github/workflows/release.yml@refs/tags/v${SOPS_VERSION}" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    "${tmpdir}/checksums.txt"
else
  # sops <= 3.12: classic cosign certificate + signature assets
  curl -fsSL --proto =https "${SOPS_BASE}/sops-v${SOPS_VERSION}.checksums.sig" -o "${tmpdir}/checksums.sig"
  curl -fsSL --proto =https "${SOPS_BASE}/sops-v${SOPS_VERSION}.checksums.pem" -o "${tmpdir}/checksums.pem"
  cosign verify-blob \
    --certificate "${tmpdir}/checksums.pem" \
    --signature   "${tmpdir}/checksums.sig" \
    --certificate-identity "https://github.com/getsops/sops/.github/workflows/release.yml@refs/tags/v${SOPS_VERSION}" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    "${tmpdir}/checksums.txt"
fi

expected=$(grep "${SOPS_ASSET}$" "${tmpdir}/checksums.txt" | awk '{print $1}')
echo "${expected}  ${tmpdir}/sops" | sha256sum --check

install -m 0755 "${tmpdir}/sops" "${INSTALL_PATH}"
