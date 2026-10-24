# raspberrypi-kernel-btf

[![build and release BTF](https://github.com/roberteggl/raspberrypi-kernel-btf/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/roberteggl/raspberrypi-kernel-btf/actions/workflows/build-and-release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Daily **detached BTF** builds for Raspberry Pi OS kernels that do not ship
`/sys/kernel/btf/vmlinux`. Required for eBPF CO-RE consumers such as
**Cilium ≥ 1.20.2** on stock Pi OS.

Maintained by [@roberteggl](https://github.com/roberteggl). Originally based on
[javierhonduco/raspberrypi-kernel-btf](https://github.com/javierhonduco/raspberrypi-kernel-btf).

> **Supply chain:** prefer [Releases from this repository](https://github.com/roberteggl/raspberrypi-kernel-btf/releases)
> only. Verify SHA-256, Sigstore signatures, and GitHub attestations before
> installing. See [PROVENANCE.md](PROVENANCE.md) and [SECURITY.md](SECURITY.md).

## Targets

| Target | Raspberry Pi model | Kernel defconfig | Kernel image name |
| --- | --- | --- | --- |
| `rpi4` | Raspberry Pi 4 / 400 / CM4 64-bit | `bcm2711_defconfig` | `kernel8` |
| `rpi5` | Raspberry Pi 5 / 500 / CM5 64-bit | `bcm2712_defconfig` | `kernel_2712` |

## Install (Pi 5 + Cilium sketch)

```sh
# 1. Pick a release whose kernel_commit/release matches your needs
# 2. Download *.btf.zst + *.sha256 (+ optional .sigstore.json)
./scripts/verify-release.sh ./raspberrypi-linux-*-rpi5-*.btf.zst

KVER="$(uname -r)"
sudo zstd -d raspberrypi-linux-*-rpi5-*.btf.zst -o "/boot/vmlinux-${KVER}"
sudo chmod 644 "/boot/vmlinux-${KVER}"
```

In Cilium Helm values, mount host `/boot` read-only into the agent so
`cilium/ebpf` can find `/boot/vmlinux-$(uname -r)`.

**Kernel upgrades are not automatic.** After `apt` changes the Pi kernel,
`uname -r` changes and you must install a matching blob (or hold the kernel
packages until you do).

## Release artifacts

Each GitHub Release (`btf-<12-char-commit>`) includes, per target:

- `*.btf.zst` — compressed raw BTF
- `*.metadata.json` — commit, defconfig, digests, builder provenance
- `*.sha256` — checksums
- Sigstore keyless signature bundle
- GitHub Actions build attestation (`gh attestation verify`)

## Manual build

```sh
nix develop
./scripts/build-btf.sh rpi4
./scripts/build-btf.sh rpi5
```

Artifacts land in `dist/<target>/`. Override source with `KERNEL_BRANCH` /
`KERNEL_REPO_URL`.

Workflow dispatch accepts an optional `kernel_branch` (e.g. `rpi-6.18.y`).

## Docs

- [PROVENANCE.md](PROVENANCE.md) — trust model, verification, Cilium notes
- [SECURITY.md](SECURITY.md) — reporting and supported artifacts
- [CI-BTF-BROKEN-PIPE.md](CI-BTF-BROKEN-PIPE.md) — known CI flake notes
