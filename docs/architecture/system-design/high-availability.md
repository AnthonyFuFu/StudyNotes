# 高可用設計

!!! abstract "本章重點"

    高可用的目標是「部分故障時整體仍能服務」。本章整理限流的四種演算法、熔斷器的三種狀態，以及降級的策略，搭配 Guava、Redis + Lua 與 Resilience4j 的實作。

## 限流（Rate Limiting）

**目的**：保護系統不被突發流量打垮

### 算法一：固定窗口算法

以 1 分鐘為一個窗口，每個窗口最多允許 100 次請求，進入新窗口時計數歸零。

| 時間窗口 | 允許請求數 |
|---------|-----------|
| 0 \~ 60 秒 | 最多 100 次 |
| 60 \~ 120 秒 | 最多 100 次 |

!!! warning "臨界點問題"

    第 59 秒來 100 次、第 61 秒再來 100 次：兩次都在各自窗口的限額內，但 **2 秒內實際通過了 200 次**，是設定值的兩倍。滑動窗口就是為了解決這個問題。

### 算法二：滑動窗口算法

**當前時間往前推 1 分鐘的窗口是動態的**

現在是 90s，窗口是 [30s \~ 90s]

現在是 91s，窗口是 [31s \~ 91s]  ← 窗口滑動

### 算法三：令牌桶（Token Bucket）（推薦）

``` mermaid
flowchart LR
    GEN(["以固定速率生成令牌"]) --> B[("令牌桶<br>🪙 🪙 🪙 🪙 🪙<br>容量：100 個令牌")]
    REQ["請求"] --> B
    B -->|"每次請求消耗 1 個令牌"| OK["放行"]
```

**優點**：允許突發流量（桶中存有令牌時可以立即消費）。

### 算法四：漏桶（Leaky Bucket）

``` mermaid
flowchart LR
    IN["請求進來<br>（含突發流量）"] --> B[("漏桶")]
    B -->|"固定速率輸出"| OUT["處理請求"]
    B -.->|"桶滿"| DROP["拒絕"]
```

- **優點**：輸出速率穩定
- **缺點**：無法應對突發流量

### Java 實作（Guava RateLimiter）

```java
import com.google.common.util.concurrent.RateLimiter;

@RestController
public class OrderController {

    private final RateLimiter rateLimiter = RateLimiter.create(10.0);

    @PostMapping("/order")
    public ResponseEntity<?> createOrder() {
        if (!rateLimiter.tryAcquire()) {
            return ResponseEntity.status(429)
                .body("Too Many Requests，請稍後再試");
        }
        return ResponseEntity.ok("訂單創建成功");
    }
}
```

### Redis + Lua 分散式限流

```java
public boolean isAllowed(String userId, int maxRequest, int windowSeconds) {
    String key = "rate_limit:" + userId;
    long now = System.currentTimeMillis();
    long windowStart = now - windowSeconds * 1000L;

    String luaScript =
        "redis.call('ZREMRANGEBYSCORE', KEYS[1], '-inf', ARGV[1]) " +
        "local count = redis.call('ZCARD', KEYS[1]) " +
        "if count < tonumber(ARGV[2]) then " +
        "   redis.call('ZADD', KEYS[1], ARGV[3], ARGV[3]) " +
        "   redis.call('EXPIRE', KEYS[1], ARGV[4]) " +
        "   return 1 " +
        "else " +
        "   return 0 " +
        "end";

    Long result = redisTemplate.execute(
        new DefaultRedisScript<>(luaScript, Long.class),
        Collections.singletonList(key),
        String.valueOf(windowStart),
        String.valueOf(maxRequest),
        String.valueOf(now),
        String.valueOf(windowSeconds)
    );

    return Long.valueOf(1).equals(result);
}
```

## 熔斷（Circuit Breaker）

**比喻**：像家裡的電路保險絲，電流過大時自動斷路，防止整個電路燒毀。

``` mermaid
stateDiagram-v2
    direction LR
    Closed: 閉合（正常）
    Open: 斷開（熔斷）
    HalfOpen: 半開（探測）
    [*] --> Closed
    Closed --> Open: 失敗率 > 閾值
    Open --> HalfOpen: 等待超時
    HalfOpen --> Closed: 測試請求成功
    HalfOpen --> Open: 測試請求失敗
```

| 狀態 | 說明 |
|------|------|
| **Closed（閉合）** | 正常狀態，請求正常通過，統計失敗率 |
| **Open（斷開）** | 熔斷狀態，直接返回錯誤，不請求下游 |
| **Half-Open（半開）** | 允許少量請求測試，成功則恢復 Closed |

### Resilience4j 實作

```yaml
# application.yml
resilience4j:
  circuitbreaker:
    instances:
      inventoryService:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 10s
        permittedNumberOfCallsInHalfOpenState: 3
```

```java
@Service
public class OrderService {

    @CircuitBreaker(name = "inventoryService", fallbackMethod = "fallbackDeductStock")
    public String deductStock(Long productId, Integer quantity) {
        return inventoryClient.deduct(productId, quantity);
    }

    public String fallbackDeductStock(Long productId, Integer quantity, Exception e) {
        log.error("庫存服務熔斷，productId={}", productId);
        return "庫存服務暫時不可用，訂單已排隊處理";
    }
}
```

## 降級（Fallback）策略

| 降級策略 | 使用場景 |
|---------|---------|
| 返回預設值 | 推薦服務掛了，搜尋結果改顯示熱門商品 |
| 讀取快取 | 商品詳情直接從 Redis 讀取，不查資料庫 |
| 非同步處理 | 下單失敗先放入 MQ，稍後重試 |
| 返回靜態頁面 | 活動頁掛了，改回傳預先產生的靜態版本 |
| 直接返回錯誤 | 非核心功能直接告知暫時不可用 |

!!! example "我的實作：holidayDessert 的四層流控"

    搶票入口用 `Semaphore(200)` 做**並發數限流**並快速失敗，後面再以本地計數器、Redis Lua、Kafka 削峰，是限流與降級的組合實作；微服務間的熔斷則在 microservicecloud 用 Resilience4j 實作。

    👉 [實戰：高併發搶票系統](../../backend/spring-boot/practice-seckill.md)
