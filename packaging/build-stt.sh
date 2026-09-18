#!/bin/bash
# One-click STT offline bundle builder.
# Usage: packaging/build-stt.sh [macos|linux|all]
# Network IS required here (ffmpeg downloads, Linux source build).
# The produced tarballs install with zero network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLATFORM="${1:-all}"
VERSION="$(grep -E '^version' pyproject.toml | head -1 | cut -d'"' -f2)"
WHISPER_VERSION="1.9.1"
MODEL_SHA="6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208"
MODEL_SRC="${NANOBOT_STT_MODEL:-$HOME/.whisper/models/ggml-medium.bin}"
FFMPEG_MAC_URL="https://evermeet.cx/ffmpeg/ffmpeg-7.1.1.7z"
FFMPEG_LINUX_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"

# macOS tarballs must not carry AppleDouble files.
export COPYFILE_DISABLE=1

die() { echo "build-stt: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing: $1"; }

DIR="packaging/build/stt"

check_model() {
  [ -f "$MODEL_SRC" ] || die "STT model not found: $MODEL_SRC"
  local sha
  sha="$(shasum -a 256 "$MODEL_SRC" | cut -d' ' -f1)"
  [ "$sha" = "$MODEL_SHA" ] || die "model sha mismatch: got $sha, want $MODEL_SHA"
}

pack_platform() {
  # $1 = macos-arm64 | linux-x64 ; stage dir $DIR/$1 already holds bin/lib/start-whisper.sh
  local platform="$1"
  local name="nanobot-stt-${platform}-v${VERSION}"
  local stage="$DIR/$platform"

  [ -x "$stage/bin/whisper-server" ] || die "missing binary: $stage/bin/whisper-server"
  [ -x "$stage/bin/ffmpeg" ] || die "missing ffmpeg: $stage/bin/ffmpeg"
  chmod +x "$stage/start-whisper.sh"

  echo "==> copying model + docs"
  cp "$MODEL_SRC" "$DIR/ggml-medium.bin"
  cp packaging/stt/ecosystem.stt.config.js "$DIR/"
  cp packaging/stt/INSTALL.md "$DIR/"

  echo "==> PM2 config + install doc + provenance"
  {
    echo "package: $name"
    echo "version: $VERSION"
    echo "source_commit: $(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "dirty: $(git status --porcelain 2>/dev/null | grep -q . && echo dirty || echo clean)"
    echo "whisper: v$WHISPER_VERSION"
    echo "model: ggml-medium.bin (sha256 $MODEL_SHA)"
    echo "ffmpeg: $2"
    echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "platform: $platform"
  } > "$DIR/BUILD-INFO-$platform.txt"
  cp "$DIR/BUILD-INFO-$platform.txt" "$DIR/BUILD-INFO.txt"

  echo "==> packing"
  (cd "$DIR" && tar -czf "$name.tar.gz" "$platform" ggml-medium.bin ecosystem.stt.config.js INSTALL.md BUILD-INFO.txt \
    && { grep -v "$name.tar.gz" SHA256SUMS 2>/dev/null || true; shasum -a 256 "$name.tar.gz"; } > SHA256SUMS.new \
    && mv SHA256SUMS.new SHA256SUMS)
  du -sh "$DIR/$name.tar.gz"
  echo "done."
}

