# STT offline bundle releases

## v0.3.5 (2026-09-18, one-click rebuild)

Source commit: `d92d679a28df9e6d657bdd3b4ac2e72b367df097` (plus uncommitted
`packaging/build-stt.sh`).
Build script: `packaging/build-stt.sh [macos|linux|all]` — both branches compile
whisper.cpp v1.9.1 from source: macOS natively (needs `cmake` + Xcode CLT),
Linux in a `centos:7` container (needs Docker, so it runs from any Mac).

> **Hashes are per-artifact, not per-commit** (same rule as the main
> `packaging/RELEASES.md`): rebuilds must be re-verified and re-recorded.

| Platform | Tarball | Size | SHA-256 |
|---|---|---|---|
| macOS arm64 | `nanobot-stt-macos-arm64-v0.3.5.tar.gz` | 1.3 GB | `502d398af037e6d1e217741b20468215a42b0cb8ef927a471aa38d39c2ab69c9` |
| Linux x64 (glibc ≤ 2.14) | `nanobot-stt-linux-x64-v0.3.5.tar.gz` | 1.4 GB | `d61ef0a01a426e24649daae6829c0bc9aba7341bf4bd76e8f65d1c1d8f67cceb` |

Tarballs live under `packaging/build/stt/` (git-ignored build output);
`SHA256SUMS` next to them (`shasum -c` passes).

### Contents (per tarball)

- `whisper-server` (whisper.cpp v1.9.1) + `start-whisper.sh` (executable bit set
  by the script)
- macOS: **single self-contained binary** (static libs, Metal compiled in, no
  `lib/` dir); Linux: binary + versioned `.so` files in `lib/`
- `ggml-medium.bin` (1.5 GB, sha256
  `6c14d5ad...9c156208`, byte-identical to production `~/.whisper/models/`)
- Static ffmpeg (for `--convert`): macOS evermeet 7.1.1-tessus (intel,
  Rosetta on arm64); Linux johnvansickle static (rolling release)
- `ecosystem.stt.config.js`, `INSTALL.md`, per-platform `BUILD-INFO-*.txt`

### Verification (2026-09-18)

- macOS: `otool -L` lists **only system frameworks** (Accelerate, Metal,
  MetalKit, CoreFoundation, `libSystem`, `libc++`, `libobjc`) — no
  `/opt/homebrew` or `/usr/local` refs, asserted by the build. Running the
  server under `DYLD_PRINT_LIBRARIES=1` loads **zero** `/opt/homebrew` images.
  Metal is active (`ggml_metal_device_init: GPU name: MTL0 (Apple M4)`); ready
  after ~10 s; test clip ("你好，这是一个语音转写测试") →
  `{"text":"你好,这是一个语音转写测试。\n"}`.
- Linux (`centos:7` amd64 container): `ldd` clean (all libs resolve from
  bundled `lib/`); server ready after ~10 s; same clip → identical Chinese
  text. Binary + lib max out at `GLIBC_2.14` (below the 2.17 floor).
- Model sha gate passes in the script before packing.

### Why macOS is source-built (not assembled from brew)

An earlier assembly-from-brew attempt was **unshippable**: ggml loads its
backend plugins only from a **compile-time path**
(`/opt/homebrew/Cellar/ggml/<ver>/libexec`), with no environment override and
no fallback to the app directory — verified by hiding that directory, after
which the process aborted in `make_buft_list`. Copying the plugins into the
bundle therefore does nothing, so a brew-derived bundle dies on a clean Mac.
Compiling with `BUILD_SHARED_LIBS=OFF -DGGML_METAL=ON -DGGML_OPENMP=OFF` yields
one self-contained signed binary and removes the plugin, `libomp`, rpath and
re-signing problems entirely.

Two other assembly-era defects are worth remembering, because they were silent:
`otool -L` indents install names with a tab, so an anchored `grep '^/opt/homebrew'`
matches nothing and any "no absolute refs" check built on it is worthless; and
`install_name_tool` invalidates brew's code signature, after which macOS
SIGKILLs the process on load (exit 137) until it is ad-hoc re-signed.

### Deltas vs the 2026-09-17 manual build

- macOS switched from brew-assembly to a source build: the old bundle carried
  absolute `/opt/homebrew` refs, no `libomp`, and no way to reach its backend
  plugins — it would have failed on any machine without brew. The new artifact
  is self-contained **and** Metal-accelerated (the brew path was CPU-only).
- Linux is a fresh source rebuild (same v1.9.1 tag, same flags); ffmpeg and
  model bytes unchanged.
- `BUILD-INFO.txt` is per-platform (`BUILD-INFO-<platform>.txt` at build root,
  copied to `BUILD-INFO.txt` inside each tarball).
