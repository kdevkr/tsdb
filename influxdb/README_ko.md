# 🚀 InfluxDB 3 Core

- InfluxDB의 최신 스토리지 엔진은 Apache Arrow를 기반으로 구축되었으며, Apache DataFusion을 기본 쿼리 엔진으로 사용합니다.
- InfluxDB는 시계열 데이터를 Parquet 파일 형식으로 저장합니다.

## Setup

### Linux / macOS (바이너리)

```sh
curl -O https://www.influxdata.com/d/install_influxdb3.sh && sh install_influxdb3.sh
```

### Windows (Docker)

윈도우 환경에서는 Docker 이미지 사용을 권장합니다.

```sh
docker compose up -d
```

## Admin token

- \_admin : 만료되지 않는 Operator 토큰
- 사전 설정된 관리자 토큰 사용: [INFLUXDB3_ADMIN_TOKEN_FILE](https://docs.influxdata.com/influxdb3/core/admin/tokens/admin/preconfigured/)

```json
{
  "token": "apiv3_StbtJg5aLdow7GVJith74r3JkaM33rybXnGa73H1ILusomLvsfRp9rAwEqla5MRQVYJN4B1jw9oI3TdKn5UjpA",
  "name": "admin-token",
  "expiry_millis": 1807220391303
}
```

## Line Protocol

Line Protocol은 InfluxDB에 데이터를 쓰기 위한 텍스트 기반 형식입니다.

**구성:** `table,tags fields timestamp`

**예시:**
```text
weather,city=Seoul temp=15.76,humidity=51 1712891427454286845
```

- **Table (Measurement)**: `weather`
- **Tags**: `city=Seoul` (선택 사항, 인덱스됨)
- **Fields**: `temp=15.76`, `humidity=51` (필수 사항)
- **Timestamp**: `1712891427454286845` (나노초 정밀도, 19자리)

### ☕ Java 클라이언트
- [InfluxDB v3 Java Client](https://docs.influxdata.com/influxdb3/core/reference/client-libraries/v3/java/)

> [!IMPORTANT]
> 이 클라이언트는 **Java 11 이상**을 요구하며, **Java 25**까지 호환됩니다.
> 실행 시 다음 JVM 인자가 필수적으로 필요합니다:
> - 모든 버전: `--add-opens=java.base/java.nio=ALL-UNNAMED`
> - **Java 25 이상**: `--sun-misc-unsafe-memory-access=allow` 추가 필수

## 주의사항

- 일부 데이터 부분 삭제 미지원
- [보존 기한(Retention Period)](https://docs.influxdata.com/influxdb3/core/reference/internals/data-retention/)은 데이터베이스 생성 시 지원
