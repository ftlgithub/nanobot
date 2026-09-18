#!/bin/bash
# One-click TTS offline bundle builder.
# Usage: packaging/build-tts.sh [macos]   (linux comes with T03)
# Network IS required here (model + wheels already cached locally preferred).
# The produced tarball installs with zero network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLATFORM="${1:-macos}"
VERSION="$(grep -E '^version' pyproject.toml | head -1 | cut -d'"' -f2)"

# macOS tarballs must not carry AppleDouble files.
export COPYFILE_DISABLE=1

die() { echo "build-tts: $*" >&2; exit 1; }

# Reproducible provenance: refuse a dirty tree unless explicitly allowed.
if [ "${ALLOW_DIRTY:-}" != "1" ] && [ -n "$(git status --porcelain 2>/dev/null | grep -vE 'docx|\.omo' || true)" ]; then
  echo "build-tts: working tree is dirty: commit first (or set ALLOW_DIRTY=1 for test builds)" >&2
  exit 1
fi

TTS_SRC="${NANOBOT_TTS_SRC:-$HOME/.nanobot/workspace/chrome-extension/tts-server}"
MODEL_SRC="${NANOBOT_TTS_MODEL:-$HOME/.cache/huggingface/hub/models--mlx-community--Qwen3-TTS-12Hz-1.7B-CustomVoice-6bit}"

[ "$PLATFORM" = "macos" ] || die "only macos supported yet (linux comes with T03)"
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

echo "==> copying MLX model (2.5GB)"
mkdir -p "$STAGE/models"
cp -r "$MODEL_SRC" "$STAGE/models/models--mlx-community--Qwen3-TTS-12Hz-1.7B-CustomVoice-6bit"

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
(cd "$OUT" && tar -czf "$NAME.tar.gz" "$NAME" && shasum -a 256 "$NAME.tar.gz" | tee SHA256SUMS)
du -sh "$OUT/$NAME.tar.gz"
echo "done."
