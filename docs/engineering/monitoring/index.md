---
icon: lucide/activity
---

# 監控與可觀測性

Metrics、Logs、Traces 三大支柱，以及 Prometheus、Grafana、ELK、鏈路追蹤如何組成完整的可觀測性平台。

**核心技術**：Prometheus / Grafana / ELK / SkyWalking / SLO

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["監控與可觀測性"])
    c0["01 · 可觀測性三大支柱"]
    R --> c0
    p0("・Metrics（指標）<br>・Logs（日誌）<br>・Traces（鏈路追蹤）")
    c0 --- p0
    c1["02 · Prometheus 深入"]
    R --> c1
    p1("・架構原理<br>・資料模型與 PromQL<br>・Spring Boot 整合<br>・告警規則（AlertManager）")
    c1 --- p1
    c2["03 · Grafana 深入"]
    R --> c2
    p2("・儀表板設計原則<br>・關鍵面板配置<br>・變數（Variables）")
    c2 --- p2
    c3["04 · ELK Stack 深入"]
    R --> c3
    p3("・ELK 架構<br>・Spring Boot 結構化日誌<br>・Filebeat 配置<br>・Logstash Pipeline<br>・Kibana 使用技巧")
    c3 --- p3
    c4["05 · 分散式鏈路追蹤"]
    R --> c4
    p4("・SkyWalking 架構<br>・Spring Boot 整合<br>・鏈路分析實戰")
    c4 --- p4
    c5["06 · 實戰：完整可觀測性平台"]
    R --> c5
    p5("・整合架構設計<br>・Docker Compose 部署<br>・生產告警體系")
    c5 --- p5
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5 chapter
    class p0,p1,p2,p3,p4,p5 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 可觀測性三大支柱](three-pillars.md)__

    ---

    什麼是可觀測性？ · 黃金指標

-   __[02 · Prometheus 深入](prometheus.md)__

    ---

    架構原理 · 資料模型與指標類型 · PromQL 查詢語言 · Spring Boot 整合 Prometheus · AlertManager 告警規則

-   __[03 · Grafana 深入](grafana.md)__

    ---

    儀表板設計原則 · 關鍵面板 PromQL 配置 · Grafana 變數

-   __[04 · ELK Stack 深入](elk.md)__

    ---

    ELK 架構 · Spring Boot 結構化日誌 · Filebeat 配置 · Logstash Pipeline · Kibana 使用技巧

-   __[05 · 分散式鏈路追蹤](tracing.md)__

    ---

    SkyWalking 架構 · Spring Boot 整合 · 鏈路追蹤實戰分析

-   __[06 · 實戰：可觀測性平台](platform.md)__

    ---

    整合架構設計 · Docker Compose 部署完整監控棧 · 生產告警體系設計 · SLI / SLO 設計

</div>

## 重點速覽

### 可觀測性三大支柱

<div class="grid cards" markdown>

-   __Metrics（指標）__

    ---

    Prometheus + Grafana

    告訴你「P99 延遲突然升到 5 秒！」

-   __Traces（鏈路追蹤）__

    ---

    SkyWalking / Zipkin

    告訴你「瓶頸在 MySQL 查詢，耗時 4.8 秒」

-   __Logs（日誌）__

    ---

    ELK Stack

    告訴你「慢查詢 SQL：缺少索引」

</div>

### 告警分級體系

| 等級 | 條件 | 響應時間 | 通知方式 |
|------|------|---------|---------|
| **P0 緊急** | 服務宕機 / 全量 5xx | 5 分鐘內 | PagerDuty 電話 + Slack @channel |
| **P1 嚴重** | 錯誤率 > 10% / P99 > 5s | 30 分鐘內 | Slack @here + Email |
| **P2 警告** | 錯誤率 > 1% / CPU > 80% | 工作時間內 | Slack 通知 |
| **P3 提示** | 輕微效能退化 | 下個迭代 | 週報匯總 |

### 關鍵 PromQL

```promql
# QPS
sum by (app) (rate(http_server_requests_seconds_count[1m]))

# P99 延遲
histogram_quantile(0.99,
  sum by (app, le) (rate(http_server_requests_seconds_bucket[5m])))

# 5xx 錯誤率（%）
sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
/ sum(rate(http_server_requests_seconds_count[5m])) * 100

# JVM 堆記憶體使用率
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100
```

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **三大支柱** | Metrics（數字）/ Logs（文字）/ Traces（鏈路），三者互補 |
| **黃金指標** | 延遲（P99）/ 流量（QPS）/ 錯誤率 / 飽和度 |
| **Prometheus** | Pull 模式，時序資料庫，PromQL 查詢，四種指標類型 |
| **PromQL** | rate() 計算速率，histogram_quantile() 計算百分位數 |
| **AlertManager** | 告警路由、分組、靜音，多種通知渠道 |
| **Grafana** | 從概覽到詳情，使用變數動態切換，SLO 儀表板 |
| **Logback** | JSON 結構化日誌，MDC 加入 traceId，非同步輸出 |
| **ELK** | Filebeat 收集 → Elasticsearch 存儲 → Kibana 查詢 |
| **SkyWalking** | 自動注入 Agent，追蹤全鏈路，定位瓶頸服務 |
| **告警分級** | P0（立即）/ P1（30分鐘）/ P2（工作時間），避免告警疲勞 |
| **SLI/SLO** | 量化服務品質目標，Error Budget 驅動工程決策 |
