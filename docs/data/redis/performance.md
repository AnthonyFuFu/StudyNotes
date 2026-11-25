# 效能優化

!!! abstract "本章重點"

    Redis 本身很快，瓶頸常常出在網路往返次數。本章介紹 Pipeline 批次執行命令，以及用 Lua Script 把多個命令合併成一個原子操作。

## Pipeline（批量命令）

```java
// 問題：N 個命令 = N 次網路往返（RTT）
// Pipeline：N 個命令一次性發送，一次網路往返

// ❌ 沒有 Pipeline（假設 RTT = 1ms）
for (int i = 0; i < 1000; i++) {
    redisTemplate.opsForValue().set("key:" + i, "value:" + i);
}
// 總耗時 ≈ 1000ms（1000 次網路往返）

// ✅ 使用 Pipeline
redisTemplate.executePipelined(connection -> {
    for (int i = 0; i < 1000; i++) {
        connection.stringCommands().set(
            ("key:" + i).getBytes(),
            ("value:" + i).getBytes()
        );
    }
    return null;
});
// 總耗時 ≈ 數毫秒（1 次網路往返）

// ⚠️ Pipeline 不保證原子性！
// 每個命令都可能成功或失敗
// 需要原子性 → 用 Lua Script 或 Transaction
```

## Lua Script（原子操作）

```java
// Lua Script 在 Redis 中是原子執行的
// 適合：需要多個命令組合成一個原子操作的場景

// 範例：限流（令牌桶）- 原子判斷並計數
String rateLimitScript =
    "local key     = KEYS[1] " +
    "local limit   = tonumber(ARGV[1]) " +
    "local expire  = tonumber(ARGV[2]) " +
    "local current = tonumber(redis.call('get', key) or '0') " +
    "if current >= limit then " +
    "    return 0 " +  // 超過限制
    "else " +
    "    redis.call('incr', key) " +
    "    if current == 0 then " +
    "        redis.call('expire', key, expire) " +
    "    end " +
    "    return 1 " +  // 允許通過
    "end";

public boolean isAllowed(String userId, int limit, int windowSeconds) {
    String key = "rate:limit:" + userId;
    Long result = redisTemplate.execute(
        new DefaultRedisScript<>(rateLimitScript, Long.class),
        List.of(key),
        String.valueOf(limit),
        String.valueOf(windowSeconds)
    );
    return Long.valueOf(1L).equals(result);
}
```
