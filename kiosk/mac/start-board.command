#!/bin/sh
# 스마트 알림판을 전체화면(키오스크) 창으로 연다 — 맥용. 더블클릭하면 된다. 닫기: Cmd+Q
# 처음 한 번은 '확인되지 않은 개발자' 경고가 뜰 수 있다: 파일을 오른쪽 클릭 → 열기.
# 로그인할 때마다 열리게 하려면: 시스템 설정 → 일반 → 로그인 항목 → '+' 로 이 파일을 넣는다.
URL="${BOARD_URL:-https://paulux0808.github.io/screen2026/}"
PROFILE="$HOME/Library/Application Support/screen2026-kiosk"

if [ -d "/Applications/Google Chrome.app" ]; then APP="Google Chrome"
elif [ -d "/Applications/Microsoft Edge.app" ]; then APP="Microsoft Edge"
elif [ -d "/Applications/Chromium.app" ]; then APP="Chromium"
else echo "[screen2026] Google Chrome 을 설치해 주세요."; exit 1; fi

pkill -f -- "screen2026-kiosk" 2>/dev/null && sleep 1
open -na "$APP" --args --kiosk "$URL" --user-data-dir="$PROFILE" --no-first-run --no-default-browser-check --hide-crash-restore-bubble
