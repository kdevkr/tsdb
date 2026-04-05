/ tick.q (TickerPlant - 데이터 관문)
/ 1. 로그 기록 (\L): 메시지 유실 방지를 위해 모든 인입 데이터를 디스크 로그 파일(.u.L)에 기록
/ 2. 시퀀스 관리 (.u.i): 각 메시지에 고유 번호를 부여하여 데이터 일관성 유지
/ 3. 데이터 배포: 인입된 데이터를 upd 함수를 통해 u.q의 배포 엔진으로 전달
/ 4. 인자: [src] [dst] [-t batch_ms] - 로그 위치와 배포 주기를 설정하여 구동

/ https://github.com/KxSystems/kdb-tick/blob/master/tick.q

/ q tick.q sym . -p 5001 </dev/null >foo 2>&1 &
"kdb+tick 2.8 2014.03.12"

/q tick.q SRC [DST] [-p 5010] [-o h]
system"l tick/",(src:first .z.x,enlist"sym"),".q"

if[not system"p";system"p 5010"]

\l tick/u.q
\d .u
ld:{if[not type key L::`$(-10_string L),string x;.[L;();:;()]];i::j::-11!(-2;L);if[0<=type i;-2 (string L)," is a corrupt log. Truncate to length ",(string last i)," and restart";exit 1];hopen L};
tick:{init[];if[not min(`time`sym~2#key flip value@)each t;'`timesym];@[;`sym;`g#]each t;d::.z.D;i::j::0;L::`$":",($[count y;y;"."]),"/",x,10#".";l::ld d;printSchemas[]};

/ 등록된 모든 TP 테이블의 스키마(컬럼, 타입, 속성) 출력
printSchemas:{
  typeck:"bgxhijefcspmdvutn";
  typnms:("boolean";"guid";"byte";"short";"int";"long";"real";"float";"char";"symbol";"timestamp";"month";"date";"timespan";"minute";"time";"timespan");
  sep:"===================================";
  -1 "\n",sep;
  -1 "  Tickerplant Table Schemas";
  -1 sep;
  tblIdx:0;
  while[tblIdx<count t;
    tblNm:t[tblIdx];
    metaTbl:0!meta tblNm;   / 0! 는 키를 제거함 — kdb+ 4.x 이상의 meta 함수는 키가 있는 테이블을 반환하기 때문
    colNms:metaTbl`c;
    colTps:metaTbl`t;
    colAts:metaTbl`a;
    padWidth:max {count string x} each colNms;
    -1 "  [",string[tblNm],"]";
    colIdx:0;
    while[colIdx<count colNms;
      colStr:string colNms[colIdx];
      typeChar:colTps[colIdx];
      attrSym:colAts[colIdx];
      typeIdx:typeck?typeChar;
      typeNm:$[typeIdx<count typeck;typnms[typeIdx];"?"];
      attrStr:$[`~attrSym;"";"  `",string[attrSym],"#"];
      -1 "    ",(colStr,(padWidth+2-count colStr)#" "),string[typeChar],"  ",typeNm,attrStr;
      colIdx+:1];
    -1 "";
    tblIdx+:1];
  -1 sep,"\n";
  };

/ TP 로그 파일을 보관할 일수 (0 설정 시 자동 삭제 비활성화)
retention:7;

/ .u.retention 일보다 오래된 TP 로그 파일 삭제 로직
cleanLogs:{
  if[(not l)|0=retention;:()];
  lpath:1_ string L;
  parts:"/" vs lpath;
  dir:"/" sv -1_ parts;
  pfx:(count[last parts]-10)# last parts;
  allFiles:string each key hsym `$":",dir;
  matches:allFiles where allFiles like pfx,"??????????";
  dates:"D"$'(-10#')matches;
  old:matches where (.z.D-retention)>dates;
  hdel each hsym each `$":",dir,"/",/:old;
  if[count old;-1 (string .z.P)," Deleted ",(string count old)," old TP log(s)."];
  };

endofday:{end d;d+:1;if[l;hclose l;l::0(`.u.ld;d)];cleanLogs[]};
ts:{if[d<x;if[d<x-1;system"t 0";'"more than one day?"];endofday[]]};

/ --- 캡처 기능: 인입되는 upd 메시지를 텍스트 파일로 기록 ---
capture:0b;               / 1b=ON 0b=OFF
capH:0;                   / 파일 핸들 (0 = 닫힘)
capFile:"./tp_capture.log";  / 출력 경로 (captureOn 호출 전 변경 가능)

capWrite:{[t;x]
  if[not capture;:()];
  capH (string .z.P)," upd ",(string t)," ",ssr[-3!x;"\n";" "],"\n";
  };

captureOn:{
  if[capture;-1 "Capture already ON.";:()];
  capH::hopen `$":",capFile;
  capture::1b;
  -1 (string .z.P)," Capture ON -> ",capFile;
  };

captureOff:{
  if[not capture;-1 "Capture already OFF.";:()];
  capture::0b;
  if[capH;hclose capH;capH::0];
  -1 (string .z.P)," Capture OFF.";
  };
/ ---

if[system"t";
 .z.ts:{pub'[t;value each t];@[`.;t;@[;`sym;`g#]0#];i::j;ts .z.D};
 upd:{[t;x]
 if[not -16=type first first x;if[d<"d"$a:.z.P;.z.ts[]];a:"n"$a;x:$[0>type first x;a,x;(enlist(count first x)#a),x]];
 t insert x;if[l;l enlist (`upd;t;x);j+:1];capWrite[t;x];}];

if[not system"t";system"t 1000";
 .z.ts:{ts .z.D};
 upd:{[t;x]ts"d"$a:.z.P;
 if[not -16=type first first x;a:"n"$a;x:$[0>type first x;a,x;(enlist(count first x)#a),x]];
 f:key flip value t;pub[t;$[0>type first x;enlist f!x;flip f!x]];if[l;l enlist (`upd;t;x);i+:1];capWrite[t;x];}];

\d .
.u.tick[src;.z.x 1];

\
 사용되는 전역 변수 목록:
 .u.w         - 테이블별 (핸들;심볼) 구독 관리 딕셔너리
 .u.i         - 로그 파일 내 메시지 시퀀스 (Disk I/O 기준)
 .u.j         - 전체 메시지 카운트 (로그 + 버퍼링 데이터 포함)
 .u.t         - 관리 대상 테이블 이름 리스트
 .u.L         - TP 로그 파일명 (예: `:./sym2008.09.11)
 .u.l         - TP 로그 파일 핸들
 .u.d         - 현재 날짜 파티션
 .u.retention - TP 로그 보관 일수 (0은 무한 보관)
 .u.capture   - 메시지 캡처 활성화 여부 (1b=ON/0b=OFF)
 .u.capFile   - 캡처 결과물 출력 경로
 .u.capH      - 캡처 파일 핸들

/test
>q tick.q
>q tick/ssl.q

/run
> q tick.q sym . -p 5010              / 1. Tickerplant (TP)
> q tick/r.q :5010 . -p 5011          / 2. Real-time DB (RDB)
> q tick/h.q . -p 5012                / 3. Historical DB (HDB)