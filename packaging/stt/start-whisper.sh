#!/bin/bash
# Start the bundled whisper-server (offline STT).
# Usage: start-whisper.sh [MODEL] [PORT] [HOST]
# Defaults match production: ggml-medium, port 9090, 127.0.0.1.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL="${1:-$HERE/../ggml-medium.bin}"
PORT="${2:-9090}"
HOST="${3:-127.0.0.1}"

# Linux bundle ships its .so files beside the binary.
if [ "$(uname)" = "Linux" ]; then
  export LD_LIBRARY_PATH="$HERE/lib:${LD_LIBRARY_PATH:-}"
fi
# whisper-server --convert shells out to ffmpeg; prefer the bundled one.
if [ -x "$HERE/bin/ffmpeg" ]; then
  export PATH="$HERE/bin:$PATH"
fi

exec "$HERE/bin/whisper-server" \
  -m "$MODEL" -l auto \
  --port "$PORT" --host "$HOST" \
  --inference-path /audio/transcriptions \
  --convert
