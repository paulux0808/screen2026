#!/bin/sh
# 스마트 알림판 한 번만 하는 설정 — 리눅스 · 라즈베리파이용
#   1) 로그인하면 알림판이 저절로 전체화면으로 열린다
#   2) (sudo 로 실행하거나 암호를 넣으면) Chromium/Chrome/Edge 가 이 주소를 클릭 없이 전체화면으로 연다
#   3) 지금 알림판을 연다
# 되돌리기: ./remove-board.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ORIGIN="https://paulux0808.github.io"
APPDIR="${XDG_DATA_HOME:-$HOME/.local/share}/screen2026"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
REAL_HOME="$HOME"

# sudo 로 실행했으면 자동 시작은 원래 사용자에게 건다
if [ "$(id -u)" = "0" ] && [ -n "${SUDO_USER:-}" ]; then
  REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  APPDIR="$REAL_HOME/.local/share/screen2026"
  AUTOSTART="$REAL_HOME/.config/autostart"
fi

mkdir -p "$APPDIR" "$AUTOSTART"
cp "$HERE/start-board.sh" "$APPDIR/start-board.sh"
chmod +x "$APPDIR/start-board.sh"
cat > "$AUTOSTART/screen2026-board.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=스마트 알림판
Comment=로그인하면 알림판을 전체화면으로 연다
Exec=$APPDIR/start-board.sh
X-GNOME-Autostart-enabled=true
EOF
# 라즈베리파이 OS(labwc)용 자동 시작
if [ -d "$REAL_HOME/.config/labwc" ] || command -v labwc >/dev/null 2>&1; then
  mkdir -p "$REAL_HOME/.config/labwc"
  grep -qs "screen2026" "$REAL_HOME/.config/labwc/autostart" || echo "$APPDIR/start-board.sh &  # screen2026" >> "$REAL_HOME/.config/labwc/autostart"
fi
if [ -n "${SUDO_USER:-}" ]; then chown -R "$SUDO_USER" "$APPDIR" "$AUTOSTART" "$REAL_HOME/.config/labwc" 2>/dev/null || true; fi
echo " [1/3] 로그인하면 알림판이 전체화면으로 열립니다."

# 클릭 없이 전체화면 허용 정책 (관리자 권한 필요)
POLICY="{\"AutomaticFullscreenAllowedForUrls\": [\"$ORIGIN\"]}"
SUDO=""; [ "$(id -u)" = "0" ] || SUDO="sudo"
if $SUDO true 2>/dev/null; then
  for d in /etc/chromium/policies/managed /etc/opt/chrome/policies/managed /etc/opt/edge/policies/managed; do
    $SUDO mkdir -p "$d" && echo "$POLICY" | $SUDO tee "$d/screen2026.json" >/dev/null
  done
  echo " [2/3] 브라우저가 $ORIGIN 를 클릭 없이 전체화면으로 열 수 있습니다."
else
  echo " [2/3] (건너뜀) 관리자 권한이 없어 자동 전체화면 정책은 넣지 못했습니다. 키오스크 창이라 그대로 전체화면입니다."
fi

echo " [3/3] 알림판을 엽니다…"
if [ -n "${SUDO_USER:-}" ]; then
  echo "       (sudo 로 실행해서 지금 열지는 않습니다. 로그아웃 후 다시 로그인하면 열립니다.)"
else
  nohup "$APPDIR/start-board.sh" >/dev/null 2>&1 &
fi
