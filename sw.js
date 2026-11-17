/*
  스마트 알림판 오프라인 보관 (service worker)
  · 알림판 파일(index.html · config.js 등)은 늘 인터넷에서 먼저 받고, 받으면 기기에 사본을 남긴다.
  · 인터넷이 안 되면 그 사본으로 화면을 띄운다. 자료는 알림판이 따로 저장해 둔 것을 보인다.
  · 글꼴(jsdelivr)은 한 번 받으면 사본을 쓴다(주소에 판 번호가 박혀 있어 바뀌지 않는다).
  · 시트·급식·날씨 요청은 건드리지 않는다.
*/
const CACHE = "board-shell-v2";
const SHELL = ["./", "./index.html", "./config.js", "./manifest.webmanifest", "./icon.svg", "./icon-192.png", "./icon-512.png"];
const FONT_HOST = "cdn.jsdelivr.net";

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k.startsWith("board-") && k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const req = e.request;
  if(req.method !== "GET") return;
  const url = new URL(req.url);

  if(url.origin === self.location.origin){
    /* 알림판 파일: 인터넷 먼저, 안 되면 사본 */
    e.respondWith(
      fetch(req).then(res => {
        if(res.ok && res.type === "basic"){
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        }
        return res;
      }).catch(() =>
        caches.match(req, { ignoreSearch:true })
          .then(hit => hit || (req.mode === "navigate" ? caches.match("./") : undefined))
          .then(hit => hit || Response.error())
      )
    );
    return;
  }

  if(url.hostname === FONT_HOST){
    /* 글꼴: 사본 먼저, 없으면 받아서 보관 */
    e.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(res => {
        if(res.ok){
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        }
        return res;
      }))
    );
  }
});
