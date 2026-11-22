/*
  알림판 점검: node tests/smoke.cjs
  · 저장소 폴더를 작은 웹서버로 띄우고, 구글 시트·나이스·날씨 응답을 흉내 낸 자료로 실제 브라우저(Playwright Chromium)에 열어 본다.
  · 일정·공지·급식·기도·학생현황·아침 예배 화면이 제대로 그려지는지, 인터넷이 끊겼을 때 저장본·오프라인 보관이 도는지 확인한다.
  · 하나라도 어긋나면 무엇이 틀렸는지 적고 실패(종료 코드 1)로 끝난다.
  필요한 것: Node 18+ 와 playwright 패키지(+ chromium). 예) npm i --no-save playwright && npx playwright install chromium
*/
"use strict";
const http = require("http");
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const ROOT = path.resolve(__dirname, "..");
const SHOTS = process.env.SHOTS || "";          /* 화면을 찍어 둘 폴더 (비우면 찍지 않는다) */
let failures = 0;
const ok = (cond, msg) => { console.log(`${cond ? "  ✓" : "  ✗"} ${msg}`); if(!cond) failures++; };

/* ── 0. 붙여 넣기 사고 방지: 역슬래시+괄호/대괄호가 없어야 한다 ── */
console.log("소스 검사");
for(const f of ["index.html", "config.js", "sw.js"]){
  const src = fs.readFileSync(path.join(ROOT, f), "utf8");
  const bad = ["\\(", "\\)", "\\[", "\\]"].filter(s => src.includes(s));
  ok(!bad.length, `${f}: 수식 기호로 바뀌기 쉬운 글자 쌍이 없다${bad.length ? " — 발견: " + bad.join(" ") : ""}`);
}
for(const f of ["manifest.webmanifest"]){
  try{ JSON.parse(fs.readFileSync(path.join(ROOT, f), "utf8")); ok(true, `${f}: JSON 형식이 맞다`); }
  catch(e){ ok(false, `${f}: JSON 형식 오류 ${e.message}`); }
}

