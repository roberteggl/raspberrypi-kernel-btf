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

## Install on a Pi (automated)

Default download source is **upstream**
[`javierhonduco/raspberrypi-kernel-btf`](https://github.com/javierhonduco/raspberrypi-kernel-btf)
(older kernels are published there). When this fork’s release history covers
the kernels you run, flip the config to `roberteggl/raspberrypi-kernel-btf`.

```sh
# one-shot (needs gh auth that can read public releases)
sudo BTF_RELEASE_REPO=javierhonduco/raspberrypi-kernel-btf ./scripts/install-btf.sh

# or install systemd units: boot install + weekly refresh + missing-blob alert
sudo ./packaging/install-host-units.sh
# edit /etc/raspberrypi-btf.conf to switch repos later
```

`install-btf.sh` matches `uname -r` → kernel `X.Y.Z` → newest
`*-rpi5-X.Y.Z-*.btf.zst` (or rpi4), verifies SHA-256, writes
`/boot/vmlinux-$(uname -r)`.

In Cilium Helm values, mount host `/boot` read-only into the agent
(`extraHostPathMounts`). Restart the Cilium pod on the node after first
install if the agent started without the blob.

**Kernel upgrades:** the weekly timer / boot service re-fetches a matching
blob. If no release exists for the new `uname -r`, the guard unit fails and
logs an error — hold packages until a matching BTF exists:

```sh
sudo apt-mark hold linux-image-rpi-2712 linux-image-rpi-v8
```
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
