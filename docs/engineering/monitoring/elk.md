# ELK Stack 深入

## ELK 架構

``` mermaid
flowchart TB
    subgraph APP ["應用層"]
        SB["Spring Boot App<br>輸出結構化日誌（JSON）"]
    end
    subgraph COLLECT ["收集層"]
        direction LR
        FB["Filebeat（輕量）<br>讀取日誌文件並發送"]
        LS["Logstash（重量級）<br>過濾、轉換、豐富日誌"]
        FB --> LS
    end
    subgraph STORE ["儲存層"]
        ES[("Elasticsearch<br>分散式全文搜索引擎<br>儲存和索引日誌")]
    end
    subgraph VIEW ["展示層"]
        KB["Kibana<br>日誌搜索、視覺化、儀表板"]
    end
    SB -- "日誌文件 / Console" --> FB
    LS --> ES
    FB -. "簡單場景可直送" .-> ES
    ES --> KB
```

## Spring Boot 結構化日誌

```xml
<!-- pom.xml -->
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.4</version>
</dependency>
```

```xml
<!-- logback-spring.xml -->
<configuration>
    <!-- 開發環境：人類可讀格式 -->
    <springProfile name="dev">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="DEBUG">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>

    <!-- 生產環境：JSON 格式（讓 ELK 解析）-->
    <springProfile name="production,staging">
        <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <customFields>
                    {"service":"${spring.application.name}",
                     "env":"${spring.profiles.active}"}
                </customFields>
                <includeMdcKeyName>traceId</includeMdcKeyName>
                <includeMdcKeyName>spanId</includeMdcKeyName>
                <includeMdcKeyName>userId</includeMdcKeyName>
                <fieldNames>
                    <timestamp>@timestamp</timestamp>
                    <levelValue>[ignore]</levelValue>
                </fieldNames>
            </encoder>
        </appender>

        <!-- 非同步輸出（不阻塞業務線程）-->
        <appender name="ASYNC_JSON" class="ch.qos.logback.classic.AsyncAppender">
            <appender-ref ref="JSON_CONSOLE"/>
            <queueSize>1024</queueSize>
            <discardingThreshold>0</discardingThreshold>
            <includeCallerData>false</includeCallerData>
        </appender>

        <root level="INFO">
            <appender-ref ref="ASYNC_JSON"/>
        </root>

        <logger name="com.example" level="DEBUG"/>
        <logger name="org.springframework.web" level="WARN"/>
    </springProfile>
</configuration>
```

```java
// MDC（Mapped Diagnostic Context）- 為日誌加上請求上下文
@Component
@Order(1)
public class LoggingFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest  request,
                                    HttpServletResponse response,
                                    FilterChain         chain)
            throws ServletException, IOException {
        try {
            String traceId = Optional
                .ofNullable(request.getHeader("X-Trace-Id"))
                .orElse(UUID.randomUUID().toString().replace("-", ""));

            String requestId = UUID.randomUUID().toString()
                .replace("-", "").substring(0, 8);

            MDC.put("traceId",   traceId);
            MDC.put("requestId", requestId);
            MDC.put("method",    request.getMethod());
            MDC.put("path",      request.getRequestURI());
            MDC.put("clientIp",  getClientIp(request));

            response.setHeader("X-Trace-Id", traceId);

            chain.doFilter(request, response);

        } finally {
            MDC.clear();  // ⚠️ 必須清除！防止線程池中的線程污染
        }
    }

    private String getClientIp(HttpServletRequest request) {
        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty()) {
            ip = request.getRemoteAddr();
        }
        return ip.split(",")[0].trim();
    }
}

// 日誌記錄最佳實踐
@Service
@Slf4j
public class OrderService {

    public Order createOrder(OrderRequest request) {
        // ✅ 結構化日誌（Key-Value 形式，ELK 容易解析）
        log.info("開始建立訂單, userId={}, productId={}, quantity={}",
            request.getUserId(), request.getProductId(), request.getQuantity());

        MDC.put("orderId", orderId.toString());
        MDC.put("userId",  request.getUserId().toString());

        try {
            Order order = processOrder(request);

            log.info("訂單建立成功, orderId={}, amount={}, status={}",
                order.getId(), order.getAmount(), order.getStatus());

            return order;

        } catch (InsufficientStockException e) {
            // ✅ 業務異常用 warn（不是 error）
            log.warn("庫存不足, orderId={}, productId={}, required={}, available={}",
                orderId, request.getProductId(),
                request.getQuantity(), e.getAvailableStock());
            throw e;

        } catch (Exception e) {
            // ✅ 系統異常用 error，並包含堆棧
            log.error("訂單建立失敗, orderId={}, errorType={}",
                orderId, e.getClass().getSimpleName(), e);
            throw new OrderCreationException("訂單建立失敗", e);

        } finally {
            MDC.remove("orderId");
            MDC.remove("userId");
        }
    }
}
```

