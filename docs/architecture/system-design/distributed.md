# 分散式系統核心

## 一致性模型（從強到弱）

| 模型 | 說明 | 代表 |
|------|------|------|
| **強一致性**（Strong Consistency） | 寫入後立即可讀到最新值，效能差 | ZooKeeper |
| **線性一致性**（Linearizability） | 操作看起來是原子的，有全局排序 | Etcd |
| **順序一致性**（Sequential Consistency） | 所有節點看到的操作順序相同 | |
| **因果一致性**（Causal Consistency） | 有因果關係的操作保持順序 | |
| **最終一致性**（Eventual Consistency） | 允許暫時不一致，最終一致 | Redis 主從、Eureka |
| **弱一致性**（Weak Consistency） | 讀到的不一定是最新的 | |

表格由上到下：一致性越來越弱，可用性與效能越來越好。

## 分散式事務

**問題場景**：訂單服務扣款 + 庫存服務減庫存，如果其中一個失敗怎麼辦？

### 方案一：2PC（Two-Phase Commit，兩階段提交）

- 協調者（Coordinator）

``` text
       /         \
      /           \
 參與者A        參與者B
（訂單服務）   （庫存服務）
```

**Phase 1 - Prepare（準備階段）**

協調者 → 所有參與者：「你可以提交嗎？」

參與者 → 協調者：「可以 / 不可以」

**Phase 2 - Commit（提交階段）**

全部回應「可以」→ 協調者發送 Commit

任一回應「不可以」→ 協調者發送 Rollback

| 優點 | 缺點 |
|------|------|
| 實作簡單 | **同步阻塞**：準備階段鎖定資源 |
| 強一致性 | **單點故障**：協調者掛掉全部卡死 |
| | **腦裂問題**：Commit 訊息部分送達 |

### 方案二：TCC（Try-Confirm-Cancel）

``` mermaid
flowchart LR
    T["Try<br>預留資源"] -->|全部成功| CF["Confirm<br>確認提交資源"]
    T -->|任一失敗| CC["Cancel<br>釋放預留資源"]
```

**電商下單範例：**

**訂單服務**

- Try:     建立訂單（狀態：待確認）
- Confirm: 訂單狀態改為已確認
- Cancel:  刪除訂單

**庫存服務**

- Try:     凍結庫存 N 個（可用庫存 -N，凍結庫存 +N）
- Confirm: 真正扣減庫存（凍結庫存 -N）
- Cancel:  解凍庫存（可用庫存 +N，凍結庫存 -N）

| 優點 | 缺點 |
|------|------|
| 無長時間鎖定 | 業務侵入性高（需實作三個方法）|
| 可控性強 | 程式碼量大 |
| | 需要保證冪等性 |

### 方案三：SAGA 模式

**將分散式事務拆成多個本地事務，每個都有對應的補償事務**

正向流程：T1 → T2 → T3 → T4

失敗補償：T1 → T2 → T3 失敗 → C2 → C1

- ↑（補償事務，撤銷已完成的操作）

**範例：**

``` text
T1: 建立訂單        C1: 取消訂單
T2: 扣減庫存        C2: 恢復庫存
T3: 扣款            C3: 退款
T4: 發送通知        C4: 發送取消通知
```

| 優點 | 缺點 |
|------|------|
| 無鎖定、高效能 | 補償邏輯複雜 |
| 適合長流程業務 | 中間狀態暴露（非強一致）|
| Seata 支援此模式 | 需保證補償事務冪等 |

### 方案四：本地消息表（最終一致性）

``` mermaid
flowchart LR
    subgraph ORDER ["訂單服務"]
        direction TB
        subgraph TX ["同一個 DB、同一個本地事務"]
            OT[("訂單表")]
            MT[("消息表")]
        end
    end
    subgraph STOCK ["庫存服務"]
        direction TB
        CON["消費消息"] --> DED["扣減庫存"]
    end
    MT -- "定時投遞 MQ" --> CON
```

**流程：**
1. 訂單服務：在**同一個事務**中寫訂單 + 寫消息表
2. 定時任務掃描未發送的消息，發到 MQ
3. 庫存服務消費 MQ，扣減庫存
4. 消費成功 → 標記消息已完成

### 方案對比總結

| 方案 | 一致性 | 效能 | 複雜度 | 適用場景 |
|------|--------|------|--------|---------|
| 2PC | 強一致 | ⭐ | 中 | 少量服務，資料庫支援 |
| TCC | 最終一致 | ⭐⭐⭐ | 高 | 對一致性要求高，電商支付 |
| SAGA | 最終一致 | ⭐⭐⭐⭐ | 高 | 長流程業務 |
| 本地消息表 | 最終一致 | ⭐⭐⭐⭐ | 中 | 跨服務異步操作 |

## 分散式鎖

**問題**：多個服務實例同時修改同一份資料怎麼辦？

### Redis 分散式鎖（推薦）

```java
// 錯誤做法 ❌ - 非原子操作
redisTemplate.opsForValue().setIfAbsent(key, value);
redisTemplate.expire(key, 30, TimeUnit.SECONDS);

// 正確做法 ✅ - 原子操作
String result = redisTemplate.execute((RedisCallback<String>) connection -> {
    return connection.set(
        key.getBytes(),
        value.getBytes(),
        Expiration.seconds(30),
        RedisStringCommands.SetOption.SET_IF_ABSENT
    );
});
```

**完整實作（含鎖續期）：**

```java
@Component
public class RedisDistributedLock {

    @Autowired
    private StringRedisTemplate redisTemplate;

    private static final String LOCK_VALUE = UUID.randomUUID().toString();

    public boolean tryLock(String key, long timeout) {
        Boolean result = redisTemplate.opsForValue()
            .setIfAbsent(key, LOCK_VALUE, timeout, TimeUnit.SECONDS);
        return Boolean.TRUE.equals(result);
    }

    public void unlock(String key) {
        String luaScript =
            "if redis.call('get', KEYS[1]) == ARGV[1] then " +
            "   return redis.call('del', KEYS[1]) " +
            "else " +
            "   return 0 " +
            "end";

        redisTemplate.execute(
            new DefaultRedisScript<>(luaScript, Long.class),
            Collections.singletonList(key),
            LOCK_VALUE
        );
    }
}
```

!!! warning

    **為什麼用 Lua 腳本釋放鎖？**
    因為「判斷 value 是否是自己的」和「刪除 key」這兩步必須是**原子操作**，否則可能刪掉別人的鎖！

### Redisson（生產推薦）

```java
RLock lock = redisson.getLock("myLock");
try {
    if (lock.tryLock(3, 10, TimeUnit.SECONDS)) {
        // 業務邏輯
    }
} finally {
    lock.unlock();
}
```

!!! example "我的實作：非同步與最終一致性"

    搶票成功後訂單經 Kafka 非同步寫入資料庫，屬於「先回應、後落地」的最終一致性設計；投遞語意與冪等消費整理在訊息佇列主題。

    👉 [訊息佇列核心概念](../../data/messaging/concepts.md)
