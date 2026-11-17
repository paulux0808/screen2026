#!/bin/sh
# setup-board.sh 되돌리기: 자동 시작 · 자동 전체화면 정책을 지우고 알림판 창을 닫는다
APPDIR="${XDG_DATA_HOME:-$HOME/.local/share}/screen2026"
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/screen2026-board.desktop"
[ -f "$HOME/.config/labwc/autostart" ] && sed -i '/screen2026/d' "$HOME/.config/labwc/autostart"
SUDO=""; [ "$(id -u)" = "0" ] || SUDO="sudo"
for d in /etc/chromium/policies/managed /etc/opt/chrome/policies/managed /etc/opt/edge/policies/managed; do
  [ -f "$d/screen2026.json" ] && $SUDO rm -f "$d/screen2026.json"
done
pkill -f -- "screen2026-kiosk" 2>/dev/null
rm -rf "$APPDIR"
echo "[screen2026] 지웠습니다. 알림판이 더는 저절로 열리지 않습니다."
