# Offline installer releases

## v0.3.5 (2026-09-16, fork main + offline packaging)

Source commit: `0d4925e5` (`build: reject dirty worktree in build.sh; record source commit in releases`).
Built from a clean tree at this commit.

> **Hashes are per-artifact, not per-commit.** Rebuilds of the same commit
> produce different SHA-256 (and slightly different sizes) because the app
> wheel embeds a build timestamp. Treat the table below as identifying one
> specific built artifact; rebuilds must be re-verified and re-recorded.

| Platform | Tarball | Size | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-offline-macos-arm64-v0.3.5.tar.gz` | 86 MB | `5c2e3b0eed6cb14dbbc56d4369e0d2cd3cd76ceba2b43bdc95791dc71dab8004` |
| Linux x64 (glibc 2.17+) | `nanobot-offline-linux-x64-v0.3.5.tar.gz` | 194 MB | `ba37cf50b1d7008f070c14ff802fdcbaf27493fb839272aea0b471a0e9c3f956` |

Tarballs live under `packaging/build/<platform>/` (git-ignored build output).

### Extras bundle (internal CLI / skills / MCP)

Same version as the main package; **cross-platform** (all assets are pure
Python/markdown, no platform binaries).

| Tarball | Size | SHA-256 |
|---|---|---|
| `nanobot-extras-v0.3.5.tar.gz` | 198 KB | `79f55fb5530b8c7c4657f683e0ebcc4b5be22ab6704571b8c7790df4997a3857` |

Built from source commit `82373448`; carries its own `BUILD-INFO.txt`.
Lives under `packaging/build/extras/` (git-ignored). Assets are **not**
versioned (internal IPs/GUIDs + MCP credentials, and this repo has a GitHub
remote) — reproduce them with `packaging/extras/stage-assets.sh`, then
`packaging/build-extras.sh`.

Install: `bash install-extras.sh <nanobot-prefix> <workspace>` (offline).
Contents: 3 CLI Apps (`dct-north-cli`, `cli-anything-asset-historical-data`,
`chart`), 6 skills, the `fastgpt-knowledge` MCP server.

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
