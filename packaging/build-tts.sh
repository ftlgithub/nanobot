#!/bin/bash
# One-click TTS offline bundle builder.
# Usage: packaging/build-tts.sh [macos|linux]
# Network IS required here (model + wheels already cached locally preferred).
# The produced tarballs install with zero network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLATFORM="${1:-macos}"
VERSION="$(grep -E '^version' pyproject.toml | head -1 | cut -d'"' -f2)"
PYTHON_BUILD_RELEASE="20260901"
PYTHON_BUILD_BASE_LINUX="cpython-3.11.16+${PYTHON_BUILD_RELEASE}-x86_64-unknown-linux-gnu-install_only"

# macOS tarballs must not carry AppleDouble files.
export COPYFILE_DISABLE=1

die() { echo "build-tts: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing: $1"; }

TTS_SRC="${NANOBOT_TTS_SRC:-$HOME/.nanobot/workspace/chrome-extension/tts-server}"
MODEL_SRC="${NANOBOT_TTS_MODEL:-$HOME/.cache/huggingface/hub/models--mlx-community--Qwen3-TTS-12Hz-1.7B-CustomVoice-6bit}"

build_linux() {
  need gh
  local dir="packaging/build/tts/linux-x64"
  local name="nanobot-tts-linux-x64-v${VERSION}"
  local stage="$dir/$name"
  local lock="packaging/tts/requirements-linux-x64.txt"
  local model_src="${NANOBOT_TTS_MODEL_LINUX:-/tmp/tts-ms-model/Qwen3-TTS-12Hz-1.7B-CustomVoice}"
  # pip evaluates env markers (e.g. gradio's audioop-lts, py>=3.13 only) against
  # the *running* interpreter, ignoring --python-version, so wheel downloads must
  # run under Python <3.13. Override with NANOBOT_DL_PYTHON when needed.
  local dl_python="${NANOBOT_DL_PYTHON:-}"
  if [ -z "$dl_python" ]; then
    for c in python3.11 python3.12 python3; do
      if command -v "$c" >/dev/null 2>&1; then dl_python="$c"; break; fi
    done
  fi
  [ -n "$dl_python" ] || die "no python available for wheel download"

  [ -f "$TTS_SRC/main.py" ] || die "TTS service not found: $TTS_SRC/main.py"
  [ -f "$lock" ] || die "missing lock: $lock"
  [ -f "$model_src/config.json" ] || die "Linux model incomplete: missing $model_src/config.json"
  shopt -s nullglob
  local weights=("$model_src"/*.safetensors)
  shopt -u nullglob
  [ "${#weights[@]}" -gt 0 ] || die "Linux model incomplete: no top-level *.safetensors in $model_src"

  echo "==> staging $name"
  rm -rf "$stage"
  mkdir -p "$stage"

  echo "==> standalone Python 3.11 (linux x86_64)"
  if [ ! -f "$dir/${PYTHON_BUILD_BASE_LINUX}.tar.gz" ]; then
    (cd "$dir" && gh release download "$PYTHON_BUILD_RELEASE" \
      --repo astral-sh/python-build-standalone \
      --pattern "${PYTHON_BUILD_BASE_LINUX}.tar.gz")
  fi
  mkdir -p "$stage/python"
  tar -xzf "$dir/${PYTHON_BUILD_BASE_LINUX}.tar.gz" -C "$stage/python"
  if [ -d "$stage/python/python" ]; then
    mv "$stage/python/python/"* "$stage/python/"
    rmdir "$stage/python/python"
  fi

  echo "==> installing locked wheels (torch CUDA needs glibc>=2.28)"
  mkdir -p "$dir/wheelhouse"
  # lock is the full linux closure (optional extras like ggml excluded at compile
  # time); --no-deps stops pip re-resolving metadata that would demand them back.
  "$stage/python/bin/python" -m pip install --quiet --no-index --no-build-isolation \
    --break-system-packages --no-deps \
    --find-links "$dir/wheelhouse" \
    -r "$lock" \
    || {
      echo "==> wheelhouse missing, downloading (needs network once)"
      # lock is the full linux closure; --no-deps skips re-resolution so host
      # markers (e.g. Darwin-only deps) can't poison the download.
      "$dl_python" -m pip download -r "$lock" \
        -d "$dir/wheelhouse" \
        --python-version 3.11 --abi cp311 --only-binary=:all: --no-deps \
        --platform manylinux_2_28_x86_64 \
        --platform manylinux_2_27_x86_64 \
        --platform manylinux_2_26_x86_64 \
        --platform manylinux_2_25_x86_64 \
        --platform manylinux_2_24_x86_64 \
        --platform manylinux_2_23_x86_64 \
        --platform manylinux_2_22_x86_64 \
        --platform manylinux_2_21_x86_64 \
        --platform manylinux_2_20_x86_64 \
        --platform manylinux_2_19_x86_64 \
        --platform manylinux_2_18_x86_64 \
        --platform manylinux_2_17_x86_64 \
        --platform manylinux2014_x86_64 \
        --platform manylinux1_x86_64 \
        --platform any -q
      "$stage/python/bin/python" -m pip install --quiet --no-index --no-build-isolation \
        --break-system-packages --no-deps \
        --find-links "$dir/wheelhouse" \
        -r "$lock"
    }

  echo "==> copying service source (no __pycache__)"
  mkdir -p "$stage/service"
  for f in main.py llm_bridge.py mlx_guard.py text_chunk.py tts_budget.py warmup.py requirements.txt; do
    [ -f "$TTS_SRC/$f" ] || die "missing service file: $TTS_SRC/$f"
    cp "$TTS_SRC/$f" "$stage/service/"
  done

  echo "==> copying original Linux model weights"
  mkdir -p "$stage/models"
  cp -r "$model_src" "$stage/models/Qwen3-TTS-12Hz-1.7B-CustomVoice"

  echo "==> PM2 config + install doc + provenance"
  cp packaging/tts/ecosystem.tts.config.js "$stage/"
  cp packaging/tts/INSTALL.linux.md "$stage/安装说明.md"
  {
    echo "package: $name"
    echo "version: $VERSION"
    echo "source_commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "service_src: $TTS_SRC"
    echo "model: Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice (about 3.5GB bf16)"
    echo "backend: faster-qwen3-tts (torch/CUDA-capable; CPU fallback depends on target)"
    echo "glibc_floor: 2.28 (torch 2.14 manylinux wheels)"
    echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "platform: linux-x64"
  } > "$stage/BUILD-INFO.txt"

  echo "==> packing"
  find "$stage" -name '.DS_Store' -delete
  (cd "$dir" && tar -czf "$name.tar.gz" "$name" && shasum -a 256 "$name.tar.gz" | tee SHA256SUMS)
  du -sh "$dir/$name.tar.gz"
  echo "done."
}

case "$PLATFORM" in
  linux)
    build_linux
    exit 0
    ;;
  macos)
    ;;
  *)
    die "usage: packaging/build-tts.sh [macos|linux]"
    ;;
esac


# Reproducible provenance: refuse a dirty tree unless explicitly allowed.
if [ "${ALLOW_DIRTY:-}" != "1" ] && [ -n "$(git status --porcelain 2>/dev/null | grep -vE 'docx|\.omo' || true)" ]; then
  echo "build-tts: working tree is dirty: commit first (or set ALLOW_DIRTY=1 for test builds)" >&2
  exit 1
fi

[ -f "$TTS_SRC/main.py" ] || die "TTS service not found: $TTS_SRC/main.py"
[ -d "$MODEL_SRC/blobs" ] || die "MLX model not found: $MODEL_SRC"
[ -f "packaging/tts/requirements-macos-arm64.txt" ] || die "missing lock: packaging/tts/requirements-macos-arm64.txt"

OUT="packaging/build/tts/macos-arm64"
NAME="nanobot-tts-macos-arm64-v${VERSION}"
STAGE="$OUT/$NAME"

echo "==> staging $NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE"

echo "==> standalone Python (uv-managed 3.11)"
PYBASE="$HOME/.local/share/uv/python/cpython-3.11-macos-aarch64-none"
[ -x "$PYBASE/bin/python" ] || die "uv Python 3.11 not found: $PYBASE"
cp -r "$PYBASE" "$STAGE/python"

echo "==> installing locked wheels (offline-capable set)"
"$STAGE/python/bin/python" -m pip install --quiet --no-index --no-build-isolation \
  --break-system-packages \
  --find-links packaging/build/tts/macos-arm64/wheelhouse \
  -r packaging/tts/requirements-macos-arm64.txt \
  || {
    echo "==> wheelhouse missing, downloading (needs network once)"
    mkdir -p packaging/build/tts/macos-arm64/wheelhouse
    python3 -m pip download -r packaging/tts/requirements-macos-arm64.txt \
      -d packaging/build/tts/macos-arm64/wheelhouse \
      --python-version 311 --abi cp311 --only-binary=:all: -q
    "$STAGE/python/bin/python" -m pip install --quiet --no-index --no-build-isolation \
      --break-system-packages \
      --find-links packaging/build/tts/macos-arm64/wheelhouse \
      -r packaging/tts/requirements-macos-arm64.txt
  }

echo "==> copying service source (no __pycache__)"
mkdir -p "$STAGE/service"
for f in main.py llm_bridge.py mlx_guard.py text_chunk.py tts_budget.py warmup.py requirements.txt; do
  [ -f "$TTS_SRC/$f" ] || die "missing service file: $TTS_SRC/$f"
  cp "$TTS_SRC/$f" "$STAGE/service/"
done

echo "==> copying MLX model into the HF hub cache layout"
# HF_HOME points at models/, and huggingface_hub resolves caches from <HF_HOME>/hub/
# -- a flat models/models--* layout makes the service try to download instead.
# cp -R (not -r) keeps the snapshots' relative symlinks into blobs/, which is what
# stops the 2.5GB model turning into a 5GB bundle.
mkdir -p "$STAGE/models/hub"
cp -R "$MODEL_SRC" "$STAGE/models/hub/models--mlx-community--Qwen3-TTS-12Hz-1.7B-CustomVoice-6bit"

echo "==> PM2 config + install doc + provenance"
cp packaging/tts/ecosystem.tts.config.js "$STAGE/"
cp packaging/tts/INSTALL.md "$STAGE/安装说明.md"
{
  echo "package: $NAME"
  echo "version: $VERSION"
  echo "source_commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "service_src: $TTS_SRC"
  echo "model: mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-6bit (2.5GB)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "platform: macos-arm64 (MLX)"
} > "$STAGE/BUILD-INFO.txt"

echo "==> packing"
find "$STAGE" -name '.DS_Store' -delete
(cd "$OUT" && tar -czf "$NAME.tar.gz" "$NAME" && shasum -a 256 "$NAME.tar.gz" | tee SHA256SUMS)
du -sh "$OUT/$NAME.tar.gz"
echo "done."
