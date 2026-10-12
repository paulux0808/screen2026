# 스마트 알림판 (screen2026)

`index.html` 한 파일짜리 알림판. 「2026학년도 학사일정」 구글 시트를 gviz JSONP 로 읽기만 한다(쓰지 않는다).

## 시트나 시트 소유 계정이 바뀌면 고칠 곳
- **시트 ID**: `index.html` 의 `SHEET_ID` (현재 `1qg5vX4KlrI3hwn1XLiLIupkO74zxleqV6Imk1y5YQIE`). 시트는 "링크가 있는 모든 사용자"로 공유돼 있어야 한다.
- **탭 이름**: gid 가 아니라 **이름**으로 읽는다. `TABS` 의 `연중행사계획`·`공지사항`·`기도순서`·`자습감독`·`학생현황`, 그리고 `fetchWord()` 의 `성경 말씀`·`찬송가 가사` 가 시트의 탭 이름(띄어쓰기 포함)과 같아야 한다.
- **Apps Script 주소**: 이 저장소는 Apps Script 웹앱을 쓰지 않는다(해당 없음).
- 브라우저 저장본(`board:cache:v1`, `board:word:v1`)에는 받아 온 시트 ID 가 같이 저장되며, 현재 `SHEET_ID` 와 다르면 쓰지 않는다.
