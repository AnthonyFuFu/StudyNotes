# Prometheus 深入

!!! abstract "本章重點"

    Prometheus 以拉取模式收集指標，是雲原生監控的事實標準。本章說明它的架構與四種指標類型、PromQL 查詢、Spring Boot Actuator 的整合，以及 AlertManager 告警規則的撰寫。

## 架構原理

``` mermaid
flowchart TB
    subgraph TARGETS ["被監控的服務"]
        direction LR
        SB["Spring Boot<br>/actuator/prometheus"] ~~~ EX1["MySQL Exporter"] ~~~ EX2["Node Exporter"] ~~~ EX3["Redis Exporter"]
    end
    TARGETS -. "Scrape：Prometheus 主動拉取（HTTP Pull）" .-> SERVER
    subgraph SERVER ["Prometheus Server"]
        direction LR
        RET["Retrieval 拉取引擎<br>每 15 秒拉取"] --> TSDB[("TSDB 時序資料庫<br>壓縮儲存，預設保留 15 天")] --> API["HTTP API"]
    end
    SERVER -- "Query（PromQL）" --> CON["Grafana / AlertManager"]
```

**核心設計：Pull 模式（拉取）**

Prometheus 主動去服務的 `/metrics` 端點拉取指標。

- **優點**：Prometheus 控制拉取頻率，服務不需要知道 Prometheus 的地址
- **缺點**：短生命週期的任務（Job）可能來不及被拉取
- **解決**：PushGateway（Job 主動推送到 Gateway，Prometheus 再拉取）

## 資料模型與指標類型

```
Prometheus 資料模型：時間序列（Time Series）

每條時間序列由：指標名稱 + 標籤集合 唯一確定

http_requests_total{method="GET", path="/api/orders", status="200"} = 1234
──────────────────  ──────────────────────────────────────────────   ────
    指標名稱                        標籤（Labels）                    當前值
```

```java
// ① Counter（計數器）- 只增不減
// 適合：請求總數、錯誤次數
// 命名慣例：_total 結尾
// ⚠️ 服務重啟後會歸零！使用 rate() 計算增長速率
http_requests_total{method="POST"} 1234

// ② Gauge（儀表盤）- 可增可減
// 適合：當前值，如記憶體使用量、在線用戶數、隊列深度
jvm_memory_used_bytes{area="heap"} 536870912
active_connections 42

// ③ Histogram（直方圖）- 觀察值分布 + 百分位數
// 適合：請求延遲、響應大小
// 自動生成三個指標：
http_request_duration_seconds_bucket{le="0.1"}   800   // ≤0.1s 的請求有 800 個
http_request_duration_seconds_bucket{le="0.5"}   950
http_request_duration_seconds_bucket{le="1.0"}   990
http_request_duration_seconds_bucket{le="+Inf"} 1000   // 總共 1000 個請求
http_request_duration_seconds_sum             123.456   // 所有請求的總耗時
http_request_duration_seconds_count              1000   // 請求總數

// ④ Summary（摘要）- 客戶端計算百分位數
// ⚠️ Summary 不支援跨實例聚合！多實例場景用 Histogram
http_request_duration_seconds{quantile="0.5"}  0.05   // P50 = 50ms
http_request_duration_seconds{quantile="0.9"}  0.2    // P90 = 200ms
http_request_duration_seconds{quantile="0.99"} 0.8    // P99 = 800ms
```

## PromQL 查詢語言

