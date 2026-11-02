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
# 예전 버전에 있던 프로그램 정리 (Falkon → Chrome으로 바뀜)
chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq falkon >/dev/null 2>&1 || true
chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq --purge >/dev/null 2>&1 || true
rm -rf "$root/home/sock/.config/falkon" "$root/etc/skel/.config/falkon"

echo ">> 웹 브라우저 설치 ($BROWSER)"
install_chrome() {
  if [ -n "${CHROME_DEB:-}" ]; then
    cp "$CHROME_DEB" "$root/tmp/chrome.deb"
  else
    chroot "$root" curl -fsSL --retry 3 -o /tmp/chrome.deb \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb || return 1
  fi
  chroot "$root" env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/chrome.deb
  local rc=$?; rm -f "$root/tmp/chrome.deb"; return $rc
}
install_chromium() {
  local base=https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64 rev
  if [ -n "${CHROMIUM_ZIP:-}" ]; then
    cp "$CHROMIUM_ZIP" "$root/tmp/chromium.zip"
  else
    rev=$(chroot "$root" curl -fsSL "$base/LAST_CHANGE") || return 1
    chroot "$root" curl -fSL --retry 3 -o /tmp/chromium.zip "$base/$rev/chrome-linux.zip" || return 1
  fi
  rm -rf "$root/opt/chromium" "$root/opt/chrome-linux"
  chroot "$root" unzip -q /tmp/chromium.zip -d /opt || return 1
  rm -f "$root/tmp/chromium.zip"
  mv "$root/opt/chrome-linux" "$root/opt/chromium"
  # 샌드박스 도우미는 root 소유 + setuid 여야 합니다.
  mv "$root/opt/chromium/chrome_sandbox" "$root/opt/chromium/chrome-sandbox"
  chown root:root "$root/opt/chromium/chrome-sandbox"; chmod 4755 "$root/opt/chromium/chrome-sandbox"
}
browser_name=""
if [ "$BROWSER" = chrome ] && install_chrome; then
  browser_name="Chrome"
  cp "$ROOT_DIR/desktop/rootfs/usr/share/sockos/browser-preferences.json" "$root/opt/google/chrome/initial_preferences"
elif install_chromium; then
  [ "$BROWSER" = chrome ] && echo "!! Google Chrome을 받지 못해서 Chromium을 대신 넣었어요."
  browser_name="Chromium"
  cp "$ROOT_DIR/desktop/rootfs/usr/share/sockos/browser-preferences.json" "$root/opt/chromium/initial_preferences"
else
  echo "!! 브라우저를 받지 못했어요. 인터넷 연결을 확인하고 다시 실행하세요." >&2
  exit 1
fi

echo ">> SockOS 설정 적용"
cp -a "$ROOT_DIR/desktop/rootfs/." "$root/"
grep -rlI '@OS_' "$root/etc" 2>/dev/null | while read -r f; do
  sed -i -e "s/@OS_NAME@/$OS_NAME/g" -e "s/@OS_VERSION@/$OS_VERSION/g" \
         -e "s/@OS_HOSTNAME@/$OS_HOSTNAME/g" "$f"
done
# 앱 메뉴 정리: 쉬운 한국어 이름을 붙이고, 일반 사용자에게 필요 없는 항목은 숨깁니다.
# 원본은 그대로 두고 /usr/local/share/applications 에 덮어쓰는 파일을 만듭니다.
apps="$root/usr/share/applications"; local_apps="$root/usr/local/share/applications"
mkdir -p "$local_apps"; rm -f "$local_apps"/*.desktop
rename_app() {  # rename_app 파일 "새 이름"
  [ -f "$apps/$1" ] || return 0
  awk -v name="$2" '/^\[/ { main = ($0 == "[Desktop Entry]") }
    main && /^Name\[/ { next }
    main && /^Name=/ { print "Name=" name; next }
    { print }' "$apps/$1" > "$local_apps/$1"
}
hide_app() {
  [ -f "$apps/$1" ] || return 0
  sed -e '/^NoDisplay=/d' -e 's/^\[Desktop Entry\]$/[Desktop Entry]\nNoDisplay=true/' "$apps/$1" > "$local_apps/$1"
}
rename_app pcmanfm-qt.desktop "파일"
rename_app org.codeberg.dnkl.foot.desktop "터미널"
rename_app featherpad.desktop "메모장"
rename_app lximage-qt.desktop "사진 보기"
rename_app qpdfview.desktop "PDF 보기"
rename_app pavucontrol-qt.desktop "소리 설정"
rename_app fcitx5-configtool.desktop "한글 입력 설정"
rename_app speedcrunch.desktop "계산기"
rename_app lxqt-archiver.desktop "압축 풀기"
rename_app mpv.desktop "동영상 플레이어"
rename_app qps.desktop "작업 관리자"
# 브라우저는 SockOS 실행기(sockos-browser.desktop) 하나만 보이게 합니다.
if [ "$browser_name" = Chromium ]; then
  sed -i -e 's/^Icon=.*/Icon=chromium/' -e 's/^StartupWMClass=.*/StartupWMClass=chromium-browser/' \
    "$root/usr/share/applications/sockos-browser.desktop"
  # 작업 표시줄이 Chromium 창 아이콘을 찾을 수 있게 숨은 항목을 만듭니다.
  for f in chromium chromium-browser; do
    printf '[Desktop Entry]\nType=Application\nName=Chromium\nExec=sockos-browser\nIcon=chromium\nNoDisplay=true\n' \
      > "$local_apps/$f.desktop"
  done
fi
sed -i "0,/^Name=.*/s//Name=인터넷 ($browser_name)/" "$root/usr/share/applications/sockos-browser.desktop"
for f in google-chrome.desktop org.codeberg.dnkl.foot-server.desktop org.codeberg.dnkl.footclient.desktop \
         org.fcitx.Fcitx5.desktop org.fcitx.fcitx5-migrator.desktop \
         kbd-layout-viewer5.desktop pcmanfm-qt-desktop-pref.desktop; do
  hide_app "$f"
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
