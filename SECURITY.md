# Security policy

## Supported artifacts

Only GitHub Releases published from this repository’s `main` branch Actions
workflows are supported. Do not trust copies mirrored elsewhere unless you
re-verify digests and attestations against this repo.

## Reporting a vulnerability

Email **robert@eggl.dev** (or open a private GitHub security advisory on this
repository). Please include:

- Release tag (e.g. `btf-<commit>`)
- Artifact filename(s)
- SHA-256 you observed vs expected
- Whether attestation / cosign verification failed

## Trust model (short)

| Input | Trust source |
| --- | --- |
| Kernel source | `github.com/raspberrypi/linux` at a pinned commit recorded in metadata |
| Build environment | Nix flake lock + GitHub-hosted `ubuntu-22.04` runner |
| Build definition | This repo’s `scripts/build-btf.sh` + `.github/workflows/*` |
| Artifacts | SHA-256 sidecars + Sigstore keyless signatures + GitHub attestations |

Builds are **reproducible in intent** (Nix + locked flake + pinned Actions),
not bit-for-bit hermetic across every runner. Always verify digests before
installing a blob onto a host.
