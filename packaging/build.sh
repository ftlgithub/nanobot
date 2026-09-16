#!/bin/bash
# One-click dual-platform offline tarball builder.
# Usage: packaging/build.sh [macos|linux|all]
# Network IS required here (build machine fetches wheels/TUI/Python).
# The produced tarballs install with zero network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLATFORM="${1:-all}"
VERSION="$(grep -E '^version' pyproject.toml | head -1 | cut -d'"' -f2)"
PY312="3.12"
TUI_VERSION="v0.3.5"
PYTHON_BUILD_RELEASE="20260901"
PYTHON_BUILD_BASE="cpython-3.12.14+${PYTHON_BUILD_RELEASE}-x86_64-unknown-linux-gnu-install_only"

# macOS tarballs must not carry AppleDouble files (they spam Linux tar).
export COPYFILE_DISABLE=1

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }

# Fail fast on stale inputs: WebUI dist must be newer than all sources,
# and both TUI zips must exist (see packaging/tui-binaries/README.md).
check_inputs() {
  if [ -n "$(find webui/src -newer nanobot/web/dist/index.html -type f 2>/dev/null | head -1)" ]; then
    echo "webui dist is stale: run 'cd webui && bun run build' first" >&2; exit 1
  fi
  for z in nanobot/tui/bin/nanobot-tui-darwin-arm64.zip nanobot/tui/bin/nanobot-tui-linux-x64.zip; do
    [ -f "$z" ] || { echo "missing $z (see packaging/tui-binaries/README.md)" >&2; exit 1; }
  done
}

check_inputs

build_wheelhouse() { # $1=build_dir $2=lock $3..=extra pip-download flags
  local dir="$1" lock="$2"; shift 2
  mkdir -p "$dir/nanobot-offline/wheelhouse"
  python3 -m pip download -r "packaging/locks/$lock" \
    -d "$dir/nanobot-offline/wheelhouse" \
    --python-version 3.12 --abi cp312 --only-binary=:all: "$@" -q
  python3 -m pip wheel . --no-deps -w "$dir/nanobot-offline/wheelhouse" -q
}

stage_common() { # $1=build_dir $2=lock-name $3=tui-asset
  local dir="$1"
  mkdir -p "$dir/nanobot-offline/tui"
  cp packaging/install.sh "$dir/nanobot-offline/install.sh"
  cp "packaging/locks/$2" "$dir/nanobot-offline/requirements.txt"
}

build_macos() {
  local dir="packaging/build/macos-arm64"
  echo "==> macOS arm64"
  need uv
  uv python install 3.12 -q 2>/dev/null || true
  local pypy
  pypy="$(uv python find 3.12)"
  local pydir
  pydir="$(dirname "$(dirname "$pypy")")"
  rm -rf "$dir/nanobot-offline"
  mkdir -p "$dir/nanobot-offline"
  cp -r "$pydir" "$dir/nanobot-offline/python"
  build_wheelhouse "$dir" "requirements-macos-arm64.txt"
  unzip -o -q nanobot/tui/bin/nanobot-tui-darwin-arm64.zip \
    nanobot-tui-darwin-arm64 -d "$dir/nanobot-offline/tui/"
  chmod +x "$dir/nanobot-offline/tui/nanobot-tui-darwin-arm64"
  stage_common "$dir" "requirements-macos-arm64.txt" _
  (cd "$dir" && tar -czf "nanobot-offline-macos-arm64-v${VERSION}.tar.gz" nanobot-offline \
    && shasum -a 256 "nanobot-offline-macos-arm64-v${VERSION}.tar.gz" | tee SHA256SUMS)
}

build_linux() {
  local dir="packaging/build/linux-x64"
  echo "==> Linux x64"
  need gh
  rm -rf "$dir/nanobot-offline"
  mkdir -p "$dir/nanobot-offline"
  if [ ! -f "$dir/${PYTHON_BUILD_BASE}.tar.gz" ]; then
    (cd "$dir" && gh release download "$PYTHON_BUILD_RELEASE" \
      --repo astral-sh/python-build-standalone \
      --pattern "${PYTHON_BUILD_BASE}.tar.gz")
  fi
  mkdir -p "$dir/nanobot-offline/python"
  tar -xzf "$dir/${PYTHON_BUILD_BASE}.tar.gz" -C "$dir/nanobot-offline/python"
  if [ -d "$dir/nanobot-offline/python/python" ]; then
    mv "$dir/nanobot-offline/python/python/"* "$dir/nanobot-offline/python/"
    rmdir "$dir/nanobot-offline/python/python"
  fi
  build_wheelhouse "$dir" "requirements-linux-x64.txt" \
    --platform manylinux2014_x86_64 --platform any
  unzip -o -q nanobot/tui/bin/nanobot-tui-linux-x64.zip \
    nanobot-tui-linux-x64 -d "$dir/nanobot-offline/tui/"
  chmod +x "$dir/nanobot-offline/tui/nanobot-tui-linux-x64"
  stage_common "$dir" "requirements-linux-x64.txt" _
  (cd "$dir" && tar -czf "nanobot-offline-linux-x64-v${VERSION}.tar.gz" nanobot-offline \
    && shasum -a 256 "nanobot-offline-linux-x64-v${VERSION}.tar.gz" | tee SHA256SUMS)
}

case "$PLATFORM" in
  macos) build_macos ;;
  linux) build_linux ;;
  all) build_macos; build_linux ;;
  *) echo "usage: $0 [macos|linux|all]" >&2; exit 1 ;;
esac
echo "done."