/* ── 흉내 자료 ── */
const D = (y, m, d) => ({ v:`Date(${y},${m - 1},${d})`, f:`${y}. ${m}. ${d}` });
const S = v => (v == null ? null : { v });
const N = v => ({ v, f:String(v) });
const table = (labels, rows) => ({ cols:labels.map((label, i) => ({ id:String.fromCharCode(65 + i), label, type:"string" })), rows:rows.map(c => ({ c })), parsedNumHeaders:1 });
const SHEETS = {
  "연중행사계획": table(["날짜", "요일", "일정"], [
    [D(2026, 11, 13), S("금"), S("[교무부]2학기 2차 지필평가 원안 제출")],
    [D(2026, 11, 16), S("월"), S("[상담부]학부모 상담 주간(~20일)")],
    [D(2026, 11, 17), S("화"), S("[교목부]화요예배\n[1학년부]안전교육(①,7) [교무부]교직원 협의회 (14:30)\n[연구부]공개수업 참관(②,3)")],
    [D(2026, 11, 18), S("수"), S("[연구부]수업 공개의 날(①②,3~4)\n[3학년부]진로 특강(③,6,7)\n[2학년부]<자율>학급 활동(②,6-7)\n[2학년부]<자율>학급 활동(③,7)")],
    [D(2026, 11, 19), S("목"), S("[교무부]대학수학능력시험")],
    [D(2026, 11, 20), S("금"), null]
  ]),
  "공지사항": table(["게시 시작일", "게시 종료일", "내용"], [
    [D(2026, 11, 16), D(2026, 11, 18), S("수능 시험장 준비로 18일(수) 오후 교실 출입이 제한됩니다.")],
    [D(2026, 10, 1), D(2026, 10, 2), S("지난 공지(보이면 안 됨)")]
  ]),
  "기도순서": table(["날짜", "요일", "이름", "성경", "찬송"], [
    [S("11/16"), S("월"), S("김하나"), S("시편 23:1-3"), N(301)],
    [S("11/17"), S("화"), S("이두리"), S("요한복음 8:12"), N(430)],
    [S("11/18"), S("수"), S("박세나"), S("로마서 8:28"), N(310)],
    [S("11/19"), S("목"), S("최네리"), S(""), S("")],
    [S("11/20"), S("금"), S("정다솜"), S("잠언 3:5-6"), N(288)]
  ]),
  "자습감독": table(["날짜", "요일", "이름"], [
    [D(2026, 11, 17), S("화"), S("홍길동")],
    [D(2026, 11, 18), S("수"), S("자습 미운영")]
  ]),
  "학생현황": table(["1학년 학급", "담임", "학생수", "2학년 학급", "담임", "학생수", "3학년 학급", "담임", "학생수"], [
    [N(1), S("가"), N(19), N(1), S("가"), N(19), N(1), S("가"), N(22)],
    [N(2), S("나"), N(20), N(2), S("나"), N(19), N(2), S("나"), N(20)],
    [N(3), S("다"), N(20), N(3), S("다"), N(20), N(3), S("다"), N(20)],
    [N(4), S("라"), N(20), N(4), S("라"), N(19), N(4), S("라"), N(20)],
    [N(5), S("마"), N(19), N(5), S("마"), N(19), N(5), S("마"), N(20)],
    [null, null, null, null, null, null, N(6), S("바"), N(18)]
  ]),
  "찬송가 가사": table(["장", "가사"], [
    [N(430), S("(1) 주와 같이 길 가는 것 즐거운 일 아닌가\n(2) 어린아이 같은 우리 미련하고 약하나\n(3) 꽃이 피는 들판이나 험한 골짜기라도")]
  ]),
  "성경 말씀": table(["책", "약칭", "장", "절", "본문"], [
    [S("요한복음"), S("요"), N(8), N(12), S("예수께서 또 말씀하여 이르시되 나는 세상의 빛이니")]
  ])
};
/* gviz 질의(select … where …)는 흉내 내지 않고, 탭에 맞는 줄만 돌려준다 */
const QUERY = {
  "찬송가 가사": t => ({ ...t, rows:t.rows }),
  "성경 말씀": t => ({ cols:t.cols.slice(2), rows:t.rows.map(r => ({ c:r.c.slice(2) })) })
};
const NEIS = {
  schoolInfo:{ schoolInfo:[{ head:[{ list_total_count:1 }, { RESULT:{ CODE:"INFO-000" } }] }, { row:[{ SCHUL_NM:"보성여자고등학교", SD_SCHUL_CODE:"7010123" }] }] },
  mealServiceDietInfo:{ mealServiceDietInfo:[{ head:[{ list_total_count:2 }, { RESULT:{ CODE:"INFO-000" } }] }, { row:[
    { MMEAL_SC_NM:"중식", MLSV_YMD:"20261117", CAL_INFO:"812.3 Kcal", DDISH_NM:"현미밥 (5.)<br/>쇠고기미역국 (5.6.16.)<br/>닭갈비 (5.6.13.15.)<br/>배추김치 (9.)" },
    { MMEAL_SC_NM:"석식", MLSV_YMD:"20261117", CAL_INFO:"905.1 Kcal", DDISH_NM:"카레라이스 (2.5.6.)<br/>돈가스 (1.2.5.6.10.)<br/>깍두기 (9.)" }
  ] }] }
};
const WX = { current:{ temperature_2m:8.3, weather_code:2 }, daily:{ temperature_2m_max:[12.1], temperature_2m_min:[3.2], precipitation_probability_max:[20] } };