build_macos() {
  need cmake
  need codesign
  xcode-select -p >/dev/null 2>&1 || die "Xcode command line tools required"
  local platform="macos-arm64"
  local name="nanobot-stt-${platform}-v${VERSION}"
  local stage="$DIR/$platform"

  check_model

  echo "==> staging $name"
  rm -rf "$stage"
  mkdir -p "$stage/bin"

  echo "==> whisper.cpp v$WHISPER_VERSION source build (static + Metal)"
  local src_tgz="$DIR/whisper.cpp-v$WHISPER_VERSION.tar.gz"
  if [ ! -f "$src_tgz" ]; then
    (cd "$DIR" && curl -sSL --retry 5 --max-time 600 -o "whisper.cpp-v$WHISPER_VERSION.tar.gz" "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v$WHISPER_VERSION.tar.gz")
  fi
  tar -tzf "$src_tgz" >/dev/null || die "whisper tarball corrupt: $src_tgz"
  local builddir="$DIR/macos-build"
  rm -rf "$builddir"
  mkdir -p "$builddir/src"
  tar -xzf "$src_tgz" -C "$builddir/src"
  # static link + Metal compiled in + no OpenMP (falls back to system Accelerate):
  # a brew-derived bundle cannot be made self-contained because ggml only looks
  # for its backend plugins at a compile-time libexec path (no env override).
  cmake -S "$builddir/src/whisper.cpp-$WHISPER_VERSION" -B "$builddir/cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DGGML_METAL=ON \
    -DGGML_OPENMP=OFF > "$builddir/cmake.log" 2>&1 \
    || { tail -25 "$builddir/cmake.log" >&2; die "cmake configure failed"; }
  cmake --build "$builddir/cmake" --target whisper-server -j"$(sysctl -n hw.ncpu)" \
    >> "$builddir/cmake.log" 2>&1 \
    || { tail -25 "$builddir/cmake.log" >&2; die "cmake build failed"; }
  cp "$builddir/cmake/bin/whisper-server" "$stage/bin/"
  chmod +x "$stage/bin/whisper-server"
  rm -rf "$builddir"

  echo "==> asserting no non-system dependencies"
  local deps
  deps="$(otool -L "$stage/bin/whisper-server" | grep -E '^[[:space:]]+(/opt/homebrew|/usr/local)' || true)"
  [ -z "$deps" ] || die "binary references non-system paths: $deps"

  echo "==> ad-hoc signing"
  codesign --force --sign - "$stage/bin/whisper-server" >/dev/null 2>&1 \
    || die "codesign failed"
  codesign -v "$stage/bin/whisper-server" >/dev/null 2>&1 || die "signature invalid"

  echo "==> static ffmpeg (evermeet 7.1.1, cached binary preferred)"
  local ffmpeg_cache="$DIR/ffmpeg-macos-7.1.1"
  if [ -x "$ffmpeg_cache" ]; then
    echo "using cached ffmpeg binary"
    cp "$ffmpeg_cache" "$stage/bin/ffmpeg"
  else
    need 7z
    local ffmpeg_7z="$DIR/ffmpeg-7.1.1.7z"
    if [ ! -f "$ffmpeg_7z" ]; then
      (cd "$DIR" && curl -sSL --retry 2 --max-time 600 -o ffmpeg-7.1.1.7z "$FFMPEG_MAC_URL")
    fi
    local tmpd
    tmpd="$(mktemp -d)"
    7z x -o"$tmpd" "$ffmpeg_7z" ffmpeg >/dev/null
    cp "$tmpd/ffmpeg" "$stage/bin/ffmpeg"
    rm -rf "$tmpd"
  fi
  chmod +x "$stage/bin/ffmpeg"
  "$stage/bin/ffmpeg" -version 2>/dev/null | head -1 | grep -q "7.1.1-tessus" \
    || die "unexpected macOS ffmpeg version"

  cp packaging/stt/start-whisper.sh "$stage/"
  pack_platform "$platform" "evermeet 7.1.1-tessus static (intel, Rosetta on arm64); whisper.cpp static, Metal"
}

