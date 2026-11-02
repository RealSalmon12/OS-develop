# make        커널, BusyBox, rootfs를 모두 빌드
# make run    터미널에서 실행 / make gui  창으로 실행
.PHONY: all kernel busybox rootfs run gui clean distclean
all: kernel rootfs

kernel:
	./scripts/build-kernel.sh

build/busybox:
	./scripts/build-busybox.sh
busybox: build/busybox

rootfs: build/busybox
	./scripts/build-rootfs.sh

run:
	./scripts/run.sh
gui:
	./scripts/run.sh --gui

clean:
	rm -rf out build/rootfs
distclean:
	rm -rf out build
