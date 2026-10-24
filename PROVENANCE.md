# Provenance

This project publishes **detached BPF Type Format (BTF)** blobs for Raspberry
Pi OS kernels that ship without `/sys/kernel/btf/vmlinux`. Consumers (notably
Cilium ≥1.20.2) can load the blob from `/boot/vmlinux-$(uname -r)`.

## Why this fork exists

The upstream project at
[javierhonduco/raspberrypi-kernel-btf](https://github.com/javierhonduco/raspberrypi-kernel-btf)
pioneered the daily build idea. This repository is a maintained fork under
`@roberteggl` so release artifacts are produced by **this account’s** GitHub
Actions, with explicit licensing, verification tooling, and supply-chain
attestations.

## What each release contains

For each target (`rpi4`, `rpi5`):

| File | Purpose |
| --- | --- |
| `*.btf.zst` | zstd-compressed raw BTF (decompress before install) |
| `*.metadata.json` | kernel commit, defconfig, digests, builder identity |
| `*.sha256` | SHA-256 of the `.btf.zst` and `.metadata.json` |
| `*.btf.zst.sig` / `.bundle` | Sigstore keyless signature (cosign) |
| GitHub attestation | SLSA-style build provenance bound to the workflow run |

## Metadata fields (schema ≥2)

```json
{
  "schema_version": "2",
  "kernel_repo": "https://github.com/raspberrypi/linux",
  "kernel_commit": "<full sha>",
  "kernel_release": "6.x.y-v8-16k+",
  "defconfig": "bcm2712_defconfig",
  "btf": { "file": "...", "sha256": "..." },
  "builder": {
    "repository": "roberteggl/raspberrypi-kernel-btf",
    "workflow": "build-and-release.yml",
    "run_id": "...",
    "run_url": "...",
    "flake_lock_sha256": "..."
  }
}
```

## Verify before install

```sh
# from a release directory after download
./scripts/verify-release.sh ./raspberrypi-linux-<commit>-rpi5-*.btf.zst

# or manually
sha256sum -c raspberrypi-linux-<commit>-rpi5-*.sha256
cosign verify-blob \
  --bundle raspberrypi-linux-<commit>-rpi5-*.btf.zst.sigstore.json \
  --certificate-identity-regexp 'https://github.com/roberteggl/raspberrypi-kernel-btf/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  raspberrypi-linux-<commit>-rpi5-*.btf.zst

gh attestation verify raspberrypi-linux-<commit>-rpi5-*.btf.zst \
  --repo roberteggl/raspberrypi-kernel-btf
```

## Install on a Pi (Cilium)

```sh
KVER="$(uname -r)"   # e.g. 6.18.39+rpt-rpi-2712
zstd -d raspberrypi-linux-*-rpi5-*.btf.zst -o "/boot/vmlinux-${KVER}"
chmod 644 "/boot/vmlinux-${KVER}"
```

Mount host `/boot` into the Cilium agent (`extraHostPathMounts`). The filename
**must** match `uname -r`. After a Pi kernel `apt` upgrade, fetch a matching
release (or rebuild) — the old blob will not apply.

## Matching caveats

Blobs are built from `bcm2711_defconfig` / `bcm2712_defconfig`, not the tuned
Raspberry Pi OS `/boot/config-*`. That is usually sufficient for Cilium CO-RE;
if relocation fails, rebuild with `KERNEL_CONFIG_FILE=/boot/config-$(uname -r)`.
