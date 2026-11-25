# 高可用設計

## 限流（Rate Limiting）

**目的**：保護系統不被突發流量打垮

### 算法一：固定窗口算法

```
時間窗口 1分鐘，允許 100 次請求

[0s ─────────────────── 60s] → 最多 100 次
[60s ────────────────── 120s] → 最多 100 次

❌ 問題：臨界點突破
59s 來 100 次 + 61s 來 100 次 = 2 秒內 200 次！
```

### 算法二：滑動窗口算法

```
當前時間往前推 1 分鐘的窗口是動態的：
現在是 90s，窗口是 [30s ~ 90s]
現在是 91s，窗口是 [31s ~ 91s]  ← 窗口滑動
```

### 算法三：令牌桶（Token Bucket）✅ 推薦

```
令牌桶
┌─────────────────────────┐
│  🪙 🪙 🪙 🪙 🪙          │  ← 以固定速率生成令牌
│  容量：100 個令牌        │
└─────────────────────────┘
        ↓ 每次請求消耗 1 個令牌

優點：允許突發流量（桶中存有令牌時可以立即消費）
```

### 算法四：漏桶（Leaky Bucket）

```
請求進來 →  ┌─────┐
           │桶    │ → 以固定速率處理請求
突發流量    │     │
           └──┬──┘
              │ 固定速率輸出

優點：輸出速率穩定
缺點：無法應對突發流量
```

### Java 實作（Guava RateLimiter）：

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

### Redis + Lua 分散式限流：

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

```
狀態機：

        失敗率 > 閾值
  閉合 ──────────────→ 斷開
（正常）                （熔斷）
  ↑                      │
  │     半開 ←───────────┘
  │    （探測）  等待超時
  │       │
  └───────┘
   測試請求成功
```

| 狀態 | 說明 |
|------|------|
| **Closed（閉合）** | 正常狀態，請求正常通過，統計失敗率 |
| **Open（斷開）** | 熔斷狀態，直接返回錯誤，不請求下游 |
| **Half-Open（半開）** | 允許少量請求測試，成功則恢復 Closed |

### Resilience4j 實作：

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

```
降級策略                    使用場景
─────────────────────────────────────────
返回預設值         →  搜索結果顯示熱門商品
讀取緩存           →  商品詳情從 Redis 讀取
異步處理           →  下單失敗放入 MQ 重試
返回靜態頁面       →  活動頁掛了返回靜態版本
直接返回錯誤       →  非核心功能直接告知不可用
```
