/ r.q (Real-time Database - 실시간 저장소)
/ 1. 인메모리 적재: TickerPlant로부터 받은 실시간 데이터를 upd를 통해 메모리 테이블에 insert
/ 2. EOD 처리 (.u.end): 날짜 변경 시 메모리 데이터를 HDB 파티션으로 덤프하고 메모리 초기화
/ 3. 자동 재연결: TP 연결 유실 시 5s/10s/1m 간격으로 점진적 재연결 시도
/ 4. 데이터 정합성 체크: 저장 전 파티션 중복 및 Out-of-bound 데이터 실시간 검사

/ q tick/r.q [host]:port[:usr:pwd] [host]:port[:usr:pwd]

if[not "w"=first string .z.o;system "sleep 1"];

\l tick/env.q

/ TickerPlant 및 HDB 포트 설정 (기본값: TP_ADDR, HDB_DIR)
tpAddr:$[`TP_ADDR in key `.; .TP_ADDR; ":5010"];
hdbDir:$[`HDB_DIR in key `.; .HDB_DIR; "."];
.u.x:.z.x,(count .z.x)_(tpAddr; hdbDir);

/ 포트 설정 (인자 -p 우선, 없으면 .env RDB_PORT 기반)
if[not system "p"; 
  pVal:$[`RDB_PORT in key `.; .RDB_PORT; 5011];
  system "p ",string pVal
 ];

/ EOD(End of Day) 처리: 저장, 메모리 초기화, HDB 리로드 신호
.u.end:{[x]
  if[null x; x:.z.D-1]; / x가 null이면 전날을 기본값으로 사용
  t:tables`.;t@:where `g=attr each t@\:`sym;
  / HDB 경로를 정확히 확인하고 파일 핸들(hsym)로 변환
  hdbPath:hsym`$.u.x 1;
  datePath:hdbPath,`$string x;
  / 메모리에 'sym' 변수가 있는지 확인하여 'sym 에러 방지
  if[not `sym in key `.;
    -1 (string .z.P)," [INFO] Initializing global memory 'sym' variable...";
    `sym set `symbol$();
  ];
  / HDB 루트에 'sym' 파일이 있는지 확인
  if[null key hdbPath,`sym;
    -1 (string .z.P)," [INFO] Initializing global sym file in HDB root...";
    (hdbPath,`sym) set `symbol$();
  ];
  / 파티션 폴더에 기존 데이터가 있는지 확인 및 로깅
  files:key datePath;
  if[count files;
    -1 (string .z.P)," [WARN] Existing data detected in partition [",string[x],"]: ",-3!files;
  ];
  if[not count files;
    -1 (string .z.P)," [INFO] Partition [",string[x],"] is clear. Proceeding with save...";
  ];
  / 파티션 날짜를 벗어난 데이터를 확인하고 저장 전에 필터링(삭제)
  {[dt;tbl]
    dts:distinct exec "d"$time from tbl; / 'time' 컬럼이 있다고 가정
    oob:dts except dt;
    if[count oob;
      oobCnt:count select from tbl where not ("d"$time)=dt;
      -1 (string .z.P)," [FILTER] Removing ",(string oobCnt)," out-of-bound rows from [",string[tbl],"] before saving to [",string[dt],"]";
      / 실제로 OOB(Out-of-bound) 데이터를 필터링
      @[`.;tbl;{ select from x where ("d"$time)=y }[;dt]];
    ];
  }[x] each t;
  / 메모리 데이터를 HDB로 저장하고 데이터가 있으면 로드
  if[any count each t;
    .Q.hdpf[hdbPath;`:.;x;`sym];
    @[;`sym;`g#] each t;
    -1 (string .z.P)," [INFO] Partition [",string[x],"] saved successfully.";
  ];
  if[not any count each t;
    -1 (string .z.P)," [INFO] No data in memory to save for partition [",string[x],"]. Skipping save.";
  ];
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
    -1 (string .z.P)," [INFO] Connected after ",(string retries)," attempt(s).";
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
    -1 (string .z.P)," [WARN] Connection to TickerPlant lost! handle=",string hp;
    h::0;
    retries::0; / 카운터를 초기화하여 짧은 간격부터 다시 시작
    -1 (string .z.P)," [INFO] Starting initial retry loop (5s interval)...";
    .u.conn[]; / 즉시 시도
  ];
 };

/ 타이머가 재연결 시도를 트리거함
.z.ts:{.u.conn[]};

/ 초기 실행 세션
-1 (string .z.P)," [INFO] Initializing RDB process with TP reconnection support...";
.u.conn[];
/ ---
