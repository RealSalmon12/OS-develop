#!/usr/bin/env bash
# BusyBox와 rootfs/ 폴더를 합쳐 부팅용 initramfs를 만듭니다. 결과: out/initramfs.cpio.gz
set -euo pipefail
source "$(dirname "$0")/../config.sh"
mkdir -p "$OUT_DIR"
stage="$BUILD_DIR/rootfs"
rm -rf "$stage"
mkdir -p "$stage"/{bin,sbin,usr/bin,usr/sbin,proc,sys,dev,tmp,run,root,etc,var/log}

cp "$BUILD_DIR/busybox" "$stage/bin/busybox"
chmod 755 "$stage/bin/busybox"
for app in $("$stage/bin/busybox" --list-full); do
  [ -e "$stage/$app" ] || ln -s /bin/busybox "$stage/$app"
done

cp -a "$ROOT_DIR/rootfs/." "$stage/"
# 설정 파일 안의 @OS_NAME@ 같은 자리표시자를 config.sh 값으로 바꿉니다.
grep -rlI '@OS_' "$stage/etc" | while read -r f; do
  sed -i -e "s/@OS_NAME@/$OS_NAME/g" -e "s/@OS_VERSION@/$OS_VERSION/g" \
         -e "s/@OS_HOSTNAME@/$OS_HOSTNAME/g" "$f"
done
chmod 755 "$stage/init" "$stage/etc/init.d/rcS" "$stage/bin/login-shell" \
          "$stage/usr/share/udhcpc/default.script"

(cd "$stage" && find . -print0 | cpio --null -o -H newc --owner=0:0 --quiet) \
  | gzip -9 > "$OUT_DIR/initramfs.cpio.gz"
echo ">> 완료: $OUT_DIR/initramfs.cpio.gz ($(du -h "$OUT_DIR/initramfs.cpio.gz" | cut -f1))"
