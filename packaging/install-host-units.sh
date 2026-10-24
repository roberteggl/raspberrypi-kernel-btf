#!/usr/bin/env bash
# Install install-btf + systemd units onto a Pi host (run as root / with sudo).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIBDIR=/usr/local/lib/raspberrypi-btf
CONF=/etc/raspberrypi-btf.conf

install -d "$LIBDIR"
install -m 0755 "$REPO_ROOT/scripts/install-btf.sh" "$LIBDIR/install-btf.sh"
install -m 0755 "$REPO_ROOT/scripts/btf-guard.sh" "$LIBDIR/btf-guard.sh"
install -m 0755 "$REPO_ROOT/scripts/verify-release.sh" "$LIBDIR/verify-release.sh" 2>/dev/null || true

install -m 0644 "$REPO_ROOT/packaging/systemd/raspberrypi-btf-install.service" /etc/systemd/system/
install -m 0644 "$REPO_ROOT/packaging/systemd/raspberrypi-btf-install.timer" /etc/systemd/system/
install -m 0644 "$REPO_ROOT/packaging/systemd/raspberrypi-btf-guard.service" /etc/systemd/system/
install -m 0644 "$REPO_ROOT/packaging/systemd/raspberrypi-btf-guard-alert.service" /etc/systemd/system/

if [[ ! -f "$CONF" ]]; then
  install -m 0644 "$REPO_ROOT/packaging/raspberrypi-btf.conf.example" "$CONF"
  echo "wrote $CONF (edit BTF_RELEASE_REPO when switching to your fork)"
fi

systemctl daemon-reload
systemctl enable --now raspberrypi-btf-install.service
systemctl enable --now raspberrypi-btf-install.timer
systemctl enable --now raspberrypi-btf-guard.service

echo "host units installed. Current blob:"
"$LIBDIR/btf-guard.sh" || true