## Filebeat 配置

```yaml
# filebeat.yml
filebeat.inputs:
  - type: container
    paths:
      - /var/log/containers/*myapp*.log
    processors:
      - decode_json_fields:
          fields: ["message"]
          target: ""
          overwrite_keys: true

  - type: log
    paths:
      - /app/logs/*.log
    json.keys_under_root: true
    json.add_error_key: true
    # 多行日誌合併（Java 堆棧追蹤）
    multiline.pattern: '^\d{4}-\d{2}-\d{2}'
    multiline.negate: true
    multiline.match: after

processors:
  - add_host_metadata: ~
  - add_kubernetes_metadata:
      host: ${NODE_NAME}
      matchers:
        - logs_path:
            logs_path: "/var/log/containers/"

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  username: "elastic"
  password: "${ELASTICSEARCH_PASSWORD}"
  index: "myapp-logs-%{+yyyy.MM.dd}"

  bulk_max_size: 1000
  worker: 4

queue.mem:
  events: 4096
  flush.min_events: 512
  flush.timeout: 5s
```

## Logstash Pipeline（複雜處理）

```ruby
# logstash/pipeline/main.conf

input {
  beats {
    port => 5044
  }
}

filter {
  json {
    source => "message"
    target => "parsed"
  }

  mutate {
    rename => {
      "[parsed][traceId]" => "trace_id"
      "[parsed][level]"   => "log_level"
      "[parsed][service]" => "service"
      "[parsed][message]" => "log_message"
    }
    remove_field => ["parsed", "message", "agent", "ecs"]
    uppercase    => ["log_level"]
  }

  date {
    match  => ["[parsed][@timestamp]", "ISO8601"]
    target => "@timestamp"
  }

  # 識別慢請求（超過 1000ms）
  if [duration_ms] and [duration_ms] > 1000 {
    mutate {
      add_tag   => ["slow_request"]
      add_field => { "slow_request" => true }
    }
  }

  # IP 地址轉地理位置
  if [client_ip] {
    geoip {
      source => "client_ip"
      target => "geoip"
    }
  }
}

output {
  elasticsearch {
    hosts    => ["elasticsearch:9200"]
    user     => "elastic"
    password => "${ES_PASSWORD}"
    index    => "%{service}-logs-%{+YYYY.MM.dd}"
    ilm_enabled           => true
    ilm_rollover_alias    => "%{service}-logs"
  }

  # 錯誤日誌額外發到 Slack
  if [log_level] == "ERROR" {
    http {
      url         => "https://hooks.slack.com/services/xxx"
      http_method => "post"
      format      => "json"
      mapping     => {
        "text" => "🚨 ERROR in %{service}: %{log_message} | traceId: %{trace_id}"
      }
    }
  }
}
```

## Kibana 使用技巧

```
KQL（Kibana Query Language）常用查詢：

# 查找特定服務的錯誤日誌
service: "order-service" AND log_level: "ERROR"

# 查找特定 traceId 的所有日誌（排查問題！）
trace_id: "abc123def456"

# 查找慢請求
duration_ms > 1000 AND service: "order-service"

# 查找包含特定錯誤訊息
log_message: "OutOfMemoryError" OR log_message: "connection refused"

# 查找特定時間段
@timestamp >= "2024-01-01T00:00:00" AND @timestamp <= "2024-01-01T01:00:00"

# 正則查詢
log_message: /.*timeout.*/

重要功能：
① Discover：實時搜索日誌
② Dashboard：視覺化日誌分析
③ Alerts：基於日誌的告警（如錯誤日誌突增）
④ Index Lifecycle Management（ILM）：
   Hot（7天）→ Warm（30天）→ Cold（90天）→ Delete
   自動管理索引，節省儲存空間
```
