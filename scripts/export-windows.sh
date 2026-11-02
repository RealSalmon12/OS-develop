#!/usr/bin/env bash
# WSL에서 만든 SockOS를 Windows 폴더(%USERPROFILE%\SockOS)로 내보냅니다.
# 그러면 Windows의 QEMU가 WHPX 가속으로 빠르게 실행할 수 있어요.
set -euo pipefail
source "$(dirname "$0")/../config.sh"

# Windows 사용자 이름이 한글이어도 깨지지 않게 UTF-8(코드 페이지 65001)로 받아 옵니다.
winprofile=$(cd /mnt/c 2>/dev/null; powershell.exe -NoProfile -Command \
  '[Console]::OutputEncoding = [Text.Encoding]::UTF8; $env:USERPROFILE' 2>/dev/null | tr -d '\r' | tail -n 1) || true
if [ -z "$winprofile" ] || [ ! -d "$(wslpath "$winprofile" 2>/dev/null)" ]; then
  winprofile=$(cd /mnt/c 2>/dev/null; cmd.exe /c "chcp 65001 >nul & echo %USERPROFILE%" 2>/dev/null | tr -d '\r' | tail -n 1) || true
fi
[ -n "$winprofile" ] || { echo "WSL에서만 쓸 수 있어요 (Windows 사용자 폴더를 못 찾음)"; exit 1; }
home_win="$(wslpath "$winprofile")"
[ -d "$home_win" ] || { echo "Windows 사용자 폴더를 찾지 못했어요: $winprofile"; exit 1; }
dest="$home_win/SockOS"
mkdir -p "$dest"

echo ">> 커널 복사"
cp "$OUT_DIR/bzImage" "$dest/bzImage"
command -v qemu-img >/dev/null || { echo "qemu-img가 필요해요: sudo apt install qemu-utils"; exit 1; }
echo ">> 디스크 이미지 변환 (빈 공간을 빼서 작게 만들어요)"
qemu-img convert -p -O qcow2 "$OUT_DIR/sockos-desktop.img" "$dest/sockos-desktop.qcow2"
cp "$ROOT_DIR/windows/run-sockos.ps1" "$dest/run-sockos.ps1"
echo ">> 완료: $winprofile\\SockOS"
echo "   Windows PowerShell에서 실행: powershell -ExecutionPolicy Bypass -File \$env:USERPROFILE\\SockOS\\run-sockos.ps1"
