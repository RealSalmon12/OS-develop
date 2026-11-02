#!/usr/bin/env bash
# 그래픽 데스크톱 SockOS를 QEMU 창으로 실행합니다.
#   ./scripts/run-desktop.sh            QEMU 창 띄우기
#   ./scripts/run-desktop.sh --headless 화면 없이 실행 (VNC :1 로 접속 가능)
set -euo pipefail
source "$(dirname "$0")/../config.sh"

accel=()
[ -w /dev/kvm ] && accel=(-enable-kvm -cpu host)

display=(-display gtk,zoom-to-fit=on)
audio=(-audiodev "${AUDIO:-pa}",id=snd0)   # 소리 출력 방식 (pa, pipewire, alsa ...)
if [ "${1:-}" = "--headless" ]; then
  display=(-display none -vnc :1)
  audio=(-audiodev none,id=snd0)
fi

exec qemu-system-x86_64 -m "${RAM:-3G}" -smp "${CPUS:-4}" "${accel[@]}" \
  -kernel "$OUT_DIR/bzImage" \
  -append "root=/dev/vda rw console=tty1 console=ttyS0 quiet loglevel=3" \
  -drive file="$OUT_DIR/sockos-desktop.img",format=raw,if=virtio \
  -device virtio-vga,xres=1280,yres=800 \
  -device virtio-keyboard-pci -device virtio-tablet-pci \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  "${audio[@]}" -device intel-hda -device hda-duplex,audiodev=snd0 \
  -serial mon:stdio "${display[@]}" "${@:2}"
