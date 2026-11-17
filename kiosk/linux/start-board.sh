#!/bin/sh
# 스마트 알림판을 전체화면(키오스크) 창으로 연다 — 리눅스 · 라즈베리파이용
#   ./start-board.sh            알림판 열기 (닫기: Alt+F4)
#   BOARD_URL=… ./start-board.sh   다른 주소로 열기
#   BOARD_BROWSER=… ./start-board.sh   브라우저 실행 파일을 직접 지정
# 다른 브라우저 창과 섞이지 않도록 알림판 전용 프로필(~/.config/screen2026-kiosk)을 쓴다.

URL="${BOARD_URL:-https://paulux0808.github.io/screen2026/}"
PROFILE="${XDG_CONFIG_HOME:-$HOME/.config}/screen2026-kiosk"

BROWSER="${BOARD_BROWSER:-}"
if [ -z "$BROWSER" ]; then
  for b in chromium chromium-browser google-chrome google-chrome-stable microsoft-edge microsoft-edge-stable; do
    if command -v "$b" >/dev/null 2>&1; then BROWSER="$b"; break; fi
  done
fi
if [ -z "$BROWSER" ]; then
  echo "[screen2026] Chromium · Chrome · Edge 가운데 하나를 설치해 주세요 (예: sudo apt install chromium)" >&2
  exit 1
fi

# 화면 보호기 · 화면 꺼짐 끄기 (X11 일 때)
if [ -n "${DISPLAY:-}" ] && command -v xset >/dev/null 2>&1; then
  xset s off -dpms s noblank 2>/dev/null || true
fi

# 켜자마자라 인터넷이 아직 안 붙었으면 30초까지 기다린다
if command -v curl >/dev/null 2>&1; then
  i=0
  while [ "$i" -lt 6 ] && ! curl -s -o /dev/null -m 5 -I "$URL"; do i=$((i + 1)); sleep 5; done
fi

# 이미 열린 알림판 창만 닫는다 (다른 브라우저 창은 그대로)
pkill -f -- "--user-data-dir=$PROFILE" 2>/dev/null && sleep 1

# 지난번에 전원이 그냥 꺼졌어도 '페이지 복원' 말풍선이 뜨지 않게 한다
PREF="$PROFILE/Default/Preferences"
if [ -f "$PREF" ]; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[A-Za-z]*"/"exit_type":"Normal"/' "$PREF" 2>/dev/null || true
fi

exec "$BROWSER" --kiosk "$URL" --user-data-dir="$PROFILE" \
  --no-first-run --no-default-browser-check --noerrdialogs \
  --disable-session-crashed-bubble --hide-crash-restore-bubble \
  --disable-features=Translate --overscroll-history-navigation=0 --disable-pinch \
  --password-store=basic "$@"
