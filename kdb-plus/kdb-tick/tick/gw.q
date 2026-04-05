/ gw.q (Gateway - 쿼리 분산 게이트웨이)
/ 1. 쿼리 라우팅: 클라이언트의 요청을 실시간(RTS)과 과거(HDB) 서버로 분산 실행
/ 2. 비동기 지연 응답 (Deferred Response): -30! 메커니즘을 사용하여 무거운 쿼리 수행 중에도 GW 가용성 유지
/ 3. 데이터 통합 (Aggregation): 실시간(In-memory)과 과거(Historical) 데이터를 하나로 통합하여 클라이언트에 응답

\l tick/env.q

/ 설정: 대상 프로세스 주소
rtsAddr:$[null RTS_ADDR; ":5013"; RTS_ADDR]; / 실시간 서비스 (메모리 쿼리)
hdbAddr:$[null HDB_ADDR; ":5012"; HDB_ADDR]; / 과거 데이터베이스 (디스크 쿼리)

/ 핸들 관리
rtsH:0; hdbH:0;

/ 포트 설정 (인자 -p 우선, 없으면 .env GW_PORT 기반)
if[not system "p"; system "p ",string $[null GW_PORT; 5014; GW_PORT]];

/ 연결 로직
.gw.conn:{
  rdbH::@[hopen;`$rtsAddr;{0}];
  hdbH::@[hopen;`$hdbAddr;{0}];
  -1 (string .z.P)," [INFO] GW connected to RTS=",string[rdbH]," HDB=",string[hdbH];
 };

/ 지연 응답을 위한 대기 중인 쿼리 트래킹
/ ([쿼리_ID] 클라이언트_핸들; 상태; RTS_데이터; HDB_데이터; 시작_시간)
queries:([id:`int$()] client:`int$(); rtsReady:`boolean$(); hdbReady:`boolean$(); rtsData:(); hdbData:(); start:.z.p);
qid:0;

/ RTS/HDB용 콜백 함수
.gw.callback:{[id;source;data]
  if[not id in key queries;:()]; / 이미 처리되었거나 만료된 경우 무시
  
  / 소스별 결과 업데이트
  $[source=`rts; 
    update rtsReady:1b, rtsData:enlist data from `queries where id=id;
    update hdbReady:1b, hdbData:enlist data from `queries where id=id
  ];
  
  row:queries[id];
  if[row[`rtsReady] and row[`hdbReady];
    / 모든 결과 도착 - 데이터 통합 후 클라이언트에 응답
    final:raze (row[`hdbData]; row[`rtsData]); / HDB 데이터 먼저, 그 다음 RTS 데이터
    -30!(row`client; 0b; final); / 클라이언트에 결과를 전송하고 지연(deferred) 상태 종료
    delete from `queries where id=id;
    -1 (string .z.P)," [INFO] Query id=",(string id)," handled in ",(string `int$0.000001*.z.p-row`start),"ms";
  ];
 };

/ 메인 쿼리 진입점 (지연 응답 로직)
.z.pg:{[q]
  if[not (rtsH>0) and (hdbH>0); .gw.conn[]]; / 핸들이 열려 있는지 확인
  
  if[not (rtsH>0) and (hdbH>0); 
    :'" [ERROR] Underlying RDB/HDB handles not available.";
  ];

  / 쿼리 ID 생성 및 대기 상태 등록
  id:qid::qid+1;
  `queries insert (id;.z.w;0b;0b;();();.z.p);

  / 쿼리 비동기 분산 실행
  / 구문: (neg 핸들)({GW_콜백}; 쿼리_ID; 소스_태그; 쿼리_문자열)
  (neg rdbH)({[id;q] (neg .z.w)(".gw.callback";id;`rts;value q)}; id; q);
  (neg hdbH)({[id;q] (neg .z.w)(".gw.callback";id;`hdb;value q)}; id; q);

  / 지연 모드 진입 - -30!를 호출할 때까지 클라이언트 대기
  -30!(::); 
 };

/ 초기 연결 시도
.gw.conn[];

-1 (string .z.P)," [INFO] Gateway process ready and serving at port ",string system"p";

/ 기본 로깅
.z.po:{ -1 (string .z.P)," [CONN] handle=",(string x)," user=",string .z.u; };
.z.pc:{ -1 (string .z.P)," [DISC] handle=",string x; };
