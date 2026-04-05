/ h.q (Historical Database - 과거 데이터 서버)
/ 1. 파티션 로딩 (\l): 디스크의 과거 데이터를 메모리 매핑(mmap) 방식으로 로드하여 서빙
/ 2. 자동 리로드 (.u.reload): RDB 저장 완료 신호를 받아 새 파티션을 즉시 인식
/ 3. 쿼리 모니터링: 모든 조회 쿼리의 수행 시간(ms)과 사용자 정보를 트래킹하여 로그 기록
/ 4. 자원 보호: 무거운 쿼리 차단을 위해 30초 타임아웃(system "T 30") 기본 설정

/ 사용법: q h.q [HDB_경로] [-p 5012]

/ 커맨드 라인 인자로부터 파티션된 데이터 경로 추출
args:.z.x where not .z.x like "-*";
hdbDir:$[count args; last args; "."];
-1 (string .z.P)," [INFO] Loading HDB from: ",hdbDir;

/ 원시 경로 문자열을 사용하여 데이터베이스 로딩 시도
system "l ",hdbDir;

/ 포트가 지정되지 않은 경우 기본 포트 설정
if[not system "p"; 
  -1 (string .z.P)," [INFO] No port specified, defaulting to 5012";
  system "p 5012";
 ];

-1 (string .z.P)," [INFO] HDB process ready and serving at port ",string system"p";

/ --- 고도화된 HDB 기능 ---
/ 1. EOD 동기화를 위한 리로드 함수: RDB/TP가 HDB 새로고침을 트리거할 때 사용
.u.reload:{
  -1 (string .z.P)," [INFO] Reloading HDB to catch new partitions...";
  system "l ",hdbDir;
  -1 (string .z.P)," [INFO] HDB reload complete.";
 };

/ 2. 자원 관리: 블로킹 방지를 위한 기본 쿼리 타임아웃(30초) 설정
system "T 30";

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