build_linux() {
  need docker
  local platform="linux-x64"
  local name="nanobot-stt-${platform}-v${VERSION}"
  local stage="$DIR/$platform"

  check_model
  docker info >/dev/null 2>&1 || die "docker daemon not running"

  echo "==> staging $name"
  rm -rf "$stage"
  mkdir -p "$stage/bin" "$stage/lib"

  echo "==> static ffmpeg (johnvansickle, cached binary preferred)"
  local ffmpeg_cache="$DIR/ffmpeg-linux-amd64-static"
  if [ -x "$ffmpeg_cache" ]; then
    echo "using cached ffmpeg binary"
    cp "$ffmpeg_cache" "$stage/bin/ffmpeg"
  else
    local ffmpeg_txz="$DIR/ffmpeg-release-amd64-static.tar.xz"
    if [ ! -f "$ffmpeg_txz" ]; then
      (cd "$DIR" && curl -sSL --retry 2 --max-time 600 -o ffmpeg-release-amd64-static.tar.xz "$FFMPEG_LINUX_URL")
    fi
    local tmpd
    tmpd="$(mktemp -d)"
    tar -xf "$ffmpeg_txz" -C "$tmpd"
    cp "$tmpd"/ffmpeg-*-amd64-static/ffmpeg "$stage/bin/ffmpeg"
    rm -rf "$tmpd"
  fi
  chmod +x "$stage/bin/ffmpeg"
  local ffmpeg_ver
  ffmpeg_ver="$("$stage/bin/ffmpeg" -version 2>/dev/null | head -1 || true)"
  if [ -z "$ffmpeg_ver" ]; then
    ffmpeg_ver="$(strings "$stage/bin/ffmpeg" 2>/dev/null | grep -m1 -E '^ffmpeg version ' || echo unknown)"
  fi

  echo "==> whisper.cpp v$WHISPER_VERSION source build (centos:7 + devtoolset-9)"
  local builddir="$DIR/linux-build"
  rm -rf "$builddir"
  mkdir -p "$builddir"
  echo "==> whisper.cpp source tarball (cached on host)"
  local whisper_tgz="$DIR/whisper.cpp-v$WHISPER_VERSION.tar.gz"
  if [ ! -f "$whisper_tgz" ]; then
    (cd "$DIR" && curl -sSL --retry 5 --max-time 600 -o "whisper.cpp-v$WHISPER_VERSION.tar.gz" "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v$WHISPER_VERSION.tar.gz")
  fi
  tar -tzf "$whisper_tgz" >/dev/null || die "whisper tarball corrupt: $whisper_tgz"
  cp "$whisper_tgz" "$builddir/"
  docker run --rm --platform linux/amd64 \
    -v "$PWD/$builddir:/out" \
    -v "$PWD/$builddir/yumcache:/var/cache/yum" \
    centos:7 bash -c '
      set -euo pipefail
      sed -i "s|^mirrorlist=|#mirrorlist=|; s|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com/centos-vault|" /etc/yum.repos.d/CentOS-Base.repo
      printf '\nretries=20\ntimeout=120\nkeepcache=1\n' >> /etc/yum.conf
      rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 || true
      yum_retry() {
        local attempt
        for attempt in 1 2 3 4 5; do
          "$@" && return 0
          echo "yum attempt $attempt failed: $*" >&2
          sleep 10
        done
        return 1
      }
      yum_retry yum install -y -q --nogpgcheck centos-release-scl-rh
      sed -i "s|^mirrorlist=|#mirrorlist=|; s|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com/centos-vault|" /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
      rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo || true
      yum_retry yum install -y -q --nogpgcheck https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm
      rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 || true
      sed -i "s|^mirrorlist=|#mirrorlist=|; s|^#baseurl=http://download.fedoraproject.org/pub/epel|baseurl=https://archives.fedoraproject.org/pub/archive/epel|" /etc/yum.repos.d/epel.repo
      yum clean all -q
      yum_retry yum install -y -q devtoolset-9-gcc devtoolset-9-gcc-c++ make cmake3 libgomp
      rpm -q devtoolset-9-gcc make cmake3 libgomp >/dev/null 2>&1 || { echo "build-stt: toolchain install failed" >&2; exit 1; }
      set +u
      source /opt/rh/devtoolset-9/enable
      set -u
      cmake3 --version
      cd /tmp && rm -rf whisper.cpp
      tar -xzf /out/whisper.cpp-v'"$WHISPER_VERSION"'.tar.gz -C /tmp
      mv /tmp/whisper.cpp-'"$WHISPER_VERSION"' /tmp/whisper.cpp
      cmake3 /tmp/whisper.cpp -B /tmp/whisper.cpp/build -DWHISPER_BUILD_TESTS=OFF -DBUILD_SHARED_LIBS=ON
      cmake3 --build /tmp/whisper.cpp/build --target whisper-server -j"$(nproc)"
      cp /tmp/whisper.cpp/build/bin/whisper-server /out/
      find /tmp/whisper.cpp/build \( -name 'libwhisper.so.*' -o -name 'libggml*.so.*' \) -exec cp {} /out/ \;
      ls /out/libwhisper.so* >/dev/null 2>&1 || { echo "build-stt: no shared whisper libs produced" >&2; exit 1; }
      cp /usr/lib64/libgomp.so.1* /out/
    '
  cp "$builddir/whisper-server" "$stage/bin/"
  chmod +x "$stage/bin/whisper-server"
  cp "$builddir"/lib*.so* "$stage/lib/" 2>/dev/null || true
  rm -rf "$builddir"

  cp packaging/stt/start-whisper.sh "$stage/"
  pack_platform "$platform" "johnvansickle static ($ffmpeg_ver)"
}

case "$PLATFORM" in
  macos)
    build_macos
    ;;
  linux)
    build_linux
    ;;
  all)
    build_macos
    build_linux
    ;;
  *)
    die "usage: packaging/build-stt.sh [macos|linux|all]"
    ;;
esac
