# 可觀測性三大支柱

## 什麼是可觀測性？

| | 監控（Monitoring） | 可觀測性（Observability） |
|---|---|---|
| 面對的問題 | 已知的問題 | 未知的問題 |
| 做法 | 設置閾值 → 超過告警 | 通過數據推斷 → 找到根因 |
| 心態 | 「我知道可能出什麼問題，所以我盯著那些指標」 | 「系統出了什麼問題，我可以從數據中找到答案」 |

**可觀測性三大支柱**

<div class="grid cards" markdown>

-   __Metrics（指標）__

    ---

    系統健康的數字化呈現

    CPU、記憶體、QPS、延遲

    **工具**：Prometheus + Grafana

-   __Logs（日誌）__

    ---

    發生了什麼的詳細記錄

    錯誤訊息、業務日誌

    **工具**：ELK Stack

-   __Traces（鏈路追蹤）__

    ---

    請求經過了哪些服務

    A → B → C → D，每段耗時

    **工具**：SkyWalking / Zipkin

</div>

**三個支柱相輔相成**

``` mermaid
flowchart LR
    M["Metrics<br>訂單服務 P99 延遲突然升到 5 秒！"] --> T["Traces<br>瓶頸在 MySQL 查詢這一步，耗時 4.8 秒"]
    T --> L["Logs<br>MySQL 慢查詢：SELECT * FROM orders WHERE …（缺少索引）"]
```

## 黃金指標（The Four Golden Signals）

**Google SRE 提出的四個最重要的監控指標**

- ① 延遲（Latency）
    - 請求需要多長時間？
    - 關注 P99（99th percentile），而不只是平均值！

**平均值的陷阱**

- [1ms, 1ms, 1ms, 1ms, 1ms, 1ms, 1ms, 1ms, 1ms, 10000ms]
- 平均 = 1001ms
- P50 = 1ms    → 50% 用戶體驗很好
- P99 = 10000ms → 1% 用戶體驗極差！

- ② 流量（Traffic）
    - 系統有多忙？
    - QPS（每秒請求數）、TPS（每秒事務數）

- ③ 錯誤率（Errors）
    - 請求失敗的比例？
    - HTTP 5xx 錯誤率、業務錯誤率

- ④ 飽和度（Saturation）
    - 系統資源使用了多少？
    - CPU 使用率、記憶體使用率、連線池使用率
