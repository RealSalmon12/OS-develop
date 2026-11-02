#!/usr/bin/env bash
# QEMU로 OS를 실행합니다.
#   ./scripts/run.sh          창 없이 터미널에서 실행 (끄기: poweroff 또는 Ctrl-A X)
#   ./scripts/run.sh --gui    QEMU 창을 띄워서 실행
set -euo pipefail
source "$(dirname "$0")/../config.sh"

accel=()
[ -w /dev/kvm ] && accel=(-enable-kvm -cpu host)

common=(-m 1G -smp 2 "${accel[@]}"
  -kernel "$OUT_DIR/bzImage" -initrd "$OUT_DIR/initramfs.cpio.gz"
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0
  -no-reboot)

if [ "${1:-}" = "--gui" ]; then
  exec qemu-system-x86_64 "${common[@]}" -vga std -serial stdio \
    -append "console=tty1 console=ttyS0 quiet"
else
  exec qemu-system-x86_64 "${common[@]}" -nographic \
    -append "console=ttyS0 quiet panic=-1"
fi
