# SockOS

리눅스 커널 위에 직접 쌓아 올리는 나만의 OS예요. 지금은 QEMU 에뮬레이터에서 부팅해서 셸까지 뜨는 단계이고, 최종 목표는 이 OS 안에서 브라우저로 유튜브를 보는 거예요.

## 로드맵

- [x] 1단계: 저장소와 빌드 스크립트
- [x] 2단계: 리눅스 커널 + BusyBox로 부팅, OS 이름과 환영 화면, 셸, 네트워크(DHCP)
- [ ] 3단계: 그래픽 데스크톱과 인터넷
- [ ] 4단계: 브라우저로 유튜브 재생

## 필요한 것 (Ubuntu / Debian 기준)

```sh
sudo apt install build-essential flex bison bc libelf-dev libssl-dev cpio xz-utils curl qemu-system-x86
```

Windows라면 WSL2(Ubuntu)에서, macOS라면 Linux 가상머신이나 Docker 안에서 빌드하는 걸 추천해요.

## 빌드하고 실행하기

```sh
make        # 커널과 BusyBox를 내려받아 빌드하고 initramfs를 만듭니다 (처음엔 10~20분)
make run    # 터미널 안에서 실행. 끄려면 poweroff 또는 Ctrl-A 다음 X
make gui    # QEMU 창을 띄워서 실행
```

결과물은 `out/bzImage`(커널)와 `out/initramfs.cpio.gz`(파일 시스템)예요.

## 내 마음대로 바꾸기

- OS 이름, 버전, 호스트 이름: `config.sh`
- 환영 화면: `rootfs/etc/motd`
- 부팅 때 실행되는 일: `rootfs/etc/init.d/rcS`
- 커널 기능: `kernel/myos.config`

`rootfs/` 폴더에 넣은 파일은 그대로 OS 안에 들어가요. `@OS_NAME@`, `@OS_VERSION@`, `@OS_HOSTNAME@`은 빌드할 때 `config.sh` 값으로 바뀝니다.

## 구조

```
config.sh               설정
kernel/myos.config      커널 설정 조각 (defconfig 위에 덮어씀)
rootfs/                 OS 안에 들어갈 파일들 (init, /etc ...)
scripts/build-kernel.sh 커널 다운로드와 빌드
scripts/build-busybox.sh BusyBox(셸과 기본 명령어) 빌드
scripts/build-rootfs.sh initramfs 만들기
scripts/run.sh          QEMU 실행
```

부팅 순서는 커널 → `/init`(파일 시스템 연결) → BusyBox init → `/etc/init.d/rcS`(호스트 이름, 네트워크) → 셸이에요.
