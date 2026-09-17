#!/bin/bash
# Build the cross-platform offline extras tarball.
# Usage: packaging/build-extras.sh
# Requires staged assets (packaging/extras/stage-assets.sh) and a clean tree.
# Network is NOT needed here (assets are local).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXTRAS="packaging/extras"
ASSETS="$EXTRAS/assets"
OUT="packaging/build/extras"
VERSION="$(grep -E '^version' pyproject.toml | head -1 | cut -d'"' -f2)"
NAME="nanobot-extras-v${VERSION}"
STAGE="$OUT/$NAME"

die() { echo "build-extras: $*" >&2; exit 1; }

# Reproducible provenance: refuse a dirty tree unless explicitly allowed
# (tarballs must be traceable to a commit).
if [ "${ALLOW_DIRTY:-}" != "1" ] && [ -n "$(git status --porcelain 2>/dev/null | grep -vE 'docx|\.omo' || true)" ]; then
  echo "build-extras: working tree is dirty: commit first (or set ALLOW_DIRTY=1 for test builds)" >&2
  exit 1
fi

# Assets are gitignored (internal content) — refuse to build an empty package.
[ -d "$ASSETS" ] || die "assets missing: run packaging/extras/stage-assets.sh first"
for check in \
  "$ASSETS/SOURCES.md" \
  "$ASSETS/cli-apps/chart/cli-chart" \
  "$ASSETS/mcp/fastgpt-knowledge/server.py" \
  "$ASSETS/mcp/fastgpt-knowledge/config.json" ; do
  [ -e "$check" ] || die "missing asset: $check"
done
[ -n "$(ls -A "$ASSETS/wheels" 2>/dev/null || true)" ] || die "no wheels staged in $ASSETS/wheels"
[ "$(ls -d "$ASSETS"/skills/*/ 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ] || die "no skills staged in $ASSETS/skills"
for f in "$EXTRAS/installer.py" "$EXTRAS/install-extras.sh" "$EXTRAS/安装说明.md"; do
  [ -f "$f" ] || die "missing build input: $f"
done

echo "==> staging $NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -r "$ASSETS" "$STAGE/assets"
cp "$EXTRAS/installer.py" "$EXTRAS/install-extras.sh" "$EXTRAS/安装说明.md" "$STAGE/"
chmod +x "$STAGE/install-extras.sh"

echo "==> writing build provenance"
{
  echo "package: $NAME"
  echo "version: $VERSION"
  echo "source_commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "platform: cross-platform (pure Python/markdown assets)"
} > "$STAGE/BUILD-INFO.txt"

echo "==> packing"
(cd "$OUT" && tar -czf "$NAME.tar.gz" "$NAME" && shasum -a 256 "$NAME.tar.gz" | tee SHA256SUMS)
du -sh "$OUT/$NAME.tar.gz"
echo "done."
