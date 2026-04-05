/ rts.q (Real-Time Service - 실시간 전담 쿼리 서버)
/ 1. 실시간 쿼리 전담: GW 도입 시 메모리 데이터를 대상으로 하는 빠른 조회를 담당
/ 2. 인메모리 적재: TickerPlant로부터 받은 실시간 데이터를 메모리에 유지
/ 3. EOD 처리 (.u.end): 데이터 저장 없이 메모리 테이블만 초기화 (HDB 저장은 r.q가 담당)
/ 4. 자동 재연결: TP 연결 유실 시 r.q와 동일한 점진적 재연결(Backoff) 로직 수행

/ q tick/rts.q [host]:port[:usr:pwd] [host]:port[:usr:pwd]

if[not "w"=first string .z.o;system "sleep 1"];

upd:insert;

/ TickerPlant 및 HDB 포트 설정 (기본값: 5010, 5012)
.u.x:.z.x,(count .z.x)_(":5010";":5012");

/ EOD(End of Day) 처리: 메모리 초기화 (HDB 저장은 하지 않음)
.u.end:{[x]
  -1 (string .z.P)," [INFO] EOD Signal received for [",string[x],"]. Clearing memory tables...";
  t:tables`.;
  / 전역 네임스페이스의 각 테이블 데이터 삭제
  {@[`.;x;0#]} each t;
  -1 (string .z.P)," [INFO] RTS Memory tables cleared.";
 };

/ 로그 리플레이 중 인서트 실패 시 에러 핸들러
.u.repUpdErr:{[t;e] 
  -2 (string .z.P)," [ERROR] TP log replay insert error in table [",string[t],"]: ",e;
  :0b; 
 };

/ 로그 리플레이 중 치명적 오류 발생 시 에러 핸들러
.u.repFatalErr:{[y;x] 
  -2 (string .z.P)," [FATAL] TP log replay aborted at log file ",(string y 1),": ",x;
  :();
 };

/ 스키마 초기화 및 로그 파일로부터 동기화; HDB 경로로 이동(클라이언트 저장을 위함)
.u.rep:{
  (.[;();:;].)each x;
  if[null first y;:()];
  if[null y 1;:()]; / 로그 파일 경로가 null이면 리플레이 건너뜀
  / 리플레이 중 upd를 래핑하여 로그를 남기고 타입 오류가 발생하는 메시지 건너뜀
  updSave:upd;
  set[`upd;{[t;x] .[insert;(t;x);.u.repUpdErr[t]]}];
  @[-11!;y;.u.repFatalErr[y]];
  set[`upd;updSave];
  system "cd ",1_-10_string first reverse y};

/ --- 재연결 로직 (Backoff) ---
/ 현재 연결 핸들 및 재시도 카운터
h:0;
retries:0;

/ 재시도 설정 (단위: ms)
shortInt:5000;
longInt:60000;

/ TickerPlant 연결 에러 핸들러
.u.errTP:{[e]
  -1 (string .z.P)," [ERROR] Failed to connect to TickerPlant at ",(.u.x 0),": ",e;
  :0;
 };

/ 백오프를 포함한 구독 함수
.u.conn:{
  retries::retries + 1;
  hp:@[hopen;`$":",.u.x 0;.u.errTP];
  if[hp>0;
    -1 (string .z.P)," [INFO] RTS connected after ",(string retries)," attempt(s).";
    retries::0; 
    h::hp;
    .u.rep .(hp)"(.u.sub[`;`];`.u `i`L)";
    system "t 0"; / 연결 성공 후 타이머 중지
  ];
  if[hp=0;
    / 3단계 백오프: 5초(1-5회), 10초(6-10회), 60초(11회 이상)
    interval:$[retries<=5;5000;$[retries<=10;10000;60000]];
    -1 (string .z.P)," [RETRY] attempt=",string[retries]," next_interval=",string[interval div 1000],"s";
    system "t ",string interval;
  ];
 };

/ 연결 종료 처리 (TickerPlant 중단 시)
.z.pc:{[hp]
  if[hp=h;
    -1 (string .z.P)," [WARN] RTS Connection to TickerPlant lost! handle=",string hp;
    h::0;
    retries::0; / 카운터를 초기화하여 짧은 간격부터 다시 시작
    -1 (string .z.P)," [INFO] Starting initial retry loop (5s interval)...";
    .u.conn[]; / 즉시 시도
  ];
 };

/ 타이머가 재연결 시도를 트리거함
.z.ts:{.u.conn[]};

/ 초기 실행 세션
-1 (string .z.P)," [INFO] Initializing RTS process with TP reconnection support...";
.u.conn[];
/ ---