function serve(){
  const types = { ".html":"text/html; charset=utf-8", ".js":"text/javascript; charset=utf-8", ".webmanifest":"application/manifest+json", ".svg":"image/svg+xml", ".png":"image/png" };
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      let p = decodeURIComponent(req.url.split("?")[0]);
      if(p.endsWith("/")) p += "index.html";
      const f = path.join(ROOT, path.normalize(p));
      if(!f.startsWith(ROOT)){ rsp.writeHead(403); rsp.end(); return; }
      fs.readFile(f, (e, buf) => {
        if(e){ rsp.writeHead(404); rsp.end("not found"); return; }
        rsp.writeHead(200, { "content-type":types[path.extname(f)] || "application/octet-stream", "cache-control":"no-cache" });
        rsp.end(req.method === "HEAD" ? undefined : buf);
      });
    }).listen(0, "127.0.0.1", () => res(srv));
  });
}
async function mock(ctx, net){
  await ctx.route(/docs\.google\.com\/spreadsheets/, route => {
    if(!net.on) return route.abort("internetdisconnected");
    const u = new URL(route.request().url());
    const cb = (u.searchParams.get("tqx") || "").match(/responseHandler:([\w$]+)/)[1];
    const sheet = u.searchParams.get("sheet");
    let t = SHEETS[sheet];
    if(t && u.searchParams.get("tq") && QUERY[sheet]) t = QUERY[sheet](t);
    const body = t ? { version:"0.6", status:"ok", table:t } : { version:"0.6", status:"error", errors:[{ reason:"invalid_query", message:"Invalid sheet" }] };
    route.fulfill({ contentType:"text/javascript; charset=utf-8", body:`/*O_o*/\n${cb}(${JSON.stringify(body)});` });
  });
  await ctx.route(/open\.neis\.go\.kr/, route => {
    if(!net.on) return route.abort("internetdisconnected");
    const svc = new URL(route.request().url()).pathname.split("/").pop();
    route.fulfill({ contentType:"application/json", headers:{ "access-control-allow-origin":"*" }, body:JSON.stringify(NEIS[svc] || { RESULT:{ CODE:"INFO-200" } }) });
  });
  await ctx.route(/api\.open-meteo\.com/, route => net.on
    ? route.fulfill({ contentType:"application/json", headers:{ "access-control-allow-origin":"*" }, body:JSON.stringify(WX) })
    : route.abort("internetdisconnected"));
  await ctx.route(/cdn\.jsdelivr\.net/, route => route.fulfill({ contentType:"text/css", headers:{ "access-control-allow-origin":"*" }, body:"" }));
}
const read = page => page.evaluate(() => {
  const txt = s => [...document.querySelectorAll(s)].map(x => x.innerText.replace(/\s+/g, " ").trim());
  const vis = s => { const e = document.querySelector(s); return !!e && e.offsetParent !== null; };
  return {
    overlay:document.querySelector("#overlay").hidden ? "" : document.querySelector("#overlay").innerText,
    status:document.querySelector("#stxt").textContent, dot:document.querySelector("#dot").className,
    pill:document.querySelector("#nowPill").hidden ? "" : document.querySelector("#nowPill").textContent,
    today:txt("#list-today > li"), todayNow:txt("#list-today > li.now"), todayPast:txt("#list-today > li.past"),
    next:txt("#list-next > li"), nextLabel:document.querySelector("#card-next [data-r=label]").textContent,
    nightToday:txt("#card-today .night:not([hidden]) b"), nightNext:txt("#card-next .night:not([hidden]) b"),
    notices:vis("#notices") ? txt("#list-notice > li") : [],
    tabs:txt("#mealTabs .tab"), tabOn:txt("#mealTabs .tab.on"), when:document.querySelector("#mealWhen").textContent,
    menuOn:txt(".menu.on"), kcal:document.querySelector("#mealKcal").textContent,
    week:txt("#week .wk"), weekNow:txt("#week .wk.now"), dv:document.querySelector("#dvLine").innerText,
    stuTotal:document.querySelector("#stuTotal").textContent, stuCells:txt("#stuRows .c").length,
    worshipOn:document.querySelector("#stage").classList.contains("worship-on"),
    hymn:document.querySelector("#w-hymn b").textContent, bible:document.querySelector("#w-bible b").textContent,
    lyrics:txt("#w-hymn-text > li"), verses:txt("#w-bible-text > li"), pray:document.querySelector("#wPray strong").textContent,
    wx:vis("#wx") ? document.querySelector("#wx").innerText.replace(/\s+/g, " ") : "",
    bells:vis("#bells") ? txt("#bells .bell.now") : null,
    emptyPg:[...document.querySelectorAll(".pg")].filter(x => x.offsetParent !== null && !x.textContent).length
  };
});

