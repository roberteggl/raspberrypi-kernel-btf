#!/usr/bin/env bash
# Exit 0 if /boot/vmlinux-$(uname -r) exists and is non-empty; else 1.
# Intended for systemd OnFailure / monitoring.
set -euo pipefail

dest="${BTF_DEST_DIR:-/boot}/vmlinux-$(uname -r)"
if [[ -s "$dest" ]]; then
  echo "ok: $dest ($(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest") bytes)"
  exit 0
fi

echo "missing BTF blob: $dest" >&2
echo "fix: BTF_RELEASE_REPO=${BTF_RELEASE_REPO:-javierhonduco/raspberrypi-kernel-btf} install-btf.sh" >&2
exit 1
