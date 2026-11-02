[ -f ~/.bashrc ] && . ~/.bashrc
# 첫 번째 화면(tty1)에서 로그인하면 SockOS 데스크톱을 바로 띄웁니다.
if [ "$(tty)" = /dev/tty1 ] && [ -z "$WAYLAND_DISPLAY" ]; then
  exec /usr/local/bin/sockos-session
fi
