package org.example;

import com.influxdb.v3.client.InfluxDBClient;
import io.github.cdimascio.dotenv.Dotenv;

public class Main {
    public static void main(String[] args) {
        System.out.println("InfluxDB Java Client Project Initialized!");

        // 상위 폴더의 .env 파일을 로드합니다 (실행 위치가 d:\tsdb 인 경우 기준)
        Dotenv dotenv = Dotenv.configure()
                .directory("./influxdb") 
                .ignoreIfMissing()
                .load();

        String host = dotenv.get("INFLUX_HOST", "http://localhost:8086");
        String tokenStr = dotenv.get("INFLUX_TOKEN");
        String database = dotenv.get("INFLUX_DATABASE", "weather_data");

        if (tokenStr == null || tokenStr.isEmpty()) {
            System.err.println("Error: INFLUX_TOKEN is not defined in .env or environment variables.");
            return;
        }

        char[] token = tokenStr.toCharArray();

        try (InfluxDBClient client = InfluxDBClient.getInstance(host, token, database)) {
            System.out.println("Connecting to InfluxDB at " + host);
            // 성공적으로 클라이언트가 생성되면 연결 성공 메시지 출력
            System.out.println("InfluxDB Client Initialized Successfully.");
        } catch (Exception e) {
            System.err.println("Failed to connect to InfluxDB: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
