# 五大資料結構 + 底層編碼

## 為什麼要了解底層編碼？

Redis 的每種資料結構，會根據「元素數量」和「元素大小」

自動選擇不同的底層編碼（encoding）

→ 小數據用壓縮結構（省記憶體）

→ 大數據用效能結構（速度快）

**面試常問**

- "ZSet 底層是什麼？"
- → 少量用 ZipList，大量用 SkipList + Dict

了解底層 → 才能解釋為什麼 Redis 這麼快、這麼省記憶體

## String（字串）

**底層編碼（三種）**

| 編碼 | 條件 | 特點 |
|------|------|------|
| `int` | 整數值，且範圍在 long 內（如 `SET counter 100`） | 直接用 long 存，不需要字串物件 |
| `embstr` | 字串長度 ≤ 44 bytes | RedisObject + SDS 一次性分配連續記憶體，只需一次 malloc |
| `raw` | 字串長度 > 44 bytes | RedisObject 和 SDS 分開分配，兩次 malloc |

**SDS（Simple Dynamic String）結構**

``` mermaid
block-beta
    columns 6
    len["len<br>已用長度"] alloc["alloc<br>容量"] flags["flags<br>類型"] buf["buf[]<br>實際字串內容"]:3
```

相較 C 字串的優勢：

- ✅ O(1) 取得長度（直接讀 len，不用遍歷）
- ✅ 二進制安全（可以存 `\0`）
- ✅ 預分配空間，減少記憶體重分配次數

```java
// String 常用場景
@Autowired
private StringRedisTemplate redisTemplate;

// 1. 緩存（最常用）
redisTemplate.opsForValue().set("user:1", json, Duration.ofMinutes(30));
String cached = redisTemplate.opsForValue().get("user:1");

// 2. 計數器（原子操作）
Long count = redisTemplate.opsForValue().increment("article:100:views");
redisTemplate.opsForValue().increment("api:rate:user:1", 1);

// 3. 分散式 Session
redisTemplate.opsForValue().set(
    "session:" + sessionId,
    userJson,
    Duration.ofHours(2)
);

// 4. 冪等性控制（SET NX）
Boolean isNew = redisTemplate.opsForValue()
    .setIfAbsent("idempotency:" + requestId, "1", Duration.ofHours(24));
if (!Boolean.TRUE.equals(isNew)) {
    return "重複請求";
}
```

## List（列表）

**底層編碼**

**listpack（JDK 7.0+ 替代 ZipList）**

- 元素數量 ≤ 128 個 且 每個元素 ≤ 64 bytes
- 緊湊的連續記憶體結構

**quicklist（預設）**

- 雙向鏈表，每個節點是一個 listpack
- 兼顧記憶體和效能

**操作複雜度**

- LPUSH / RPUSH：O(1)  → 頭尾插入
- LPOP / RPOP：  O(1)  → 頭尾刪除

``` text
LINDEX：       O(n)  → 按索引查詢（需遍歷）
LRANGE：       O(n)  → 範圍查詢
```

```java
// List 常用場景

// 1. 消息佇列（簡單版）
// 生產者
redisTemplate.opsForList().leftPush("task:queue", taskJson);

// 消費者（阻塞等待，BLPOP）
List<String> result = redisTemplate.opsForList()
    .rightPop("task:queue", Duration.ofSeconds(30)); // 阻塞 30 秒

// 2. 最新動態列表（朋友圈 / 訊息流）
// 只保留最新 100 條
redisTemplate.opsForList().leftPush("user:1:feed", postJson);
redisTemplate.opsForList().trim("user:1:feed", 0, 99); // 只保留 0~99

// 3. 操作歷史（最近瀏覽）
redisTemplate.opsForList().leftPush("user:1:history", productId);
redisTemplate.opsForList().trim("user:1:history", 0, 9); // 只保留最近 10 條
List<String> history = redisTemplate.opsForList().range("user:1:history", 0, -1);
```

## Hash（雜湊）

**底層編碼**

**listpack**

- 元素數量 ≤ 128 個 且 每個 field/value ≤ 64 bytes

**hashtable**

- 超過閾值自動轉換
- 拉鏈法解決 Hash 衝突（和 Java HashMap 類似）
- 負載因子 > 1 時觸發 rehash（漸進式，不阻塞）

**漸進式 rehash**

- 同時維護 ht[0]（舊）和 ht[1]（新）
- 每次讀寫操作，順便遷移一個桶
- 遷移完成後，ht[0] = ht[1]
- → 避免一次性 rehash 導致服務卡頓！

