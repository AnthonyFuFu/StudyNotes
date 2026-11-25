# 實戰：完整可觀測性平台

!!! abstract "本章重點"

    本章把 Metrics、Logs、Traces 三者整合成一套完整的可觀測性平台，示範以 Docker Compose 部署整個監控棧，並說明生產環境的告警分級與 SLI / SLO 的設計方式。

## 整合架構設計

``` mermaid
flowchart TB
    APP["Spring Boot Apps<br>Micrometer + Logback JSON + OTel Agent"]
    APP -- Metrics --> PROM["Prometheus<br>拉取指標"]
    APP -- Logs --> FB["Filebeat<br>收集日誌"]
    APP -- Traces --> OAP["SkyWalking OAP /<br>OpenTelemetry"]
    PROM --> GF["Grafana<br>指標儀表板・告警"]
    FB --> ES["Elasticsearch + Kibana<br>日誌搜索"]
    OAP --> SWUI["SkyWalking UI<br>鏈路視覺化"]
    GF --> AM["AlertManager<br>統一告警通知"]
    AM --> SL["Slack"]
    AM --> PD["PagerDuty"]
    AM --> EM["Email"]
```

## Docker Compose 部署完整監控棧

```yaml
# docker-compose-monitoring.yml
version: '3.8'

services:

  # ══════════ Prometheus ══════════
  prometheus:
    image: prom/prometheus:v2.48.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./monitoring/prometheus/rules:/etc/prometheus/rules:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.enable-lifecycle'
    networks:
      - monitoring

  # ══════════ AlertManager ══════════
  alertmanager:
    image: prom/alertmanager:v0.26.0
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    networks:
      - monitoring

  # ══════════ Grafana ══════════
  grafana:
    image: grafana/grafana:10.2.0
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER:     admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP:     "false"
      GF_SMTP_ENABLED:            "true"
      GF_SMTP_HOST:               smtp.example.com:587
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources:ro
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
    networks:
      - monitoring

  # ══════════ Node Exporter（主機指標）══════════
  node-exporter:
    image: prom/node-exporter:v1.7.0
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring

  # ══════════ Elasticsearch ══════════
  elasticsearch:
    image: elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - monitoring

  # ══════════ Kibana ══════════
  kibana:
    image: kibana:8.11.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_HOSTS: http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - monitoring

  # ══════════ Filebeat ══════════
  filebeat:
    image: elastic/filebeat:8.11.0
    container_name: filebeat
    user: root
    volumes:
      - ./monitoring/filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - filebeat_data:/usr/share/filebeat/data
    networks:
      - monitoring

  # ══════════ SkyWalking OAP ══════════
  skywalking-oap:
    image: apache/skywalking-oap-server:9.7.0
    container_name: skywalking-oap
    ports:
      - "11800:11800"   # gRPC（Agent 上報）
      - "12800:12800"   # HTTP（UI 查詢）
    environment:
      SW_STORAGE: elasticsearch
      SW_STORAGE_ES_CLUSTER_NODES: elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - monitoring

  # ══════════ SkyWalking UI ══════════
  skywalking-ui:
    image: apache/skywalking-ui:9.7.0
    container_name: skywalking-ui
    ports:
      - "8080:8080"
    environment:
      SW_OAP_ADDRESS: http://skywalking-oap:12800
    networks:
      - monitoring

volumes:
  prometheus_data:
  alertmanager_data:
  grafana_data:
  elasticsearch_data:
  filebeat_data:

networks:
  monitoring:
    driver: bridge
```

## 生產告警體系設計

**告警分級**

**P0 - 緊急（立即響應，5 分鐘內）**

- ✅ 服務完全宕機
- ✅ 所有請求 5xx（錯誤率 100%）
- ✅ 資料庫連線失敗
- ✅ 核心業務功能不可用
- → 通知：PagerDuty 電話 + Slack @channel

**P1 - 嚴重（30 分鐘內響應）**

- ✅ 錯誤率 > 10%
- ✅ P99 延遲 > 5s
- ✅ JVM OOM（記憶體 > 95%）
- ✅ 磁碟空間 > 90%
- → 通知：Slack @here + Email

