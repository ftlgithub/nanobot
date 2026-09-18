# TTS offline bundle releases

## v0.3.5 Linux x64 (2026-09-18)

Source commit: `86b2257882332164b5b171a720793c7f843eea4e`.
Build script: `packaging/build-tts.sh linux` (one-click; run inside a Linux
container when the build host is macOS, since the staged Linux Python cannot
execute on macOS).

> **Hashes are per-artifact, not per-commit** (same rule as the main
> `packaging/RELEASES.md`): rebuilds must be re-verified and re-recorded.

| Tarball | Size | SHA-256 |
|---|---|---|
| `nanobot-tts-linux-x64-v0.3.5.tar.gz` | 6.7 GB | `f7d1560ba9f683ef1de3badb09ddb6175b3a5c29b13002b7b49af7e4dcf82e91` |

Tarball lives under `packaging/build/tts/linux-x64/` (git-ignored build
output); `SHA256SUMS` next to it.

### Contents

- Standalone Python 3.11 (`python-build-standalone 20260901`, linux x86_64)
- Locked wheelhouse, 120 pins (`packaging/tts/requirements-linux-x64.txt`):
  torch 2.14.0 (CUDA 13.0), faster-qwen3-tts 0.4.0, transformers 5.17.0,
  fastapi 0.139.2, uvicorn 0.51.0. `sox` pinned to 1.4.1 (1.5.0 is sdist-only,
  no wheel). `qwentts-cpp-python` (ggml extra) deliberately excluded at compile
  time — PyPI carries no wheel; upstream ships CUDA wheels via HuggingFace
  dataset only.
- Service source from the extension `tts-server` (main.py + helpers) with two
  Linux fixes: `backend="torch"` in both `setup_kwargs`, plus `model_name` /
  `device` via `NANOBOT_TTS_MODEL_DIR` / `NANOBOT_TTS_DEVICE` env (defaults keep
  macOS behavior byte-identical). PM2 config sets both env vars to the bundle.
  `INSTALL.linux.md`, `BUILD-INFO.txt`.
- Model: `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` (bf16, ~3.9 GB incl. tokenizer),
  fetched via ModelScope.

### Verification (2026-09-18, `python:3.11-slim` amd64 container)

- Tarball SHA-256 matches `SHA256SUMS`; 59287 entries; no `.DS_Store`/`__MACOSX`.
- Service files `py_compile` clean: COMPILE_OK.
- Import sweep against staged env: fastapi / uvicorn / soundfile / numpy /
  sox / torch 2.14.0+cu130 / faster_qwen3_tts — all OK.
- `import main` now selects the torch backend (previously died demanding the
  excluded ggml package): in a GPU-less container it stops at
  `ValueError: CUDA graphs require CUDA device`, which proves ggml is gone and
  the torch path is wired. Staged service files hash-match the edited sources.
- Local model dir proven loadable: `qwen_tts` type registration +
  `AutoConfig.from_pretrained(<bundle>/models/...)` → `LOCAL_DIR_CONFIG_OK`.

### Residual (needs target GPU box)

Full `/v1/audio/speech` smoke per `INSTALL.linux.md`: PM2 start → model load →
warmup → one synthesis → `/health`. Requires NVIDIA GPU (torch CUDA-graph
path; CPU-only targets are out of scope for this bundle).
