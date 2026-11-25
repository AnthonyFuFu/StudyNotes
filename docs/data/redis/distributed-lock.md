# 分散式鎖

## SET NX 實作（基礎版）

```java
// ❌ 錯誤方式一：SETNX + EXPIRE 兩步驟（非原子！）
redisTemplate.opsForValue().setIfAbsent("lock:order", "1"); // 成功
// 如果這裡程序崩潰 → 鎖永遠不會過期！（死鎖）
redisTemplate.expire("lock:order", 30, TimeUnit.SECONDS);

// ✅ 正確方式：SET NX EX 原子命令
@Service
public class RedisDistributedLock {

    @Autowired
    private StringRedisTemplate redisTemplate;

    private static final String LOCK_PREFIX = "lock:";

    public boolean tryLock(String lockKey, String requestId, long expireSeconds) {
        String key = LOCK_PREFIX + lockKey;
        // SET key value NX EX seconds → 原子操作
        Boolean success = redisTemplate.opsForValue()
            .setIfAbsent(key, requestId, Duration.ofSeconds(expireSeconds));
        return Boolean.TRUE.equals(success);
    }

    public boolean unlock(String lockKey, String requestId) {
        String key = LOCK_PREFIX + lockKey;
        // ⚠️ 必須用 Lua Script 保證原子性！
        // 防止誤刪其他請求的鎖
        String script =
            "if redis.call('get', KEYS[1]) == ARGV[1] then " +
            "    return redis.call('del', KEYS[1]) " +
            "else " +
            "    return 0 " +
            "end";

        Long result = redisTemplate.execute(
            new DefaultRedisScript<>(script, Long.class),
            List.of(key),
            requestId
        );
        return Long.valueOf(1L).equals(result);
    }
}

// 使用範例
@Service
@RequiredArgsConstructor
public class OrderService {

    private final RedisDistributedLock lock;

    public void createOrder(Long userId) {
        String lockKey   = "order:user:" + userId;
        String requestId = UUID.randomUUID().toString(); // 唯一標識，防止誤刪

        boolean locked = lock.tryLock(lockKey, requestId, 30);
        if (!locked) {
            throw new BusinessException("系統繁忙，請稍後再試");
        }

        try {
            // 業務邏輯（同一用戶同一時間只能有一個請求進入）
            doCreateOrder(userId);
        } finally {
            lock.unlock(lockKey, requestId); // 釋放鎖
        }
    }
}
```

## Redisson（生產推薦）

```java
// Redisson 解決了 SET NX 的問題：
// ✅ 看門狗機制（自動續期，防止業務還沒完成鎖就過期）
// ✅ 可重入鎖（同一線程可以多次獲取）
// ✅ 公平鎖
// ✅ 紅鎖（RedLock，多節點一致性）

// pom.xml
// <dependency>
//     <groupId>org.redisson</groupId>
//     <artifactId>redisson-spring-boot-starter</artifactId>
//     <version>3.24.3</version>
// </dependency>

@Service
@RequiredArgsConstructor
public class OrderService {

    private final RedissonClient redissonClient;

    // 基本使用
    public void createOrder(Long userId) {
        RLock lock = redissonClient.getLock("lock:order:user:" + userId);

        boolean locked = lock.tryLock(3, 30, TimeUnit.SECONDS);
        // tryLock(waitTime, leaseTime, unit)
        // waitTime:  最多等待 3 秒獲取鎖
        // leaseTime: 鎖定最長 30 秒（-1 = 啟用看門狗）

        if (!locked) {
            throw new BusinessException("系統繁忙，請稍後再試");
        }

        try {
            doCreateOrder(userId);
        } finally {
            if (lock.isHeldByCurrentThread()) { // 確保是自己持有的鎖
                lock.unlock();
            }
        }
    }

    // 看門狗機制（leaseTime = -1 時自動啟用）
    public void longRunningTask() {
        RLock lock = redissonClient.getLock("lock:long:task");
        lock.lock(); // 不指定過期時間，看門狗每 10 秒自動續期 30 秒
        try {
            // 耗時很長的任務，不用擔心鎖過期
            processLargeData();
        } finally {
            lock.unlock();
        }
    }

    // 紅鎖（RedLock）- 多個 Redis 節點
    public void redLockExample() {
        RLock lock1 = redissonClient1.getLock("lock:order");
        RLock lock2 = redissonClient2.getLock("lock:order");
        RLock lock3 = redissonClient3.getLock("lock:order");

        // 需要多數節點（3/5）成功才算獲取到鎖
        RLock redLock = redissonClient.getRedLock(lock1, lock2, lock3);

        redLock.lock();
        try {
            // 即使某個 Redis 節點宕機，鎖仍然有效
        } finally {
            redLock.unlock();
        }
    }
}
```

**看門狗（Watchdog）原理**

lock.lock()（不設過期時間）

- ↓

默認鎖定 30 秒（lockWatchdogTimeout）

- ↓

啟動後台線程（每 10 秒檢查一次）

- ↓

如果鎖仍被持有 → 自動延長過期時間到 30 秒

- ↓

業務完成，unlock() → 取消看門狗

**效果**

- 業務執行 5 秒 → 鎖還有 25 秒，不需要續期
- 業務執行 25 秒 → 看門狗在第 10s、20s 各續期一次
- 業務異常崩潰 → 看門狗線程也消失 → 鎖 30 秒後自動過期 ✅

!!! example "我的實作：holidayDessert 搶票預熱"

    預熱活動時以 Redis 分散式鎖（`ticket:init:lock:{ticketName}`）防止多台機器重複初始化；真正的扣票則不用鎖，而是交給 **Lua Script** 一次原子完成判斷與扣減，避免鎖競爭成為瓶頸。

    👉 [實戰：高併發搶票系統](../../backend/spring-boot/practice-seckill.md)
