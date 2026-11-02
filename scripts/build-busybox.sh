#!/usr/bin/env bash
# BusyBox(셸과 기본 명령어 묶음)를 정적 바이너리로 빌드합니다. 결과: build/busybox
set -euo pipefail
source "$(dirname "$0")/../config.sh"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [ -n "${BUSYBOX_BIN:-}" ]; then
  echo ">> 미리 준비된 BusyBox 사용: $BUSYBOX_BIN"
  cp "$BUSYBOX_BIN" "$BUILD_DIR/busybox"
  exit 0
fi

tarball="busybox-$BUSYBOX_VERSION.tar.bz2"
[ -f "$tarball" ] || curl -fL -o "$tarball" "https://busybox.net/downloads/$tarball"
rm -rf busybox-src && mkdir busybox-src
tar -xf "$tarball" -C busybox-src --strip-components=1
cd busybox-src
make -s defconfig
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
# 최신 커널 헤더에서 깨지는 tc 명령은 끕니다.
sed -i 's/^CONFIG_TC=y/# CONFIG_TC is not set/' .config
make -j"$JOBS" busybox
cp busybox "$BUILD_DIR/busybox"
echo ">> 완료: $BUILD_DIR/busybox"
