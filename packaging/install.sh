#!/bin/bash
# nanobot offline installer — macOS arm64 / Linux x64.
# No network required. Installs the bundled standalone Python, all locked
# wheels (no-index), the TUI binary, and verifies the install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${1:-$HOME/nanobot-offline}"

echo "==> Installing nanobot offline to $PREFIX"
mkdir -p "$PREFIX"
cp -r "$SCRIPT_DIR/python" "$PREFIX/python"
PYBIN="$PREFIX/python/bin/python"

echo "==> Installing wheels (offline, no index)..."
# --break-system-packages is safe here: this Python is bundled solely for nanobot.
# Two steps: deps from the lock first, then the app --no-deps (tolerates
# platform-specific pins that differ from the macOS lock, e.g. tiktoken).
"$PYBIN" -m pip install --quiet --no-index --no-build-isolation --break-system-packages \
  --find-links "$SCRIPT_DIR/wheelhouse" -r "$SCRIPT_DIR/requirements.txt"
"$PYBIN" -m pip install --quiet --no-index --no-build-isolation --break-system-packages --no-deps \
  --find-links "$SCRIPT_DIR/wheelhouse" nanobot-ai

SITE_PKGS=$("$PYBIN" -c "import site; print(site.getsitepackages()[0])")

echo "==> Installing TUI binary..."
mkdir -p "$SITE_PKGS/nanobot/tui/bin"
ASSET="$(ls "$SCRIPT_DIR/tui" | grep -E '^nanobot-tui-' | head -1)"
cp "$SCRIPT_DIR/tui/$ASSET" "$SITE_PKGS/nanobot/tui/bin/$ASSET"
chmod +x "$SITE_PKGS/nanobot/tui/bin/$ASSET"

echo "==> Verifying..."
"$PREFIX/python/bin/nanobot" --version
"$PYBIN" -c "import nanobot, nanobot.agent.loop, nanobot.webui.ws_http, nanobot.channels.manager; print('modules OK')"

mkdir -p "$PREFIX/bin"
ln -sf "$PREFIX/python/bin/nanobot" "$PREFIX/bin/nanobot"
ln -sf "$PREFIX/python/bin/nanobot-desktop-tui" "$PREFIX/bin/nanobot-desktop-tui" 2>/dev/null || true

echo ""
echo "Done. Add to PATH:"
echo "  export PATH=\"$PREFIX/bin:\$PATH\""
echo "Then run: nanobot gateway  (or: nanobot --help)"
