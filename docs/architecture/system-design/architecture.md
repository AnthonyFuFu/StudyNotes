# 架構設計

!!! abstract "本章重點"

    系統規模變大之後，流量分配、服務拆分與非同步溝通成為架構的核心問題。本章介紹負載均衡的演算法與層級、微服務拆分原則，以及訊息佇列適合的使用場景。

## 負載均衡

| 算法 | 說明 | 適用場景 |
|------|------|---------|
| **輪詢（Round Robin）** | 依序分配 | 服務性能相近 |
| **加權輪詢** | 按性能分配比例 | 服務性能不均 |
| **最少連接** | 分給連接數最少的 | 請求處理時間不均 |
| **IP Hash** | 根據 IP 固定分配 | 需要 Session 黏滯 |
| **隨機** | 隨機選擇 | 簡單場景 |

## 微服務設計原則

| 原則 | 說明 |
|------|------|
| **單一職責** | 每個服務只做一件事 |
| **服務自治** | 每個服務有自己的資料庫 |
| **接口穩定** | API 版本向後兼容 |
| **失敗設計** | 設計時假設依賴服務會失敗 |
| **冪等設計** | 重複請求不產生副作用 |

### 冪等性實作

```java
@PostMapping("/order")
public ResponseEntity<?> createOrder(@RequestBody OrderRequest request) {
    String idempotencyKey = "order:idem:" + request.getRequestId();

    Boolean isFirst = redisTemplate.opsForValue()
        .setIfAbsent(idempotencyKey, "processing", 24, TimeUnit.HOURS);

    if (!Boolean.TRUE.equals(isFirst)) {
        return ResponseEntity.ok(getOrderResult(request.getRequestId()));
    }

    Order order = orderService.create(request);
    redisTemplate.opsForValue().set(idempotencyKey, order.getId().toString());
    return ResponseEntity.ok(order);
}
```

## 消息隊列使用場景

- 1\. 非同步解耦：
    - 訂單服務 → [MQ] → 通知服務（不需要同步等待）

- 2\. 流量削峰：
    - 秒殺：10萬請求 → [MQ緩衝] → 服務慢慢消費

- 3\. 最終一致性：
    - 本地消息表 → [MQ] → 其他服務（分散式事務）

- 4\. 事件驅動：
    - 用戶下單事件 → [MQ] → 積分服務/推薦服務/物流服務
