# Offline installer releases

## v0.3.5 (2026-09-16, fork main + offline packaging)

Source commit: `690bd530` (`build: reject dirty worktree in build.sh; record source commit in releases`).
Built from a clean tree at this commit.

> **Hashes are per-artifact, not per-commit.** Rebuilds of the same commit
> produce different SHA-256 (and slightly different sizes) because the app
> wheel embeds a build timestamp. Treat the table below as identifying one
> specific built artifact; rebuilds must be re-verified and re-recorded.

| Platform | Tarball | Size | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-offline-macos-arm64-v0.3.5.tar.gz` | 86 MB | `05949ba9880118a70fbd6d9d4c4517eba0439240614247d4af6a2ca71a79a013` |
| Linux x64 (glibc 2.17+) | `nanobot-offline-linux-x64-v0.3.5.tar.gz` | 194 MB | `51bc62c0ff84bb8bac8c3c9a04db3b0e7ead526ae3cfd0561fd3e8fc894f1127` |

Tarballs live under `packaging/build/<platform>/` (git-ignored build output).

### Extras bundle (internal CLI / skills / MCP)

Same version as the main package; **cross-platform** (all assets are pure
Python/markdown, no platform binaries).

| Tarball | Size | SHA-256 |
|---|---|---|
| `nanobot-extras-v0.3.5.tar.gz` | 198 KB | `84cdae62b8d21cf6353333679afe184e85c279600d2ca49f51b6930270807ef0` |

Built from source commit `690bd530`; carries its own `BUILD-INFO.txt`.
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

### Verification (2026-09-17)

- macOS: fresh-extract + clean-HOME install → `nanobot v0.3.5`, modules OK;
  gateway smoke (bootstrap → new_chat → message → session.delete →
  health) PASS.
- Linux: `ubuntu:22.04` amd64 container, `--network none` → install OK;
  same smoke chain PASS (`deleted:true`, `health ok/running`).
- Import sweep on installed package: 324 modules OK; 7 failures are all
  known optional extras (aiohttp/api, matrix, slack, telegram, Windows-only).
- **Extras bundle** (same commit): macOS clean HOME + Linux `--network none`
  container — install exit 0 and idempotent on re-run; `run_cli_app` invoked
  all three CLI apps (`dct-north-cli`, `cli-anything-asset-historical-data`,
  `chart`); the 6 skills load with no duplicates and no residual
  `dct-north-cli`; the MCP server starts and lists 3 tools (gateway logs
  "connected, 3 capabilities registered"); `installed.json` carries no
  dev-machine paths and the MCP `command` points at the bundled Python.
  Both runs also re-passed the main-package smoke chain.
- Found and fixed while verifying extras: on a host with no registry cache and
  no network, `run_cli_app` crashed before reaching the local app fallback
  (upstream re-raises for required catalog sources). Fixed in
  `get_app()` — `# FORK-HOOK: fork-cli-apps-offline-catalog`.

### Known limits

- Third-party CLI Apps are not preinstalled; internal CLI/skill/MCP live in
  the separate `nanobot-extras-*` bundle (see offline-extras spec).
- No macOS x64 / Windows / Linux arm64 builds.
- Linux pins diverge from macOS for 3 compiled packages (see above);
  runtime API usage verified compatible.
- Tarball `tar` on macOS emits `LIBARCHIVE.xattr` warnings on Linux
  extraction — harmless, ignored.
