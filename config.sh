# 나만의 OS 기본 설정. 여기 값을 바꾸면 OS 이름, 버전, 사용할 소스가 바뀝니다.
OS_NAME="${OS_NAME:-SockOS}"
OS_VERSION="${OS_VERSION:-0.1}"
OS_HOSTNAME="${OS_HOSTNAME:-sockos}"

KERNEL_VERSION="${KERNEL_VERSION:-6.12.10}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"

# 이미 받아 둔 소스나 바이너리를 쓰고 싶으면 아래 환경 변수를 지정하세요.
#   KERNEL_TARBALL=/path/to/linux-x.y.tar.xz   (다운로드 대신 사용)
#   BUSYBOX_BIN=/path/to/static/busybox        (BusyBox 빌드 생략)

# 데스크톱 브라우저: chrome = Google Chrome (기본), chromium = 오픈소스 Chromium
# Chrome을 못 받으면 자동으로 Chromium을 넣습니다.
# 상품으로 배포할 때는 Chrome을 다시 배포할 수 없으니 BROWSER=chromium 을 쓰세요.
BROWSER="${BROWSER:-chrome}"
#   CHROME_DEB=/path/to/google-chrome-stable_current_amd64.deb   (다운로드 대신 사용)
#   CHROMIUM_ZIP=/path/to/chrome-linux.zip                      (다운로드 대신 사용)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/out}"
JOBS="${JOBS:-$(nproc)}"