```promql
# ─── 標籤匹配器 ───
# =  完全匹配    {method="GET"}
# != 不等於      {status!="200"}
# =~ 正則匹配    {path=~"/api/.*"}
# !~ 正則不匹配  {status!~"2.*"}

# ─── 常用函數 ───
# rate()    計算範圍向量的每秒平均增長率（適合 Counter）
# irate()   計算最後兩個樣本的瞬時速率（對突發更敏感）
# increase() 計算範圍內的增長量
# histogram_quantile() 從 Histogram 計算百分位數

# ─── 常用 PromQL 查詢範例 ───

# 每秒請求數（QPS）
rate(http_requests_total{job="myapp"}[1m])

# 按路徑分組的 QPS
sum by (path) (
    rate(http_requests_total{job="myapp"}[1m])
)

# HTTP 錯誤率（5xx 佔總請求的比例）
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
* 100

# P99 請求延遲（從 Histogram 計算）
histogram_quantile(0.99,
    sum by (le) (
        rate(http_request_duration_seconds_bucket{job="myapp"}[5m])
    )
)

# JVM 堆記憶體使用率（%）
jvm_memory_used_bytes{area="heap"}
/
jvm_memory_max_bytes{area="heap"}
* 100

# CPU 使用率（過去 1 分鐘）
100 - (
    avg by (instance) (
        rate(node_cpu_seconds_total{mode="idle"}[1m])
    ) * 100
)

# 連線池使用率（HikariCP）
hikaricp_connections_active
/
hikaricp_connections_max
* 100

# 過去 1 小時的 GC 暫停時間
increase(jvm_gc_pause_seconds_sum[1h])

# 多實例聚合（3 個實例的總 QPS）
sum(rate(http_requests_total{job="myapp"}[1m]))
```

## Spring Boot 整合 Prometheus

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health, info, prometheus, metrics
      base-path: /actuator
  endpoint:
    health:
      show-details: always
      probes:
        enabled: true        # 開啟 K8s 探針端點
    prometheus:
      enabled: true
  metrics:
    tags:
      application: ${spring.application.name}
      environment: ${spring.profiles.active}
    distribution:
      # 開啟 Histogram（計算百分位數必須開啟）
      percentiles-histogram:
        http.server.requests: true
      percentiles:
        http.server.requests: 0.5, 0.75, 0.95, 0.99
      # SLO 邊界
      slo:
        http.server.requests: 100ms, 200ms, 500ms, 1s
```

=== "自定義業務指標"

    ``` java
    // 自定義業務指標
    @Component
    @RequiredArgsConstructor
    public class OrderMetrics {

        private final MeterRegistry registry;

        private Counter             orderCreatedCounter;
        private Counter             orderFailedCounter;
        private AtomicInteger       pendingOrders = new AtomicInteger(0);
        private Timer               orderProcessingTimer;
        private DistributionSummary orderAmountSummary;

        @PostConstruct
        public void init() {
            // ① Counter
            orderCreatedCounter = Counter.builder("order.created.total")
                .description("已建立的訂單總數")
                .tag("service", "order-service")
                .register(registry);

            orderFailedCounter = Counter.builder("order.failed.total")
                .description("建立失敗的訂單總數")
                .register(registry);

            // ② Gauge（監控動態值）
            Gauge.builder("order.pending.count", pendingOrders, AtomicInteger::get)
                .description("當前待處理訂單數")
                .register(registry);

            // ③ Timer
            orderProcessingTimer = Timer.builder("order.processing.duration")
                .description("訂單處理耗時")
                .publishPercentileHistogram()
                .slo(
                    Duration.ofMillis(100),
                    Duration.ofMillis(500),
                    Duration.ofSeconds(1)
                )
                .register(registry);

            // ④ DistributionSummary
            orderAmountSummary = DistributionSummary.builder("order.amount")
                .description("訂單金額分布（元）")
                .baseUnit("yuan")
                .publishPercentileHistogram()
                .register(registry);
        }

        public void recordOrderCreated(BigDecimal amount) {
            orderCreatedCounter.increment();
            orderAmountSummary.record(amount.doubleValue());
            pendingOrders.incrementAndGet();
        }

        public void recordOrderFailed(String reason) {
            orderFailedCounter.increment(Tags.of("reason", reason));
        }

        public void recordOrderCompleted() {
            pendingOrders.decrementAndGet();
        }

        // 用 Timer 包裝業務邏輯（自動計時）
        public Order createOrderWithMetrics(OrderRequest request) {
            return orderProcessingTimer.record(() -> createOrder(request));
        }
    }
    ```

=== "使用 @Timed 注解"

    ``` java
    // 使用 @Timed 注解（更簡潔）
    @Service
    public class OrderService {

        @Timed(
            value       = "order.create.duration",
            description = "訂單建立耗時",
            percentiles = {0.5, 0.99},
            histogram   = true
        )
        public Order createOrder(OrderRequest request) {
            // 業務邏輯
        }
    }
    ```


```yaml
# prometheus.yml（Prometheus 配置）
global:
  scrape_interval:     15s
  evaluation_interval: 15s

