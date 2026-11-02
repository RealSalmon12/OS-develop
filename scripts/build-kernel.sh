#!/usr/bin/env bash
# 리눅스 커널을 받아서 QEMU용으로 빌드합니다. 결과: out/bzImage
set -euo pipefail
source "$(dirname "$0")/../config.sh"
mkdir -p "$BUILD_DIR" "$OUT_DIR"
cd "$BUILD_DIR"

if [ -n "${KERNEL_TARBALL:-}" ]; then
  tarball="$KERNEL_TARBALL"
else
  major="${KERNEL_VERSION%%.*}"
  tarball="$BUILD_DIR/linux-$KERNEL_VERSION.tar.xz"
  if [ ! -f "$tarball" ]; then
    echo ">> 커널 $KERNEL_VERSION 다운로드"
    curl -fL -o "$tarball.part" \
      "https://cdn.kernel.org/pub/linux/kernel/v$major.x/linux-$KERNEL_VERSION.tar.xz"
    mv "$tarball.part" "$tarball"
  fi
fi

src="$BUILD_DIR/linux"
if [ ! -f "$src/Makefile" ]; then
  echo ">> 커널 소스 풀기: $tarball"
  rm -rf "$src" && mkdir -p "$src"
  tar -xf "$tarball" -C "$src" --strip-components=1
fi

cd "$src"
echo ">> 커널 설정 (x86_64 defconfig + KVM 게스트 + $OS_NAME 설정)"
make -s ARCH=x86_64 defconfig
make -s ARCH=x86_64 kvm_guest.config
./scripts/kconfig/merge_config.sh -m .config "$ROOT_DIR/kernel/myos.config" >/dev/null
make -s ARCH=x86_64 olddefconfig
sed -i "s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"-${OS_HOSTNAME}\"/" .config

echo ">> 커널 빌드 (-j$JOBS), 처음에는 몇 분 걸려요"
make ARCH=x86_64 -j"$JOBS" bzImage
cp arch/x86/boot/bzImage "$OUT_DIR/bzImage"
echo ">> 완료: $OUT_DIR/bzImage"
