#!/usr/bin/env bash
# Install a detached BTF blob for the running Pi kernel.
#
# Default source is the upstream daily builder (has history for older kernels).
# Flip BTF_RELEASE_REPO to roberteggl/raspberrypi-kernel-btf when that fork
# has a matching release for your uname -r.
#
# Uses the public GitHub REST API via curl (no gh auth required for public repos).
set -euo pipefail

BTF_RELEASE_REPO="${BTF_RELEASE_REPO:-javierhonduco/raspberrypi-kernel-btf}"
BTF_TARGET="${BTF_TARGET:-}"
BTF_DEST_DIR="${BTF_DEST_DIR:-/boot}"
BTF_WORKDIR="${BTF_WORKDIR:-$(mktemp -d)}"
BTF_KEEP_WORKDIR="${BTF_KEEP_WORKDIR:-0}"
BTF_VERIFY="${BTF_VERIFY:-1}"
DRY_RUN="${DRY_RUN:-0}"
GITHUB_API="${GITHUB_API:-https://api.github.com}"

cleanup() {
  if [[ "$BTF_KEEP_WORKDIR" != "1" ]]; then
    rm -rf "$BTF_WORKDIR"
  fi
}
trap cleanup EXIT

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

need curl
need zstd
need jq
need sha256sum

uname_r="$(uname -r)"
# 6.18.39+rpt-rpi-2712 -> 6.18.39
kernel_ver="$(printf '%s' "$uname_r" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
[[ "$kernel_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "cannot parse kernel version from uname -r=$uname_r"

if [[ -z "$BTF_TARGET" ]]; then
  if [[ "$uname_r" == *2712* ]] || grep -q 'Raspberry Pi 5' /proc/device-tree/model 2>/dev/null; then
    BTF_TARGET=rpi5
  else
    BTF_TARGET=rpi4
  fi
fi

dest="${BTF_DEST_DIR}/vmlinux-${uname_r}"
echo "repo=${BTF_RELEASE_REPO}"
echo "uname_r=${uname_r}"
echo "kernel_ver=${kernel_ver}"
echo "target=${BTF_TARGET}"
echo "dest=${dest}"

curl_api() {
  local url="$1"
  local args=(-fsSL -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
  if [[ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
    args+=(-H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}")
  fi
  curl "${args[@]}" "$url"
}

# Collect release pages until we find a match or run out (cap pages).
matches_file="$(mktemp)"
page=1
found=0
while [[ $page -le 10 ]]; do
  json="$(curl_api "${GITHUB_API}/repos/${BTF_RELEASE_REPO}/releases?per_page=30&page=${page}")"
  count="$(jq 'length' <<<"$json")"
  [[ "$count" -gt 0 ]] || break
  jq -r --arg t "$BTF_TARGET" --arg v "$kernel_ver" '
    .[] | . as $rel | .assets[]
    | select(.name | test("-" + $t + "-" + $v + "-") and endswith(".btf.zst"))
    | [$rel.tag_name, .name, .browser_download_url]
    | @tsv
  ' <<<"$json" >>"$matches_file"
  if [[ -s "$matches_file" ]]; then
    found=1
    break
  fi
  page=$((page + 1))
done

mapfile -t matches <"$matches_file"
rm -f "$matches_file"

if [[ ${#matches[@]} -eq 0 ]]; then
  die "no ${BTF_TARGET} BTF asset for kernel ${kernel_ver} in ${BTF_RELEASE_REPO}
hint: hold the kernel package, or wait for a matching release, then retry.
      switch repo with: BTF_RELEASE_REPO=roberteggl/raspberrypi-kernel-btf $0"
fi

IFS=$'\t' read -r tag asset_name asset_url <<<"${matches[0]}"
echo "selected tag=${tag} asset=${asset_name}"

stem="${asset_name%.btf.zst}"
mkdir -p "$BTF_WORKDIR"
cd "$BTF_WORKDIR"

download() {
  local name="$1"
  local url="https://github.com/${BTF_RELEASE_REPO}/releases/download/${tag}/${name}"
  curl -fsSL -o "$name" "$url" || return 1
}

download "${stem}.btf.zst" || die "download failed for ${stem}.btf.zst"
download "${stem}.sha256" || die "download failed for ${stem}.sha256"
download "${stem}.metadata.json" || true
download "${stem}.btf.zst.sigstore.json" || true

if [[ "$BTF_VERIFY" == "1" ]]; then
  echo "==> verify sha256"
  sha256sum -c "${stem}.sha256"
  if [[ -f "${stem}.metadata.json" ]]; then
    expected="$(jq -r '.btf.sha256' "${stem}.metadata.json")"
    actual="$(sha256sum "${stem}.btf.zst" | awk '{print $1}')"
    [[ "$expected" == "$actual" ]] || die "metadata sha256 mismatch"
    echo "metadata OK (schema $(jq -r '.schema_version' "${stem}.metadata.json"))"
  fi
fi

zstd -d -f "${stem}.btf.zst" -o "vmlinux-${uname_r}"
ls -lah "vmlinux-${uname_r}"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY_RUN=1 — not installing to ${dest}"
  exit 0
fi

if [[ ! -w "$BTF_DEST_DIR" ]]; then
  sudo install -m 0644 -o root -g root "vmlinux-${uname_r}" "$dest"
else
  install -m 0644 -o root -g root "vmlinux-${uname_r}" "$dest" 2>/dev/null \
    || install -m 0644 "vmlinux-${uname_r}" "$dest"
fi

echo "installed ${dest} ($(sha256sum "$dest" | awk '{print $1}'))"
echo "note: Cilium agent needs host /boot mounted (extraHostPathMounts)."
echo "restart cilium on this node if the agent was already running without the blob."
