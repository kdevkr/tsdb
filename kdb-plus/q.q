/ q.q - kdb+ 프로세스 공통 초기화 스크립트
/ .z.pg 및 .z.ps에 대한 예외 처리(trap) 로깅 기능 추가

/ 에러 발생 시 처리 (기본 응답 및 오류 처리는 그대로 유지하면서 로그 및 스택 트레이스 출력)
.proc.err:{[typ;q;e]
  / 로그 출력 중에 발생할 수 있는 부가적인 에러도 트랩하여 원본 처리 흐름 보호
  msg:(-3!q); / 쿼리 내용을 안전하게 문자열로 변환
  bt:.Q.sbt .Q.bt[]; / 현재 스택 트레이스(Backtrace) 문자열 생성
  @[{-1 (string .z.P)," [ERROR] Query [",x,"] failed: ",y," - Error: ",z,"\nStack Trace:\n",a}[typ;msg;e];bt;()];
  'e; / 기존 동작(에러 리턴) 유지를 위해 에러 재발생
 };

/ 1. 원본 핸들러 보관 (정의되어 있지 않다면 기본 연산인 value 사용)
/ 이전에 이미 래핑된 경우를 방지하기 위해 래핑 여부를 체크하여 할당
if[not `orig_pg in key `.proc; .proc.orig_pg:@[{.z.pg};();{value}]];
if[not `orig_ps in key `.proc; .proc.orig_ps:@[{.z.ps};();{value}]];

/ 2. 핸들러 래핑 적용
/ .[f;x;g] 구문에서 g는 (내부 에러 발생 시) 에러 문자열을 인자로 받는 단일 인자 함수여야 함.
.z.pg:{[q] .[.proc.orig_pg; enlist q; {.proc.err["SYNC";x;y]}[q]]};
.z.ps:{[q] .[.proc.orig_ps; enlist q; {.proc.err["ASYNC";x;y]}[q]]};

-1 (string .z.P)," [INFO] Exception handling installed for .z.pg and .z.ps";