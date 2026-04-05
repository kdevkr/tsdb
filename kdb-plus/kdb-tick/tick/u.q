/ u.q (구독 및 전송 엔진)
/ 1. 구독자 관리 (w): 특정 테이블/심볼을 구독 중인 클라이언트 핸들 추적
/ 2. 구독 기능 (.u.sub): (handle) ".u.sub[table;sym]"을 통해 구독 레지스트리 등록
/ 3. 데이터 푸시 (.u.pub): 새로운 데이터를 구독 중인 핸들에 비동기 전송
/ 4. 연결 해제 관리: 클라이언트 연결 종료 시 (.z.pc) 구독자 자동 제거

\d .u
init:{w::t!(count t::tables`.)#()}

del:{w[x]_:w[x;;0]?y};
.z.po:{
  xip:"." sv string(.z.a div 16777216;(.z.a div 65536)mod 256;(.z.a div 256)mod 256;.z.a mod 256);
  rpid:@[x;".z.i";{0N}];          / 원격 PID (kdb+ 클라이언트가 아니면 null)
  rfile:@[x;".z.f";{`}];          / 원격 스크립트 이름 (예: r, feed)
  pidstr:$[null rpid;"";" pid=",string rpid];
  nmstr:$[`~rfile;"";" proc=",string rfile];
  -1 (string .z.P)," [CONN] handle=",(string x)," ip=",xip," user=",(string .z.u),pidstr,nmstr;
  };
.z.pc:{del[;x]each t;-1 (string .z.P)," [DISC] handle=",string x};

sel:{$[`~y;x;select from x where sym in y]}

pub:{[t;x]{[t;x;w]if[count x:sel[x]w 1;(neg first w)(`upd;t;x)]}[t;x]each w t}

add:{$[(count w x)>i:w[x;;0]?.z.w;.[`.u.w;(x;i;1);union;y];w[x],:enlist(.z.w;y)];(x;$[99=type v:value x;sel[v]y;@[0#v;`sym;`g#]])}

sub:{if[x~`;:sub[;y]each t];if[not x in t;'x];del[x].z.w;add[x;y]}

end:{(neg union/[w[;;0]])@\:(`.u.end;x)}