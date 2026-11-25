# 多級快取與資料一致性

!!! abstract "本章重點"

    Redis 再快也要經過網路，熱點資料放在 JVM 本地記憶體可以快上百倍。本章說明 Caffeine 本地快取的原理、本地 + Redis 的多級快取架構，以及更新資料時如何維持快取與資料庫的一致性。

## 為什麼需要本地快取

| 層級 | 延遲 | 容量 | 共享 |
|------|------|------|------|
| JVM 本地快取（Caffeine） | **約 100 奈秒** | 受 JVM 記憶體限制 | ❌ 每台機器各一份 |
| Redis | 約 0.5 \~ 1 毫秒（含網路） | 數十 GB | ✅ 所有機器共用 |
| MySQL | 數毫秒到數百毫秒 | 無上限 | ✅ |

**適合放本地快取的資料**：讀多寫少、可以容忍短暫不一致、量不大。例如商品分類、系統設定、熱門商品、權限清單，以及 [熱 Key](hot-big-key.md)。

## 多級快取架構

``` mermaid
flowchart TB
    R(["請求"]) --> L1{"L1 本地快取<br>Caffeine"}
    L1 -->|"命中"| OK(["回傳"])
    L1 -->|"未命中"| L2{"L2 Redis"}
    L2 -->|"命中，回填 L1"| OK
    L2 -->|"未命中"| DB[("MySQL")]
    DB -->|"回填 L2、L1"| OK
```

``` java
@Service
@RequiredArgsConstructor
public class CategoryService {

    private final StringRedisTemplate redis;
    private final CategoryRepository repository;

    // L1：最多 1,000 筆、寫入 5 分鐘後過期
    private final Cache<String, List<Category>> local = Caffeine.newBuilder()
            .maximumSize(1_000)
            .expireAfterWrite(Duration.ofMinutes(5))
            .recordStats()                                // 監控命中率
            .build();

    public List<Category> findAll() {
        return local.get("category:all", key -> {         // L1 未命中才執行，且同一個 key 只會載入一次
            String cached = redis.opsForValue().get(key);
            if (cached != null) {
                return JSON.parseArray(cached, Category.class);
            }
            List<Category> fromDb = repository.findAll();
            redis.opsForValue().set(key, JSON.toJSONString(fromDb), Duration.ofMinutes(30));
            return fromDb;
        });
    }
}
```

!!! info "Caffeine 為什麼快、命中率高"

    - **W-TinyLFU** 淘汰演算法：同時考慮「最近」與「頻率」，比單純 LRU 命中率更高，也能抵抗一次性的大量掃描
    - `cache.get(key, loader)` 對同一個 key **只會呼叫一次 loader**，其他執行緒等待結果，天生防止快取擊穿
    - 搭配 Spring：`spring.cache.type=caffeine` 後直接用 `@Cacheable`

## 快取與資料庫的一致性

更新資料時，有「先更新資料庫還是先處理快取」「更新快取還是刪除快取」的選擇：

| 策略 | 問題 |
|------|------|
| 先更新快取，再更新資料庫 | 資料庫失敗時，快取是錯的 |
| 先刪快取，再更新資料庫 | 刪除後、更新前有人讀取，會把**舊資料**寫回快取 |
| **先更新資料庫，再刪除快取**（Cache Aside） ✅ | 不一致的機率最低，是業界最常用的做法 |

``` mermaid
sequenceDiagram
    participant W as 寫入請求
    participant DB as MySQL
    participant R as Redis
    W->>DB: ① UPDATE
    W->>R: ② DEL key
    Note over R: 下一次讀取時才從 DB 重新載入
```

**為什麼是「刪除」而不是「更新」快取**：兩個寫入並發時，更新快取的順序可能與資料庫相反，造成永久不一致；刪除則讓下一次讀取自然載入最新值，而且很多寫入的資料其實沒人讀，沒必要先算好放進快取。

**還不夠可靠時的補強**

| 手段 | 做法 |
|------|------|
| **延遲雙刪** | 更新資料庫 → 刪快取 → 延遲數百毫秒再刪一次，處理讀寫並發寫回舊值的情況 |
| **刪除失敗重試** | 刪快取失敗時送進 MQ 重試 |
| **訂閱 Binlog** | 用 Canal / Debezium 監聽 MySQL Binlog，由獨立程序刪除快取，業務程式碼不需要處理 |
| **一定要設 TTL** | 最後一道防線：就算刪除全部失敗，資料最多不一致到過期為止 |

## 多台機器的本地快取怎麼同步

Redis 是共用的，刪一次就好；本地快取每台機器各一份，要通知所有機器一起失效：

``` mermaid
flowchart LR
    A["機器 A<br>更新資料"] -- "PUBLISH cache:invalidate category:all" --> R[("Redis Pub/Sub")]
    R --> A2["機器 A 清除 L1"]
    R --> B["機器 B 清除 L1"]
    R --> C["機器 C 清除 L1"]
```

``` java
// 更新後廣播失效訊息
redis.convertAndSend("cache:invalidate", "category:all");

// 每台機器都訂閱，收到後清除本地快取
@Bean
RedisMessageListenerContainer invalidateListener(RedisConnectionFactory cf, CategoryService svc) {
    var container = new RedisMessageListenerContainer();
    container.setConnectionFactory(cf);
    container.addMessageListener((msg, pattern) -> svc.evictLocal(new String(msg.getBody())),
            new ChannelTopic("cache:invalidate"));
    return container;
}
```

!!! warning "Pub/Sub 不保證送達"

    Redis Pub/Sub 沒有持久化，訂閱者斷線期間的訊息會遺失。所以本地快取的 TTL 要設得短（數分鐘），讓漏掉的失效訊息最多影響到過期為止；需要可靠送達時改用 Redis Stream 或 MQ。

## 我的實作

holidayDessert 的搶票系統就是「本地 + Redis」兩層：`ConcurrentHashMap<typeId, AtomicInteger>` 在 JVM 內記錄剩餘票數，售罄後直接攔截，連 Redis 都不用打；真正的扣票仍以 Redis Lua 為準（見[高併發搶票系統](../../backend/spring-boot/practice-seckill.md)）。這正是本地快取的正確用法：**用來提早擋下請求，不用來決定最終結果**。