```java
// Hash 常用場景

// 1. 存儲物件（避免 JSON 序列化開銷）
Map<String, String> userFields = new HashMap<>();
userFields.put("name",  "Alice");
userFields.put("email", "alice@example.com");
userFields.put("age",   "25");
redisTemplate.opsForHash().putAll("user:1", userFields);

// 單獨更新某個欄位（不需要讀整個物件）
redisTemplate.opsForHash().put("user:1", "age", "26");

// 讀取特定欄位
String name = (String) redisTemplate.opsForHash().get("user:1", "name");

// 2. 購物車（Hash field = productId, value = quantity）
redisTemplate.opsForHash().increment("cart:user:1", "product:100", 1);
redisTemplate.opsForHash().increment("cart:user:1", "product:200", 2);
Map<Object, Object> cart = redisTemplate.opsForHash().entries("cart:user:1");
// 刪除商品
redisTemplate.opsForHash().delete("cart:user:1", "product:100");

// 3. 計數器集合
redisTemplate.opsForHash().increment("article:100:stats", "views",   1);
redisTemplate.opsForHash().increment("article:100:stats", "likes",   1);
redisTemplate.opsForHash().increment("article:100:stats", "comments",1);
```

## Set（集合）

**底層編碼**

**intset**

- 所有元素都是整數 且 元素數量 ≤ 512
- 有序整數陣列，二分搜尋

**hashtable**

- 超過閾值自動轉換
- value 都為 null

**特點**

- 元素不重複
- 支援集合運算（交集 / 並集 / 差集）
- 時間複雜度 O(1) 查詢

```java
// Set 常用場景

// 1. 點讚（去重）
redisTemplate.opsForSet().add("article:100:likes", userId.toString());
Long likeCount = redisTemplate.opsForSet().size("article:100:likes");
Boolean hasLiked = redisTemplate.opsForSet().isMember("article:100:likes", userId.toString());
// 取消點讚
redisTemplate.opsForSet().remove("article:100:likes", userId.toString());

// 2. 共同好友（交集）
Set<String> friends1   = redisTemplate.opsForSet().members("user:1:friends");
Set<String> friends2   = redisTemplate.opsForSet().members("user:2:friends");
Set<String> commonFriends = redisTemplate.opsForSet()
    .intersect("user:1:friends", "user:2:friends");

// 3. 抽獎（隨機取元素）
// 不移除（可重複中獎）
String winner = redisTemplate.opsForSet().randomMember("lottery:pool");
// 移除（不可重複中獎）
String winner2 = redisTemplate.opsForSet().pop("lottery:pool");

// 4. UV 統計（獨立訪客，用 HyperLogLog 更省記憶體）
redisTemplate.opsForHyperLogLog().add("page:home:uv", userId.toString());
Long uv = redisTemplate.opsForHyperLogLog().size("page:home:uv");
// HyperLogLog：記憶體固定 12KB，誤差 < 0.81%（不需要精確時使用）
```

## ZSet（有序集合）⭐ 最重要

**底層編碼**

**listpack**

- 元素數量 ≤ 128 個 且 每個元素 ≤ 64 bytes

**skiplist + dict（跳表 + 字典）**

- 超過閾值自動轉換

**為什麼要兩個結構？**

- dict：   member → score（O(1) 查詢某個 member 的 score）
- skiplist：按 score 排序（O(log n) 範圍查詢）

**跳表（SkipList）結構**

``` text
level 3: 1 ──────────────────────────────→ 9
level 2: 1 ──────────→ 5 ──────────────→ 9
```

level 1: 1 → 2 → 3 → 5 → 6 → 7 → 8 → 9

查詢從最高層開始，快速跳過不需要的節點

時間複雜度：O(log n)

**為什麼用跳表而不是紅黑樹？**

- ✅ 範圍查詢更簡單（跳表葉節點連結）
- ✅ 實作更簡單（紅黑樹複雜）
- ✅ 並發友好（跳表局部修改，紅黑樹旋轉影響範圍大）

```java
// ZSet 常用場景

// 1. 排行榜（score = 分數 / 積分）
// 新增或更新分數
redisTemplate.opsForZSet().add("game:leaderboard", "player:Alice", 9500.0);
redisTemplate.opsForZSet().incrementScore("game:leaderboard", "player:Bob", 100.0);

// 取前 10 名（由高到低）
Set<ZSetOperations.TypedTuple<String>> top10 =
    redisTemplate.opsForZSet()
        .reverseRangeWithScores("game:leaderboard", 0, 9);

// 查詢某玩家排名（0-based）
Long rank = redisTemplate.opsForZSet()
    .reverseRank("game:leaderboard", "player:Alice");

// 2. 延遲佇列（score = 執行時間戳）
long executeAt = System.currentTimeMillis() + 30_000; // 30 秒後執行
redisTemplate.opsForZSet().add("delay:queue", taskJson, executeAt);

// 定期輪詢（每秒查詢到期任務）
@Scheduled(fixedRate = 1000)
public void pollDelayQueue() {
    long now = System.currentTimeMillis();
    Set<String> dueTasks = redisTemplate.opsForZSet()
        .rangeByScore("delay:queue", 0, now);
    // 處理到期任務並移除
    dueTasks.forEach(task -> {
        processTask(task);
        redisTemplate.opsForZSet().remove("delay:queue", task);
    });
}

// 3. 時間軸（score = 時間戳）
redisTemplate.opsForZSet().add(
    "user:1:timeline",
    postJson,
    (double) System.currentTimeMillis()
);
// 查詢最新 20 條
Set<String> timeline = redisTemplate.opsForZSet()
    .reverseRange("user:1:timeline", 0, 19);
```
