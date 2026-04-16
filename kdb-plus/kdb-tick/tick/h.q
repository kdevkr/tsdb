/ h.q (Historical Database - 과거 데이터 서버)
/ 1. 파티션 로딩 (\l): 디스크의 과거 데이터를 메모리 매핑(mmap) 방식으로 로드하여 서빙
/ 2. 자동 리로드 (.u.reload): RDB 저장 완료 신호를 받아 새 파티션을 즉시 인식
/ 3. 쿼리 모니터링: 모든 조회 쿼리의 수행 시간(ms)과 사용자 정보를 트래킹하여 로그 기록
/ 4. 자원 보호: 무거운 쿼리 차단을 위해 30초 타임아웃(system "T 30") 기본 설정

\l tick/env.q

/ 커맨드 라인 인자로부터 파티션된 데이터 경로 추출 (없으면 .env HDB_DIR 사용)
args:.z.x where not .z.x like "-*";
hdbVal:$[`HDB_DIR in key `.; .HDB_DIR; "./hdb"];
hdbPath:$[count args; last args; hdbVal];

/ 경로가 존재하는지 확인 (없으면 경고 후 대기)
if[null key hsym `$hdbPath;
  -1 (string .z.P)," [WARN] HDB directory [",hdbPath,"] is missing. Waiting for first end-of-day save...";
 ];
if[not null key hsym `$hdbPath;
  -1 (string .z.P)," [INFO] Loading HDB from: ",hdbPath;
 ];

/ 원시 경로 문자열을 사용하여 데이터베이스 로딩 시도 (sym 파일이 있을 경우에만 실행하여 .env 파일 충돌 방지)
if[not null key (hsym `$hdbPath),`sym;
  -1 (string .z.P)," [INFO] 'sym' file found. Initializing HDB load...";
  system "l ",1_ string hsym `$hdbPath;
 ];
if[null key (hsym `$hdbPath),`sym;
  -1 (string .z.P)," [WARN] No 'sym' file found in ",hdbPath,". HDB initialization skipped.";
 ];

/ 포트 설정 (인자 -p 우선, 없으면 .env HDB_PORT 기반)
if[not system "p"; 
  pVal:$[`HDB_PORT in key `.; .HDB_PORT; 5012];
  system "p ",string pVal
 ];

-1 (string .z.P)," [INFO] HDB process ready and serving at port ",string system"p";

/ --- 고도화된 HDB 기능 ---
/ 1. EOD 동기화를 위한 리로드 함수: RDB/TP가 HDB 새로고침을 트리거할 때 사용
.u.reload:{
  -1 (string .z.P)," [INFO] Reloading HDB to catch new partitions...";
  system "l ",hdbPath; / hdbPath 변수 사용 (hdbDir 대체)
  -1 (string .z.P)," [INFO] HDB reload complete.";
 };

/ 2. 자원 관리: 블로킹 방지를 위한 기본 쿼리 타임아웃 설정
tVal:$[`QUERY_TIMEOUT in key `.; .QUERY_TIMEOUT; 30];
system "T ",string tVal;

/ 3. 성능 및 감사 로깅: 누가 어떤 쿼리를 수행하는지 모니터링
/ 동기 쿼리 로깅
.z.pg:{[q]
  start:.z.p;
  res:value q;
  dur:string `int$0.000001 * (string .z.p - start); / 밀리초 단위
  -1 (string .z.P)," [QUERY] synchronous, user=",string[.z.u]," handle=",string[.z.w]," duration=",dur,"ms, q=",string[q];
  res
 };

/ 비동기 쿼리 로깅
.z.ps:{[q]
  start:.z.p;
  value q;
  dur:string `int$0.000001 * (string .z.p - start);
  -1 (string .z.P)," [QUERY] asynchronous, user=",string[.z.u]," handle=",string[.z.w]," duration=",dur,"ms, q=",string[q];
 };

/ 4. 연결 모니터링 (개선됨)
.z.po:{
  xip:"." sv string(.z.a div 16777216;(.z.a div 65536)mod 256;(.z.a div 256)mod 256;.z.a mod 256);
  -1 (string .z.P)," [CONN] handle=",(string x)," ip=",xip," user=",string .z.u;
 };

.z.pc:{-1 (string .z.P)," [DISC] handle=",string x};
/ ---
