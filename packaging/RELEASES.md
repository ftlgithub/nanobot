# Offline installer releases

## v0.3.5 (2026-09-16, fork main + offline packaging)

| Platform | Tarball | Size | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-offline-macos-arm64-v0.3.5.tar.gz` | 91 MB | `b9193107e27257bd11471db55fc875fd9bad7bd549aa397fe11b8737b56c2609` |
| Linux x64 (glibc 2.17+) | `nanobot-offline-linux-x64-v0.3.5.tar.gz` | 203 MB | `371acc8a056af86b527f458c1fd760454ff17f9c629ac80d2b9237bcdeb2fd27` |

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