**P2 - 警告（工作時間內處理）**

- ✅ 錯誤率 > 1%
- ✅ P99 延遲 > 2s
- ✅ CPU > 80%（持續 15 分鐘）
- ✅ 連線池使用率 > 80%
- → 通知：Slack 通知

**P3 - 提示（下個迭代處理）**

- ✅ 輕微效能退化
- ✅ 日誌中出現大量 WARN
- → 通知：週報匯總

**告警黃金法則**

- ① 告警必須是可操作的（Actionable）
- ② 避免告警疲勞（Alert Fatigue）
    - 太多無效告警 → 工程師麻木 → 漏掉真正的問題
- ③ 告警要有 Runbook
    - 每個告警對應一份操作手冊：
    - "收到這個告警，做以下步驟 1、2、3..."

```yaml
# 完整的生產告警規則
groups:
  - name: p0_critical
    rules:
      - alert: AllInstancesDown
        expr: |
          sum by (app) (up{job="spring-boot-apps"}) == 0
        for: 1m
        labels:
          severity: p0
          pagerduty: "true"
        annotations:
          summary: "🚨 P0：{{ $labels.app }} 所有實例宕機！"
          description: "{{ $labels.app }} 在 {{ $labels.namespace }} 完全不可用"
          runbook: "https://wiki.example.com/runbook/p0-service-down"

  - name: p1_serious
    rules:
      - alert: HighErrorRateP1
        expr: |
          (
            sum by (app) (rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
            /
            sum by (app) (rate(http_server_requests_seconds_count[5m]))
          ) * 100 > 10
        for: 3m
        labels:
          severity: p1
        annotations:
          summary: "🔴 P1：{{ $labels.app }} 錯誤率 {{ $value | printf \"%.1f\" }}%"
          description: |
            服務 {{ $labels.app }} 的 5xx 錯誤率超過 10%，持續 3 分鐘。
            排查步驟：
            1. 查看 Kibana 最近的 ERROR 日誌
            2. 查看 SkyWalking 的失敗追蹤
            3. 檢查依賴服務（DB、Redis）是否正常
          runbook: "https://wiki.example.com/runbook/high-error-rate"

  - name: p2_warning
    rules:
      - alert: SlowResponseP2
        expr: |
          histogram_quantile(0.99,
            sum by (app, le) (
              rate(http_server_requests_seconds_bucket[5m])
            )
          ) > 2
        for: 5m
        labels:
          severity: p2
        annotations:
          summary: "⚠️ P2：{{ $labels.app }} P99 延遲 {{ $value | humanizeDuration }}"

      - alert: HikariConnectionPoolWarning
        expr: |
          (hikaricp_connections_active / hikaricp_connections_max) * 100 > 80
        for: 3m
        labels:
          severity: p2
        annotations:
          summary: "⚠️ P2：{{ $labels.app }} 資料庫連線池使用率 {{ $value | printf \"%.0f\" }}%"
```

## SLI / SLO 設計

**SLI（Service Level Indicator）服務水平指標**

- 可用性：成功請求數 / 總請求數
- 延遲：P99 &lt; 500ms 的請求比例
- 錯誤率：5xx 錯誤比例

**SLO（Service Level Objective）服務水平目標**

- 可用性 SLO：99.9%（每月最多 43 分鐘停機）
- 延遲 SLO：  95% 的請求 P99 &lt; 500ms
- 錯誤率 SLO：5xx 錯誤率 &lt; 0.1%

**Error Budget（錯誤預算）**

- SLO = 99.9% → Error Budget = 0.1%（每月 43 分鐘）
- Error Budget 消耗完 → 停止新功能發布，專注穩定性

```java
// 追蹤 SLO 違規
@Component
public class SloMetrics {

    private final MeterRegistry registry;

    public void trackSloViolation(String sloName, boolean violated) {
        Counter.builder("slo.violations.total")
            .tag("slo_name", sloName)
            .tag("violated", String.valueOf(violated))
            .register(registry)
            .increment();
    }
}
```
