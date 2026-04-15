# 🚀 InfluxDB 3 Core

- InfluxDB’s latest storage engine is built on Apache Arrow and uses Apache DataFusion as its foundational query engine
- InfluxDB stores time series data in the Parquet file format.

## Setup

### Linux / macOS (Binary)

```sh
curl -O https://www.influxdata.com/d/install_influxdb3.sh && sh install_influxdb3.sh
```

### Windows (Docker)

For Windows environments, using the Docker image is recommended.

```sh
docker compose up -d
```

## Admin token

- \_admin : No expires Operator token
- Use `Preconfigured` admin token : [INFLUXDB3_ADMIN_TOKEN_FILE](https://docs.influxdata.com/influxdb3/core/admin/tokens/admin/preconfigured/)

```json
{
  "token": "apiv3_StbtJg5aLdow7GVJith74r3JkaM33rybXnGa73H1ILusomLvsfRp9rAwEqla5MRQVYJN4B1jw9oI3TdKn5UjpA",
  "name": "admin-token",
  "expiry_millis": 1807220391303
}
```

## Line Protocol

Line Protocol is a text-based format for writing points to InfluxDB.

**Format:** `table,tags fields timestamp`

**Example:**
```text
weather,city=Seoul temp=15.76,humidity=51 1712891427454286845
```

- **Table (Measurement)**: `weather`
- **Tags**: `city=Seoul` (Optional, indexed)
- **Fields**: `temp=15.76`, `humidity=51` (Required)
- **Timestamp**: `1712891427454286845` (Nanosecond precision, 19 digits)


### ☕ Java Client
- [InfluxDB v3 Java Client](https://docs.influxdata.com/influxdb3/core/reference/client-libraries/v3/java/)

> [!IMPORTANT]
> This client requires **Java 11 or later** and is compatible up to **Java 25**.
> The following JVM arguments are required at runtime:
> - All versions: `--add-opens=java.base/java.nio=ALL-UNNAMED`
> - **Java 25 or later**: `--sun-misc-unsafe-memory-access=allow` is also required.

#### 🚀 Getting Started (Gradle)
```gradle
dependencies {
    implementation 'com.influxdb:influxdb3-java:1.8.0'
}
```

## Considerations

- Partial deletion of data is not supported
- [Retention Period](https://docs.influxdata.com/influxdb3/core/reference/internals/data-retention/) is supported during database creation
