/ w.q (Writer - 디스크 직접 적재 서버)
/ 1. 실시간 디스크 적재: TickerPlant로부터 받은 데이터를 메모리에 쌓지 않고 즉시 HDB 파티션에 기록
/ 2. 파티션 관리: 데이터의 날짜(time/date)를 분석하여 해당 날짜의 디스크 폴더로 라우팅
/ 3. 데이터 영속성: RDB가 EOD에 저장하기 전에 장애가 나더라도, w.q를 통해 디스크에 이미 기록된 데이터는 보호됨
/ 4. 심볼 열거: .Q.en을 사용하여 HDB의 전역 sym 파일과 정합성을 유지하며 적재

\l tick/env.q

/ 설정
tpAddr:$[`TP_ADDR in key `.; .TP_ADDR; ":5010"];
hdbDir:$[`HDB_DIR in key `.; .HDB_DIR; "."];
.u.x:.z.x,(count .z.x)_(tpAddr; hdbDir);
hdbPath:hsym `$.u.x 1;
hdbAddr:$[`HDB_ADDR in key `.; .HDB_ADDR; ":5012"]; / 리로딩을 위한 HDB 프로세스 주소
hH:0; / HDB용 핸들

/ 포트 설정 (인자 -p 우선, 없으면 .env WDB_PORT 기반)
if[not system "p"; 
  pVal:$[`WDB_PORT in key `.; .WDB_PORT; 5015];
  system "p ",string pVal
 ];

/ 보조 함수: 리로딩을 위해 HDB에 연결
.w.connHDB:{ hH::@[hopen;`$hdbAddr;{0}]; };

/ 보조 함수: sym 파일 및 핸들이 존재하는지 확인
if[not `sym in key `.; `sym set `symbol$()];
if[null key hdbPath,`sym; (hdbPath,`sym) set `symbol$()];

/ 고도화된 upd: 메모리 버퍼링
/ 매 틱마다 디스크에 쓰는 대신 메모리 테이블에 인서트하여 모아둠
upd:{[t;x]
  data:$[100h=type x; x; flip (cols t)!x]; 
  t insert data; / 메모리 내 버퍼링
 };

/ 디스크 I/O 부하 감소를 위한 벌크 쓰기 (Flush) 메커니즘
/ 매 분(60,000ms) 실행되도록 스케줄링됨
.w.flush:{
  tabs:tables`.;
  / 버퍼링된 데이터가 있는 테이블만 처리
  tabs:tabs where 0 < count each value each tabs;
  
  if[not count tabs; :()]; / 플러시할 데이터 없음
  
  -1 (string .z.P)," [WDB] Starting scheduled flush for ",(string count tabs)," tables...";
  
  / 각 버퍼링된 테이블 순회
  {[t]
    data:value t;
    dts:distinct "d"$data`time;
    
    {[t;hdb;d;df]
      pPath:.Q.dd[.Q.dd[hdb;d];t]; 
      
      / 미래 또는 다른 날짜 파티션에 쓰기 작업 시 명시적으로 로깅
      msg:$[d>.z.D; " [FUTURE]"; $[d<.z.D; " [PAST]"; " [PRESENT]"]];
      -1 (string .z.P),msg," Appending ",(string count df)," rows to partition [",string[d],"] table [",string[t],"]";
      
      .[pPath;();,;.Q.en[hdb] df];
    }[t;hdbPath] peach (dts!{ [dt;df] select from df where ("d"$time)=dt }[;data] each dts);
    
    / 디스크 쓰기 성공 후 메모리 버퍼 삭제
    @[`.;t;0#];
  } each tabs;

  / 모든 테이블이 플러시된 후 HDB에 리로드 신호 전송
  if[hH=0; .w.connHDB[]];
  if[hH>0; (neg hH)".u.reload[]"; ];
  
  -1 (string .z.P)," [WDB] Scheduled flush and HDB reload complete.";
 };

/ 벌크 쓰기를 위한 타이머 설정
system "t ",string $[`WDB_FLUSH_INTERVAL in key `.; .WDB_FLUSH_INTERVAL; 60000];
.z.ts:{
  .w.flush[]; / 스케줄링된 디스크 쓰기
  if[h=0; .u.conn[]]; / 타이머가 이미 사용 중인지 재연결 로직 확인
 };

/ --- 표준 연결 및 TP 레포 로직 (r.q에서 상속받음) ---
/ 에러 핸들러
.u.repUpdErr:{[t;e] -2 (string .z.P)," [ERROR] TP upd error in [",string[t],"]: ",e; :0b; };
.u.repFatalErr:{[y;x] -2 (string .z.P)," [FATAL] TP replay error at ",(string y 1),": ",x; :(); };

/ 스키마 초기화 (WDB의 경우 대개 전체 리플레이는 필요 없으나 스키마는 동기화함)
.u.rep:{ (.[;();:;].)each x; system "cd ",1_-10_string first reverse y };

h:0; retries:0;
.u.errTP:{ -1 (string .z.P)," [ERROR] Failed to connect to TP: ",e; :0; };

.u.conn:{
  retries::retries + 1;
  hp:@[hopen;`$":",.u.x 0;.u.errTP];
  if[hp>0;
    -1 (string .z.P)," [INFO] WDB connected to TP after ",(string retries)," attempt(s).";
    retries::0; h::hp;
    / 구독 및 스키마 동기화; 실시간으로 쓰기 때문에 전체 로그 리플레이는 반드시 필요하지 않음
    .u.rep .(hp)"(.u.sub[`;`];`.u `i`L)";
    system "t 0";
  ];
  if[hp=0;
    interval:$[retries<=5;5000;$[retries<=10;10000;60000]];
    system "t ",string interval;
  ];
 };

.z.pc:{[hp] if[hp=h; h::0; retries::0; .u.conn[]]; };
.z.ts:{.u.conn[]};

/ 초기 연결
-1 (string .z.P)," [INFO] Initializing WDB process (Direct-to-Disk)...";
.u.conn[];
/ ---
