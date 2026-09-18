# STT offline bundle releases

## v0.3.5 (2026-09-18, one-click rebuild)

Source commit: `2ffe41d1e856aaa9d8e0c13b5e9a8ae21d97f123` (plus uncommitted
`packaging/build-stt.sh`).
Build script: `packaging/build-stt.sh [macos|linux|all]` (one-click; Linux
branch rebuilds whisper.cpp from source in a centos:7 container, so it runs
from any Mac with Docker — no Linux host needed).

> **Hashes are per-artifact, not per-commit** (same rule as the main
> `packaging/RELEASES.md`): rebuilds must be re-verified and re-recorded.

| Platform | Tarball | Size | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-stt-macos-arm64-v0.3.5.tar.gz` | 1.3 GB | `7b650d86d4145fe9403ee3fa318696f4d467bcaf421b4104543f13f2b9e643a9` |
| Linux x64 (glibc ≤ 2.14) | `nanobot-stt-linux-x64-v0.3.5.tar.gz` | 1.4 GB | `d61ef0a01a426e24649daae6829c0bc9aba7341bf4bd76e8f65d1c1d8f67cceb` |

Tarballs live under `packaging/build/stt/` (git-ignored build output);
`SHA256SUMS` next to them (`shasum -c` passes).

### Contents (per tarball)

- `whisper-server` (whisper.cpp v1.9.1) + versioned runtime libs +
  `start-whisper.sh` (executable bit set by the script)
- `ggml-medium.bin` (1.5 GB, sha256
  `6c14d5ad...9c156208`, byte-identical to production `~/.whisper/models/`)
- Static ffmpeg (for `--convert`): macOS evermeet 7.1.1-tessus (intel,
  Rosetta on arm64); Linux johnvansickle static (rolling release)
- `ecosystem.stt.config.js`, `INSTALL.md`, per-platform `BUILD-INFO-*.txt`

### Verification (2026-09-18)

- macOS (this machine): server ready after ~10 s; test clip
  ("你好，这是一个语音转写测试") → `{"text":"你好,这是一个语音转写测试。\n"}`.
  `otool -L` shows zero absolute `/opt/homebrew` refs (rpath fix verified).
- Linux (`centos:7` amd64 container): `ldd` clean (all libs resolve from
  bundled `lib/`); server ready after ~10 s; same clip → identical Chinese
  text. Binary + lib max out at `GLIBC_2.14` (below the 2.17 floor).
- Model sha gate passes in the script before packing.

### Deltas vs the 2026-09-17 manual build

- macOS libs moved brew 0.15.1-era set → current brew (whisper.cpp still
  1.9.1, binary byte-identical; ggml now 0.16.0 and ships no Metal/blas/
  cpu-apple backend `.so`, so this build is CPU-fallback — transcribe test
  still passes, ~10 s startup).
- macOS previously staged two absolute brew rpaths (`libggml`,
  `libggml-base`); the script now rewrites all `/opt/homebrew` refs to
  `@rpath` (clean-Mac-safe).
- Linux is a fresh source rebuild (same v1.9.1 tag, same flags); ffmpeg and
  model bytes unchanged.
- `BUILD-INFO.txt` is now per-platform (`BUILD-INFO-<platform>.txt` at build
  root, copied to `BUILD-INFO.txt` inside each tarball).
