package org.example;

import com.influxdb.v3.client.InfluxDBClient;
import com.influxdb.v3.client.Point;
import io.github.cdimascio.dotenv.Dotenv;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.ToString;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Stream;

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
            System.out.println("InfluxDB Client Initialized Successfully.");

            // 1. Write Data
            System.out.println("\n--- Writing Data ---");
            Point point = Point.measurement("weather")
                    .setTag("city", "Seoul")
                    .setField("temp", 15.76)
                    .setField("humidity", 51)
                    .setTimestamp(Instant.now());

            client.writePoint(point);
            System.out.println("Point written: " + point.toLineProtocol());

            // 2. Query Data (Object[] 배열 -> WeatherData 객체로 매핑)
            System.out.println("\n--- Querying Data ---");
            String sql = "SELECT time, city, temp, humidity FROM weather WHERE time > now() - interval '1 hour' ORDER BY time DESC LIMIT 5";
            System.out.println("Querying with SQL: " + sql);
            
            try (Stream<Object[]> stream = client.query(sql)) {
                stream.map(WeatherData::fromRow)
                    .forEach(data -> {
                        System.out.printf("Time: %s | City: %s | Temp: %.2f | Humidity: %d%n",
                                data.getTime(),
                                data.getCity(),
                                data.getTemp(),
                                data.getHumidity());
                    });
            }

            // 3. Batch Write (v3 SDK에서는 BatchPoints 클래스 대신 Stream<Point>를 사용합니다)
            System.out.println("\n--- Batch Writing Data ---");
            Point p1 = Point.measurement("weather")
                    .setTag("city", "Busan")
                    .setField("temp", 12.5)
                    .setField("humidity", 45)
                    .setTimestamp(Instant.now());

            Point p2 = Point.measurement("weather")
                    .setTag("city", "Incheon")
                    .setField("temp", 13.2)
                    .setField("humidity", 48)
                    .setTimestamp(Instant.now());

            List<Point> pointsList = Arrays.asList(p1, p2);
            client.writePoints(pointsList);
            System.out.println("Batch points written successfully.");

        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        }
    }
}

/**
 * Weather 데이터를 담는 Bean 클래스
 */
@Getter
@NoArgsConstructor
@ToString
class WeatherData {
    private String time;
    private String city;
    private Double temp;
    private Long humidity;

    // Object[] 로부터 WeatherData 를 생성하는 Static Factory 메서드
    public static WeatherData fromRow(Object[] row) {
        WeatherData data = new WeatherData();
        data.time = String.valueOf(row[0]);
        data.city = String.valueOf(row[1]);
        data.temp = (row[2] instanceof Number) ? ((Number) row[2]).doubleValue() : 0.0;
        data.humidity = (row[3] instanceof Number) ? ((Number) row[3]).longValue() : 0L;
        return data;
    }
}
