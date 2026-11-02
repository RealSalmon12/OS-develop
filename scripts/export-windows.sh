#!/usr/bin/env bash
# WSL에서 만든 SockOS를 Windows 폴더(%USERPROFILE%\SockOS)로 내보냅니다.
# 그러면 Windows의 QEMU가 WHPX 가속으로 빠르게 실행할 수 있어요.
set -euo pipefail
source "$(dirname "$0")/../config.sh"

winprofile=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
[ -n "$winprofile" ] || { echo "WSL에서만 쓸 수 있어요 (Windows 사용자 폴더를 못 찾음)"; exit 1; }
dest="$(wslpath "$winprofile")/SockOS"
mkdir -p "$dest"

echo ">> 커널 복사"
cp "$OUT_DIR/bzImage" "$dest/bzImage"
command -v qemu-img >/dev/null || { echo "qemu-img가 필요해요: sudo apt install qemu-utils"; exit 1; }
echo ">> 디스크 이미지 변환 (빈 공간을 빼서 작게 만들어요)"
qemu-img convert -p -O qcow2 "$OUT_DIR/sockos-desktop.img" "$dest/sockos-desktop.qcow2"
cp "$ROOT_DIR/windows/run-sockos.ps1" "$dest/run-sockos.ps1"
echo ">> 완료: $winprofile\\SockOS"
echo "   Windows PowerShell에서 실행: powershell -ExecutionPolicy Bypass -File \$env:USERPROFILE\\SockOS\\run-sockos.ps1"
