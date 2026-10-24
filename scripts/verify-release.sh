#!/usr/bin/env bash
# Verify a detached BTF release artifact (sha256 + optional cosign + gh attestation).
set -euo pipefail

usage() {
    cat <<'EOF' >&2
usage: verify-release.sh <path-to.btf.zst>

Expects siblings next to the blob:
  *.sha256
  *.metadata.json          (optional but recommended)
  *.btf.zst.sigstore.json  (optional cosign bundle)
EOF
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

btf="$1"
if [[ ! -f "$btf" ]]; then
    echo "error: file not found: $btf" >&2
    exit 1
fi

dir="$(cd "$(dirname "$btf")" && pwd)"
base="$(basename "$btf")"
stem="${base%.btf.zst}"
sha_file="${dir}/${stem}.sha256"
meta_file="${dir}/${stem}.metadata.json"
bundle="${dir}/${base}.sigstore.json"
repo="${VERIFY_REPO:-roberteggl/raspberrypi-kernel-btf}"

echo "==> SHA-256"
if [[ ! -f "$sha_file" ]]; then
    echo "error: missing $sha_file" >&2
    exit 1
fi
(
    cd "$dir"
    sha256sum -c "$(basename "$sha_file")"
)

if [[ -f "$meta_file" ]]; then
    echo "==> metadata digest cross-check"
    expected="$(jq -r '.btf.sha256 // empty' "$meta_file")"
    actual="$(sha256sum "$btf" | awk '{print $1}')"
    if [[ -n "$expected" && "$expected" != "$actual" ]]; then
        echo "error: metadata btf.sha256 mismatch" >&2
        echo "  metadata: $expected" >&2
        echo "  actual:   $actual" >&2
        exit 1
    fi
    echo "metadata OK (schema $(jq -r '.schema_version' "$meta_file"))"
    jq -r '
      "kernel_commit=\(.kernel_commit)",
      "kernel_release=\(.kernel_release)",
      "defconfig=\(.defconfig)",
      "builder_repo=\(.builder.repository // "n/a")",
      "run_url=\(.builder.run_url // "n/a")"
    ' "$meta_file"
fi

if [[ -f "$bundle" ]]; then
    echo "==> cosign (Sigstore keyless)"
    if ! command -v cosign >/dev/null 2>&1; then
        echo "warn: cosign not installed; skip signature verify" >&2
    else
        cosign verify-blob \
            --bundle "$bundle" \
            --certificate-identity-regexp "https://github.com/${repo}/" \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com \
            "$btf"
        echo "cosign OK"
    fi
else
    echo "==> cosign: no bundle present (${base}.sigstore.json); skipped"
fi

if command -v gh >/dev/null 2>&1; then
    echo "==> GitHub attestation"
    if gh attestation verify "$btf" --repo "$repo" 2>/dev/null; then
        echo "attestation OK"
    else
        echo "warn: gh attestation verify failed or unavailable (ok for older releases)" >&2
    fi
else
    echo "==> attestation: gh CLI not installed; skipped"
fi

echo "OK: $btf"
