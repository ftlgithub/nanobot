# Offline installer releases

## v0.3.5 (2026-09-16, fork main + offline packaging)

Source commit: `84acc444` (`docs: packaging directory overview`).
Tarballs built from a clean tree at this commit; rebuilds from the same
commit are byte-equivalent except for embedded timestamps.

| Platform | Tarball | Size | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-offline-macos-arm64-v0.3.5.tar.gz` | 91 MB | `01c60555e480e5cff21e15562a4f5154aa515415c405b7c435fa81425c43d6ce` |
| Linux x64 (glibc 2.17+) | `nanobot-offline-linux-x64-v0.3.5.tar.gz` | 203 MB | `05c60cfa75b64e20f67c42df3303f80c2f8780a7e7e4d92ec8c7a0f4573edd19` |

Tarballs live under `packaging/build/<platform>/` (git-ignored build output).

### Contents (per tarball)

- Standalone Python 3.12 (uv-managed build for macOS; python-build-standalone
  `20260901` for Linux) + `install.sh` (two-step `--no-index` install)
- Locked wheelhouse (89 pins; Linux: pillow 12.2.0 / rapidfuzz 3.13.0 /
  tiktoken 0.11.0 capped for manylinux2014, see `packaging/locks/`)
- Prebuilt WebUI (`nanobot/web/dist`, from this checkout)
- Prebundled TUI native binary for the matching platform
- `requirements.txt` (platform lock copy used by `install.sh`)

### Verification (2026-09-16)

- macOS: fresh-extract + clean-HOME install → `nanobot v0.3.5`, modules OK;
  gateway smoke (bootstrap → new_chat → message → session.delete →
  health) PASS.
- Linux: `ubuntu:22.04` amd64 container, `--network none` → install OK;
  same smoke chain PASS (`deleted:true`, `health ok/running`).
- Import sweep on installed package: 324 modules OK; 7 failures are all
  known optional extras (aiohttp/api, matrix, slack, telegram, Windows-only).

### Known limits

- No third-party CLI Apps preinstalled (see offline-installer spec).
- No macOS x64 / Windows / Linux arm64 builds.
- Linux pins diverge from macOS for 3 compiled packages (see above);
  runtime API usage verified compatible.
- Tarball `tar` on macOS emits `LIBARCHIVE.xattr` warnings on Linux
  extraction — harmless, ignored.
