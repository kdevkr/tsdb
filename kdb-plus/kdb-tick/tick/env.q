/ env.q (.env 파일 로더)
/ 1. 설정값 추출: .env 파일을 읽어 키-값 쌍을 전역 변수로 자동 생성
/ 2. 타입 변환: 숫자(포트, 인터벌 등)로 된 문자열을 kdb+ 정수형으로 자동 변환
/ 3. 주석 및 공백 처리: #로 시작하는 주석과 빈 줄을 건너뜀

.env.load:{
  / .env 파일의 절대 경로를 찾기 위해 부모 디렉토리 등 확인 (현재는 실행 디렉토리 기준)
  envPath:hsym `.env;
  if[null key envPath; :()]; / 파일이 없으면 무시
  
  / 한 줄씩 읽기
  raw:read0 envPath;
  
  / 주석 및 빈 줄 필터링
  lines:raw where (not raw like "#*") and (count each raw)>0;
  
  / 키-값 쌍 분할 ("=" 기준)
  kv: "=" vs' lines;
  
  {
    k:`$first x;
    v:"=" sv 1_ x; / 값에 =가 포함되어 있을 경우를 대비한 병합
    
    / 숫자로 변환 가능한지 체크
    nv:@[{"I"$x};v;{0N}];
    
    / 전역 네임스페이스(.)에 변수 강제 설정
    set[`.Q.dd[`.`;k]; $[not null nv; nv; v]];
    
    -1 (string .z.P)," [ENV] Config set: ",(string k),"=", $[not null nv; string nv; v];
  } each kv;
 };

/ 초기 로딩 실행
.env.load[];
/ ---
