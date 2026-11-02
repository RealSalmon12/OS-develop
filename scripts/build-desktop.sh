#!/usr/bin/env bash
# 그래픽 데스크톱이 들어간 SockOS 디스크 이미지를 만듭니다. (root 권한 필요)
# 결과: out/sockos-desktop.img
#
# 브라우저 같은 큰 프로그램은 수많은 라이브러리가 필요해서, 사용자 공간은
# Ubuntu 패키지 저장소에서 가져옵니다. 커널, 부팅 설정, 화면, 브랜딩은 SockOS 것입니다.
set -euo pipefail
source "$(dirname "$0")/../config.sh"
[ "$(id -u)" = 0 ] || { echo "root 권한이 필요해요: sudo make desktop"; exit 1; }

MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"
SUITE="${UBUNTU_SUITE:-noble}"
IMAGE_SIZE="${IMAGE_SIZE:-6G}"
root="$BUILD_DIR/desktop-root"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

if [ ! -x "$root/usr/bin/apt-get" ]; then
  echo ">> 기본 파일 시스템 내려받기 ($SUITE)"
  rm -rf "$root"
  debootstrap --variant=minbase --components=main,universe "$SUITE" "$root" "$MIRROR"
fi

cat > "$root/etc/apt/sources.list" <<SRC
deb $MIRROR $SUITE main universe
deb $MIRROR $SUITE-updates main universe
deb $MIRROR $SUITE-security main universe
SRC
# 이미지 안에서 서비스가 바로 켜지지 않게 막습니다.
printf '#!/bin/sh\nexit 101\n' > "$root/usr/sbin/policy-rc.d"
chmod 755 "$root/usr/sbin/policy-rc.d"

mounts=(proc sys dev dev/pts)
cleanup() { for m in dev/pts dev sys proc; do umount -l "$root/$m" 2>/dev/null || true; done; }
trap cleanup EXIT
mount -t proc proc "$root/proc"
mount -t sysfs sys "$root/sys"
mount --bind /dev "$root/dev"
mount --bind /dev/pts "$root/dev/pts"
cp /etc/resolv.conf "$root/etc/resolv.conf.build" 2>/dev/null || true
rm -f "$root/etc/resolv.conf"; cp /etc/resolv.conf "$root/etc/resolv.conf"

echo ">> 패키지 설치"
pkgs=$(grep -v '^\s*#' "$ROOT_DIR/desktop/packages.txt" | xargs)
chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get update -qq
chroot "$root" env DEBIAN_FRONTEND=noninteractive \
  apt-get install -y -qq --no-install-recommends $pkgs

echo ">> SockOS 설정 적용"
cp -a "$ROOT_DIR/desktop/rootfs/." "$root/"
grep -rlI '@OS_' "$root/etc" 2>/dev/null | while read -r f; do
  sed -i -e "s/@OS_NAME@/$OS_NAME/g" -e "s/@OS_VERSION@/$OS_VERSION/g" \
         -e "s/@OS_HOSTNAME@/$OS_HOSTNAME/g" "$f"
done
# Ubuntu 배포판 정보 대신 SockOS 정보를 씁니다.
rm -f "$root/etc/os-release" "$root/usr/lib/os-release"
cp "$root/etc/sockos-release" "$root/usr/lib/os-release"
ln -s ../usr/lib/os-release "$root/etc/os-release"
echo "$OS_HOSTNAME" > "$root/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 %s\n' "$OS_HOSTNAME" > "$root/etc/hosts"
printf '%s %s\n' "$OS_NAME $OS_VERSION" '\n \l' > "$root/etc/issue"

chroot "$root" /bin/bash -e <<'IN'
sed -i 's/^# *ko_KR.UTF-8/ko_KR.UTF-8/; s/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen >/dev/null
echo 'LANG=ko_KR.UTF-8' > /etc/default/locale
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
echo Asia/Seoul > /etc/timezone
id sock >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,video,input,render sock
passwd -d sock >/dev/null
echo 'sock ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/sock
chmod 440 /etc/sudoers.d/sock
cp -a /etc/skel/. /home/sock/ && chown -R sock:sock /home/sock
systemctl enable systemd-networkd systemd-resolved seatd sockos-gpu-detect >/dev/null 2>&1
# Ubuntu 안내 문구 대신 SockOS 화면이 바로 보이게 합니다.
rm -f /etc/update-motd.d/* /etc/legal /etc/motd
systemctl mask systemd-networkd-wait-online.service >/dev/null 2>&1
apt-get clean
rm -rf /var/lib/apt/lists/*
IN
rm -f "$root/usr/sbin/policy-rc.d" "$root/etc/resolv.conf" "$root/etc/resolv.conf.build"
ln -s /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
cleanup; trap - EXIT

echo ">> 디스크 이미지 만들기 ($IMAGE_SIZE)"
img="$OUT_DIR/sockos-desktop.img"
rm -f "$img"; truncate -s "$IMAGE_SIZE" "$img"
mkfs.ext4 -q -L sockos -d "$root" "$img"
# sudo로 만들었어도 일반 사용자가 make run-desktop으로 열 수 있게 소유자를 돌려줍니다.
if [ -n "${SUDO_UID:-}" ]; then
  chown "$SUDO_UID:$SUDO_GID" "$OUT_DIR" "$img"
fi
echo ">> 완료: $img"
