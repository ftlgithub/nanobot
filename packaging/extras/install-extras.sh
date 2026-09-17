#!/bin/bash
# Thin wrapper: locate the target nanobot's bundled Python, then run installer.py.
# All logic lives in installer.py; this only solves "which interpreter?".
#
# Usage: install-extras.sh [<nanobot-prefix>] [<workspace>] [extra installer.py flags...]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${1:-}"
WORKSPACE="${2:-}"
if [ "$#" -gt 0 ]; then shift; fi
if [ "$#" -gt 0 ]; then shift; fi

if [ -z "$PREFIX" ]; then
  NANOBOT_BIN="$(command -v nanobot || true)"
  if [ -n "$NANOBOT_BIN" ]; then
    # <prefix>/bin/nanobot -> <prefix>
    PREFIX="$(cd "$(dirname "$(readlink -f "$NANOBOT_BIN" 2>/dev/null || echo "$NANOBOT_BIN")")/.." && pwd)"
  fi
fi

PYBIN=""
if [ -n "$PREFIX" ] && [ -x "$PREFIX/python/bin/python3" ]; then
  PYBIN="$PREFIX/python/bin/python3"
elif [ -n "$PREFIX" ] && [ -x "$PREFIX/python/bin/python" ]; then
  PYBIN="$PREFIX/python/bin/python"
else
  # Let installer.py produce the proper "refusing to install into the wrong Python" error
  PYBIN="$(command -v python3 || command -v python || true)"
  if [ -z "$PYBIN" ]; then
    echo "install-extras: no Python found; pass <nanobot-prefix> explicitly" >&2
    exit 1
  fi
fi

ARGS=(--assets "$HERE/assets")
if [ -n "$PREFIX" ]; then ARGS+=(--prefix "$PREFIX"); fi
if [ -n "$WORKSPACE" ]; then ARGS+=(--workspace "$WORKSPACE"); fi

exec "$PYBIN" "$HERE/installer.py" "${ARGS[@]}" "$@"
