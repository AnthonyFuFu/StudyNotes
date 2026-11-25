# Grafana 深入

## 儀表板設計原則

好的儀表板：**從上到下，從概覽到詳情**。

| 列 | 內容 | 面板範例 |
|----|------|---------|
| **第一行** | 系統健康狀態（紅燈 / 綠燈），一眼看出是否正常 | 服務 A ✅ ・ 服務 B ✅ ・ MySQL ✅ ・ Redis ⚠️ ・ 告警數 2 |
| **第二行** | 核心指標趨勢（時間序列圖） | QPS 趨勢 ・ 錯誤率趨勢 ・ P99 延遲趨勢 ・ 活躍連線數 |
| **第三行** | 資源使用 | CPU ・ 記憶體 ・ JVM |
| **第四行** | 業務指標 | 訂單數 ・ 用戶數 ・ 收入 |

## 關鍵面板 PromQL 配置

```json
// 1. QPS 面板（時間序列圖）
{
  "title": "每秒請求數 (QPS)",
  "type": "timeseries",
  "targets": [
    {
      "expr": "sum by (app) (rate(http_server_requests_seconds_count{namespace='$namespace'}[$__rate_interval]))",
      "legendFormat": "{{app}}"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "reqps",
      "thresholds": {
        "steps": [
          {"color": "green",  "value": 0},
          {"color": "yellow", "value": 1000},
          {"color": "red",    "value": 5000}
        ]
      }
    }
  }
}

// 2. P99 延遲面板
{
  "title": "P99 請求延遲",
  "type": "timeseries",
  "targets": [
    {
      "expr": "histogram_quantile(0.99, sum by (app, le) (rate(http_server_requests_seconds_bucket{namespace='$namespace'}[$__rate_interval])))",
      "legendFormat": "P99 - {{app}}"
    },
    {
      "expr": "histogram_quantile(0.95, sum by (app, le) (rate(http_server_requests_seconds_bucket{namespace='$namespace'}[$__rate_interval])))",
      "legendFormat": "P95 - {{app}}"
    },
    {
      "expr": "histogram_quantile(0.50, sum by (app, le) (rate(http_server_requests_seconds_bucket{namespace='$namespace'}[$__rate_interval])))",
      "legendFormat": "P50 - {{app}}"
    }
  ],
  "fieldConfig": {
    "defaults": { "unit": "s" }
  }
}

// 3. JVM 記憶體面板（Gauge）
{
  "title": "JVM 堆記憶體使用率",
  "type": "gauge",
  "targets": [
    {
      "expr": "(jvm_memory_used_bytes{area='heap', app='$app'} / jvm_memory_max_bytes{area='heap', app='$app'}) * 100"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "min": 0,
      "max": 100,
      "thresholds": {
        "steps": [
          {"color": "green",  "value": 0},
          {"color": "yellow", "value": 70},
          {"color": "red",    "value": 85}
        ]
      }
    }
  }
}

// 4. 錯誤率面板（Stat 大數字）
{
  "title": "5xx 錯誤率",
  "type": "stat",
  "targets": [
    {
      "expr": "(sum(rate(http_server_requests_seconds_count{status=~'5..', namespace='$namespace'}[5m])) / sum(rate(http_server_requests_seconds_count{namespace='$namespace'}[5m]))) * 100"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "unit": "percent",
      "thresholds": {
        "steps": [
          {"color": "green",  "value": 0},
          {"color": "yellow", "value": 1},
          {"color": "red",    "value": 5}
        ]
      }
    }
  }
}
```

## Grafana 變數（Variables）

```
使用變數讓儀表板可以動態切換環境/服務：

① namespace 變數（從 Prometheus 標籤取得）
   Type:  Query
   Query: label_values(up, namespace)
   → 自動列出所有 namespace，可以在頂部下拉選擇

② app 變數（依賴 namespace 變數）
   Type:  Query
   Query: label_values(up{namespace="$namespace"}, app)
   → 選擇 namespace 後，自動更新 app 列表

③ interval 變數（時間間隔）
   Type:   Interval
   Values: 1m, 5m, 15m, 30m, 1h
   → 讓使用者選擇聚合粒度

在 PromQL 中使用：
  rate(http_requests_total{namespace="$namespace", app="$app"}[$interval])
```
