# SockOS를 Windows에서 직접 QEMU + WHPX 가속으로 실행합니다.
# 사용법 (PowerShell):  powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\SockOS\run-sockos.ps1
# 가볍게 실행:          ... run-sockos.ps1 -Cpus 2 -Width 1280 -Height 720
# 준비물: QEMU for Windows, "Windows 하이퍼바이저 플랫폼" 기능 (README의 Windows 실행 참고)

param(
  [int]$Cpus = 4,          # 노트북이 뜨거워지면 2로 줄여보세요
  [string]$Memory = "4G",
  [int]$Width = 1920,      # 무거우면 1280
  [int]$Height = 1080      # 무거우면 720
)
$ErrorActionPreference = "Stop"
$dir  = $PSScriptRoot
$qemu = "C:\Program Files\qemu\qemu-system-x86_64.exe"

if (-not (Test-Path $qemu)) {
  Write-Host "QEMU가 없어요. 관리자 PowerShell에서 설치하세요:" -ForegroundColor Yellow
  Write-Host "  winget install SoftwareFreedomConservancy.QEMU"
  exit 1
}
foreach ($f in "bzImage", "sockos-desktop.qcow2") {
  if (-not (Test-Path "$dir\$f")) {
    Write-Host "$dir\$f 이 없어요. Ubuntu에서 'make export-windows'를 먼저 실행하세요." -ForegroundColor Yellow
    exit 1
  }
}

$hv = (Get-CimInstance Win32_OptionalFeature -Filter "Name='HypervisorPlatform'").InstallState
if ($hv -ne 1) {
  Write-Host "!! 'Windows 하이퍼바이저 플랫폼'이 꺼져 있어서 느리게 실행돼요." -ForegroundColor Yellow
  Write-Host "   관리자 PowerShell: Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All  (그 후 재부팅)"
}

& $qemu `
  -accel whpx,kernel-irqchip=off -accel tcg `
  -machine q35 -m $Memory -smp $Cpus `
  -cpu qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt `
  -kernel "$dir\bzImage" `
  -append "root=/dev/vda rw console=tty1 quiet loglevel=3" `
  -drive "file=$dir\sockos-desktop.qcow2,format=qcow2,if=virtio" `
  -device "virtio-vga,xres=$Width,yres=$Height" `
  -device virtio-keyboard-pci -device virtio-tablet-pci `
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 `
  -audiodev dsound,id=snd0 -device intel-hda -device hda-duplex,audiodev=snd0 `
  -display sdl