rule_files:
  - "rules/spring_boot_alerts.yml"
  - "rules/jvm_alerts.yml"
  - "rules/business_alerts.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  # ── Spring Boot 應用 ──
  - job_name: 'spring-boot-apps'
    metrics_path: '/actuator/prometheus'
    scrape_interval: 15s

    # Kubernetes 服務發現（自動發現 Pod）
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['production', 'staging']

    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app

  # ── Node Exporter（主機指標）──
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # ── MySQL Exporter ──
  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']

  # ── Redis Exporter ──
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
```

## AlertManager 告警規則

```yaml
# rules/spring_boot_alerts.yml
groups:
  - name: spring_boot_alerts
    interval: 30s

    rules:
      # ── 服務宕機 ──
      - alert: ServiceDown
        expr: up{job="spring-boot-apps"} == 0
        for: 1m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "服務宕機 🚨"
          description: "{{ $labels.app }} 在 {{ $labels.namespace }} 已宕機超過 1 分鐘"
          runbook: "https://wiki.example.com/runbook/service-down"

      # ── 高錯誤率 ──
      - alert: HighErrorRate
        expr: |
          (
            sum by (app) (rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
            /
            sum by (app) (rate(http_server_requests_seconds_count[5m]))
          ) * 100 > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "HTTP 錯誤率過高 ⚠️"
          description: "{{ $labels.app }} 錯誤率為 {{ $value | humanize }}%（閾值 5%）"

      # ── 高延遲 ──
      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            sum by (app, le) (
              rate(http_server_requests_seconds_bucket[5m])
            )
          ) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P99 延遲過高 ⚠️"
          description: "{{ $labels.app }} P99 延遲 {{ $value | humanizeDuration }}（閾值 2s）"

      # ── JVM 堆記憶體告警 ──
      - alert: JvmHeapUsageHigh
        expr: |
          (
            jvm_memory_used_bytes{area="heap"}
            /
            jvm_memory_max_bytes{area="heap"}
          ) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "JVM 堆記憶體使用率過高"
          description: "{{ $labels.app }} 堆記憶體使用 {{ $value | humanize }}%（閾值 85%）"

      # ── 連線池耗盡 ──
      - alert: HikariPoolExhausted
        expr: hikaricp_connections_pending > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "資料庫連線池耗盡 🚨"
          description: "{{ $labels.app }} 有 {{ $value }} 個請求等待資料庫連線"

---
# rules/business_alerts.yml
groups:
  - name: business_alerts
    rules:
      - alert: HighOrderFailureRate
        expr: |
          (
            rate(order_failed_total[5m])
            /
            rate(order_created_total[5m])
          ) * 100 > 10
        for: 3m
        labels:
          severity: critical
          team: business
        annotations:
          summary: "訂單失敗率過高 🚨"
          description: "訂單失敗率 {{ $value | humanize }}%，可能影響業務收入！"
```

```yaml
# alertmanager.yml（告警路由與通知）
global:
  resolve_timeout: 5m
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alert@example.com'

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  receiver: 'slack-ops'
  group_by: ['alertname', 'app', 'namespace']
  group_wait:      30s
  group_interval:  5m
  repeat_interval: 4h

  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
      continue: true

    - match:
        team: business
      receiver: 'slack-business'

    - match:
        severity: warning
      mute_time_intervals:
        - non-business-hours

receivers:
  - name: 'slack-ops'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/xxx'
        channel: '#ops-alerts'
        color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
        send_resolved: true

  - name: 'pagerduty'
    pagerduty_configs:
      - routing_key: 'your-pagerduty-key'

  - name: 'email-ops'
    email_configs:
      - to: 'ops-team@example.com'

time_intervals:
  - name: non-business-hours
    time_intervals:
      - times:
          - start_time: '00:00'
            end_time: '09:00'
          - start_time: '18:00'
            end_time: '24:00'
        weekdays: ['monday:friday']
      - weekdays: ['saturday', 'sunday']
```