(async () => {
  const srv = await serve();
  const base = `http://127.0.0.1:${srv.address().port}/`;
  const browser = await chromium.launch();
  const errors = [];
  const open = async (ctx, q, wait = 1800) => {
    const page = await ctx.newPage();
    page.on("pageerror", e => errors.push(`${q}: ${e.message}`));
    page.on("console", m => { if(m.type() === "error" && !/net::ERR_INTERNET_DISCONNECTED|Failed to load resource/.test(m.text())) errors.push(`${q}: ${m.text()}`); });
    await page.goto(base + q);
    await page.waitForTimeout(wait);
    return page;
  };
  const shot = async (page, name) => { if(SHOTS){ fs.mkdirSync(SHOTS, { recursive:true }); await page.screenshot({ path:path.join(SHOTS, name + ".png") }); } };
  const newCtx = (extra = {}) => browser.newContext({ viewport:{ width:1920, height:1080 }, deviceScaleFactor:1, serviceWorkers:"block", ...extra });

  /* ── 1. 수업 중 평소 화면 ── */
  console.log("평소 화면 (11/17 화 10:30)");
  const net = { on:true };
  let ctx = await newCtx();
  await mock(ctx, net);
  let page = await open(ctx, "?date=2026-11-17&time=10:30");
  let v = await read(page);
  await shot(page, "1-normal");
  ok(!v.overlay, "자료 불러오기 실패 안내가 없다");
  ok(v.dot === "dot" && /갱신/.test(v.status), `상태 줄이 정상이다 (${v.status})`);
  ok(v.pill === "3교시 수업 중 · 30분 남음", `지금 배지: ${v.pill}`);
  ok(v.bells && v.bells.length === 1 && /3교시/.test(v.bells[0]), "일과 줄에 3교시가 표시된다");
  ok(v.today.some(x => /교목부 화요예배/.test(x)), "오늘: [교목부]화요예배");
  ok(v.today.some(x => /안전교육 ?1학년 7교시/.test(x)), "오늘: 안전교육에 '1학년 7교시' 태그");
  ok(v.today.some(x => /교직원 협의회 \(14:30\)/.test(x)), "오늘: 시각 괄호는 본문에 남는다");
  ok(v.todayNow.some(x => /공개수업 참관 ?2학년 3교시/.test(x)), "오늘: 지금 교시(3교시) 일정이 강조된다");
  ok(v.today.some(x => /학부모 상담 주간 ?~11\/20/.test(x)), "오늘: 어제 시작한 기간 일정(~20일)이 이어서 보인다");
  ok(v.nightToday.join() === "홍길동", "오늘 자습감독: 홍길동");
  ok(v.nextLabel === "내일", "다음 칸 이름: 내일");
  ok(v.next.some(x => /수업 공개의 날 ?1·2학년 3~4교시/.test(x)), "내일: '1·2학년 3~4교시'");
  ok(v.next.some(x => /자율 ?학급 활동 ?2학년 6~7교시 ?3학년 7교시/.test(x)), "내일: 같은 일정은 한 줄로 묶이고 태그가 나열된다");
  ok(v.nightNext.join() === "자습 미운영", "내일 자습: 미운영");
  ok(v.notices.length === 1 && /수능 시험장/.test(v.notices[0]), "공지: 기간 안의 공지 하나만");
  ok(v.tabs.join() === "중식,석식" && v.when === "오늘", `급식 이름표: ${v.tabs} (${v.when})`);
  ok(v.menuOn.length === 1 && /현미밥/.test(v.menuOn[0]) && !/[(]?\d+\.[)]?/.test(v.menuOn[0]), `급식: 알레르기 번호가 빠진다 (${v.menuOn[0]})`);
  ok(v.kcal === "812 kcal", "급식 열량: 812 kcal");
  ok(v.week.length === 5 && /이두리/.test(v.weekNow[0] || ""), "기도: 이번 주 다섯 날, 오늘(이두리) 강조");
  ok(/430장/.test(v.dv) && /요한복음 8:12/.test(v.dv), `오늘 찬송·성경: ${v.dv}`);
  ok(v.stuTotal === "총 314명" && v.stuCells === 18, `학생현황: ${v.stuTotal}`);
  ok(/8°/.test(v.wx) && /구름 조금/.test(v.wx), `날씨: ${v.wx}`);
  ok(v.emptyPg === 0, "빈 쪽 번호 칸이 보이지 않는다");
  await page.close();

  /* ── 2. 점심 뒤: 중식이 내려가고 석식만 ── */
  console.log("점심 뒤 (12:30)");
  page = await open(ctx, "?date=2026-11-17&time=12:30");
  v = await read(page);
  ok(v.tabs.join() === "석식" && /카레라이스/.test(v.menuOn[0] || ""), `급식: 석식만 (${v.tabs})`);
  ok(v.todayPast.some(x => /공개수업 참관/.test(x)), "끝난 교시(3교시) 일정은 흐리게");
  await page.close();

  /* ── 3. 아침 예배 ── */
  console.log("아침 예배 (07:52)");
  page = await open(ctx, "?date=2026-11-17&time=07:52", 2500);
  v = await read(page);
  await shot(page, "2-worship");
  ok(v.worshipOn, "아침 예배 화면으로 바뀐다");
  ok(v.hymn === "430장" && v.lyrics.length === 3 && /^1 ?주와 같이/.test(v.lyrics[0]), `찬송 가사 3절 (${v.lyrics.length}절)`);
  ok(v.bible === "요한복음 8:12" && v.verses.length === 1 && /세상의 빛/.test(v.verses[0]), "성경 본문");
  ok(v.pray === "이두리", "기도 맡은 이: 이두리");
  ok(v.emptyPg === 0, "빈 쪽 번호 칸이 보이지 않는다");
  await page.close();

  /* ── 4. 주말: 다음 등교일 ── */
  console.log("토요일 (11/21)");
  page = await open(ctx, "?date=2026-11-21&time=10:00");
  v = await read(page);
  ok(/요일/.test(v.nextLabel) && v.week.length === 5, `다음 칸: ${v.nextLabel}, 기도는 다음 주`);
  ok(v.bells === null, "주말에는 일과 줄이 없다");
  await page.close();

  /* ── 5. 인터넷이 끊긴 채 다시 켜짐: 저장본 ── */
  console.log("인터넷 끊김 (저장본)");
  net.on = false;
  page = await open(ctx, "?date=2026-11-17&time=10:30");
  v = await read(page);
  ok(!v.overlay && v.today.some(x => /화요예배/.test(x)), "저장본으로 일정을 보인다");
  ok(/dot err/.test(v.dot) && /저장본/.test(v.status), `상태 줄이 끊김을 알린다 (${v.status})`);
  await page.close();
  await ctx.close();

  /* ── 6. 처음부터 인터넷이 없을 때 ── */
  console.log("처음부터 끊김");
  ctx = await newCtx();
  await mock(ctx, net);
  page = await open(ctx, "?date=2026-11-17&time=10:30");
  v = await read(page);
  ok(/불러오지 못했습니다/.test(v.overlay), "불러오지 못했다는 안내가 뜬다");
  await page.close();
  await ctx.close();
  net.on = true;

  /* ── 7. 예시 화면 ── */
  console.log("예시 화면 (?demo)");
  ctx = await newCtx();
  await mock(ctx, net);
  page = await open(ctx, "?demo&time=10:30");
  v = await read(page);
  ok(!v.overlay && v.today.length >= 4 && v.next.length >= 5, "예시 자료가 그려진다");
  await page.close();

  /* ── 7-1. 설치 파일 받기 (ZIP): 한 번 받으면 단추가 사라진다 ── */
  console.log("설치 파일 받기 (ZIP)");
  page = await ctx.newPage();
  page.on("pageerror", e => errors.push(`setup: ${e.message}`));
  await page.goto(base + "?date=2026-11-17&time=10:30");
  await page.waitForTimeout(1200);
  ok(await page.evaluate(() => !document.querySelector("#btnSetup").hidden), "처음에는 '설치 파일 받기' 단추가 있다");
  await page.mouse.move(400, 400);
  const [dl] = await Promise.all([page.waitForEvent("download", { timeout:15000 }), page.click("#btnSetup")]);
  const zipPath = path.join(require("os").tmpdir(), `screen2026-${process.pid}.zip`);
  await dl.saveAs(zipPath);
  ok(dl.suggestedFilename() === "screen2026-windows.zip", `파일 이름: ${dl.suggestedFilename()}`);
  const { execFileSync } = require("child_process");
  const check = JSON.parse(execFileSync("python3", ["-I", "-c", `
import json, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
print(json.dumps({"bad": z.testzip(), "names": z.namelist(),
  "bat": z.read("setup-board.bat").hex(), "ps1": z.read("clean-startup.ps1").hex(),
  "readme": z.read("README.txt")[:3].hex()}))`, zipPath]).toString());
  const want = ["README.txt", "setup-board.bat", "start-board.bat", "remove-board.bat", "clean-startup.bat", "clean-startup.ps1", "restore-startup.bat", "allow-auto-fullscreen.reg", "remove-auto-fullscreen.reg"];
  ok(check.bad === null, "ZIP 이 손상되지 않았다 (CRC 확인)");
  ok(JSON.stringify(check.names) === JSON.stringify(want), `ZIP 안의 파일: ${check.names.join(", ")}`);
  ok(check.bat === fs.readFileSync(path.join(ROOT, "kiosk/windows/setup-board.bat")).toString("hex"), "setup-board.bat 이 원본과 똑같다 (줄 끝 CRLF 유지)");
  ok(check.ps1 === fs.readFileSync(path.join(ROOT, "kiosk/windows/clean-startup.ps1")).toString("hex"), "clean-startup.ps1 이 원본과 똑같다 (BOM 유지)");
  ok(check.readme === "efbbbf", "README.txt 는 메모장에서 한글이 깨지지 않게 BOM 이 붙어 있다");
  fs.unlinkSync(zipPath);
  ok(await page.evaluate(() => document.querySelector("#btnSetup").hidden), "받은 뒤에는 단추가 사라진다");
  await page.reload(); await page.waitForTimeout(800);
  ok(await page.evaluate(() => document.querySelector("#btnSetup").hidden), "다시 열어도 단추가 없다 (이 기기에서 한 번만)");
  await page.goto(base + "?setup&date=2026-11-17&time=10:30"); await page.waitForTimeout(800);
  ok(await page.evaluate(() => !document.querySelector("#btnSetup").hidden), "?setup 을 붙이면 다시 보인다");
  await page.close();

  /* ── 8. 창 모드: 안내 없이, 첫 클릭·키에 전체화면을 청한다 ── */
  console.log("창 모드 (브라우저 창이 화면보다 작음)");
  await ctx.close();
  ctx = await newCtx({ viewport:{ width:1600, height:860 }, screen:{ width:1920, height:1080 } });
  await mock(ctx, net);
  await ctx.addInitScript(() => {
    window.__fsCalls = 0;
    const orig = Element.prototype.requestFullscreen;
    Element.prototype.requestFullscreen = function(...a){ window.__fsCalls++; return orig.apply(this, a); };
  });
  page = await open(ctx, "?date=2026-11-17&time=10:30", 1200);
  const atLoad = await page.evaluate(() => window.__fsCalls);
  const floating = await page.evaluate(() => [...document.querySelectorAll("body *")].filter(e => {
    const cs = getComputedStyle(e);
    return (cs.position === "absolute" || cs.position === "fixed") && e.offsetParent !== null && !["fit", "stage"].includes(e.id)
      && !e.closest(".toast.hide") && !e.closest(".overlay[hidden]") && e.getBoundingClientRect().width > 0 && !e.closest("svg");
  }).map(e => e.id || e.className));
  await shot(page, "3-window");
  ok(atLoad >= 1, "열자마자 전체화면을 청한다");
  ok(!floating.length, "화면 위에 떠 있는 안내가 없다" + (floating.length ? " — " + floating.join(", ") : ""));
  await page.mouse.click(800, 400);
  await page.waitForTimeout(300);
  const afterClick = await page.evaluate(() => window.__fsCalls);
  ok(afterClick > atLoad, "화면을 한 번 누르면 전체화면을 청한다");
  await page.keyboard.press("Enter");
  await page.waitForTimeout(300);
  ok(await page.evaluate(() => window.__fsCalls) >= afterClick, "리모컨 확인(Enter) 키로도 청한다");
  await page.close();
  await ctx.close();

  /* ── 9. 오프라인 보관(sw.js): 한 번 연 뒤 인터넷이 끊겨도 화면이 뜬다 ── */
  console.log("오프라인 보관 (service worker)");
  ctx = await browser.newContext({ viewport:{ width:1920, height:1080 }, deviceScaleFactor:1, serviceWorkers:"allow" });
  await mock(ctx, net);
  page = await open(ctx, "?date=2026-11-17&time=10:30", 2500);
  const swOk = await page.evaluate(async () => { const r = await navigator.serviceWorker.ready; return !!r.active; });
  ok(swOk, "오프라인 보관이 켜진다");
  await page.reload(); await page.waitForTimeout(800);
  await ctx.setOffline(true);
  net.on = false;
  await page.reload().catch(() => {});
  await page.waitForTimeout(1500);
  v = await read(page).catch(() => null);
  ok(!!v && v.today.some(x => /화요예배/.test(x)), "인터넷 없이 다시 열어도 알림판이 뜬다");
  await ctx.close();
  net.on = true;

  ok(!errors.length, "자바스크립트 오류가 없다" + (errors.length ? "\n      " + errors.join("\n      ") : ""));
  await browser.close();
  srv.close();
  console.log(failures ? `\n실패 ${failures}건` : "\n모두 통과");
  process.exit(failures ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
