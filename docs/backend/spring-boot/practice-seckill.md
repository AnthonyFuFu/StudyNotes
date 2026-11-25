# 實戰：高併發搶票系統

!!! abstract "專案：holidayDessert"

    Spring Boot 3.5 + MySQL + Redis + Kafka。模擬演唱會開賣瞬間的高併發搶票：先把票務資料**預熱**到 Redis，搶票時只操作 Redis，訂單再**非同步**寫回資料庫。後台內建壓力測試工具，可模擬 2,000 名會員同時搶票並回報 TPS。

## 為什麼不能直接查資料庫扣庫存

``` mermaid
flowchart LR
    U(["2,000 個請求<br>同一秒湧入"]) --> APP["應用程式"] --> DB[("MySQL<br>同一列庫存")]
```

- 所有請求都在搶**同一列**的行鎖，變成序列化執行，TPS 只剩幾百
- 連線池（預設 10 條）瞬間被占滿，後面的請求全部逾時
- 「先查剩餘數、再扣減」在並發下會**超賣**

解法的核心思路：**把競爭移出資料庫，越早擋掉越好**。

## 活動生命週期

``` mermaid
flowchart LR
    A["建立活動<br>選擇場地模板"] --> B["座位配置<br>分區 / 排 / 座"] --> C["預熱<br>DB → Redis"] --> D["開賣搶票"] --> E["非同步建立訂單"]
```

- **預熱**：用 Redis 分散式鎖防止多台機器重複初始化；把票種資訊、剩餘數、座位池寫入 Redis（TTL 24 小時）
- **自動關閉**：排程每分鐘檢查，售完、超過售票時間、活動結束時自動關閉預熱

## 四層防護

``` mermaid
flowchart TB
    R(["搶票請求"]) --> L1{"Layer 1<br>Semaphore 流控"}
    L1 -->|"超過 200 併發"| X1["系統繁忙"]
    L1 --> L2{"Layer 2<br>本地剩餘計數器"}
    L2 -->|"本地已售罄"| X2["票已售罄"]
    L2 --> L3{"Layer 3<br>Redis Lua 原子操作"}
    L3 -->|"票數不足 / 超過個人上限"| X3["失敗"]
    L3 -->|"扣票 + 配位成功"| L4["Layer 4<br>非同步寫入 DB"]
```

| 層級 | 技術 | 擋掉什麼 | 為什麼放在這一層 |
|------|------|---------|----------------|
| **1** | `Semaphore(200)` | 超過 200 個同時進行的請求 | 保護 Redis，不讓瞬間流量全部打下去 |
| **2** | `ConcurrentHashMap<typeId, AtomicInteger>` | 已售罄後的所有請求 | 在 JVM 記憶體內判斷，**連網路都不用走** |
| **3** | Redis Lua Script | 超賣、超過個人購買上限 | 單執行緒 + 原子腳本，保證判斷與扣減不可分割 |
| **4** | Kafka / `@Async` | 資料庫寫入壓力 | 削峰填谷，資料庫按自己的速度消化 |

### Layer 1 + 2：JVM 內的快速攔截

``` java
// Layer 1：Semaphore 流控（限制同時進入 Redis 的併發數）
private final Semaphore SEMAPHORE = new Semaphore(200);
// Layer 2：本地剩餘計數器。售罄後直接本地攔截，不打 Redis
private final ConcurrentHashMap<Integer, AtomicInteger> LOCAL_REMAINING = new ConcurrentHashMap<>();

public PurchaseResult purchase(int typeId, int memId, int quantity) {
    if (!SEMAPHORE.tryAcquire()) {                 // 不等待，拿不到就直接回「系統繁忙」
        return PurchaseResult.BUSY;
    }
    try {
        AtomicInteger local = LOCAL_REMAINING.get(typeId);
        if (local != null && local.get() <= 0) {
            return PurchaseResult.SOLD_OUT;        // 本地已知售罄，不打 Redis
        }
        // ... Layer 3：執行 Lua Script
    } finally {
        SEMAPHORE.release();                       // 一定要在 finally 釋放
    }
}
```

!!! info "為什麼用 `tryAcquire()` 而不是 `acquire()`"

    `acquire()` 拿不到許可會**阻塞等待**，Tomcat 執行緒全卡在這裡，等於把問題轉嫁給執行緒池。`tryAcquire()` 立即失敗、立即回應，這就是**快速失敗（Fail Fast）**。

### Layer 3：Redis Lua 原子腳本

一次完成「檢查剩餘數 → 檢查個人上限 → 扣票 → 依序配位」：

``` lua
local quantity  = tonumber(ARGV[1])
local remaining = redis.call('GET', KEYS[1])                    -- ticket:remaining:{typeId}
if not remaining or tonumber(remaining) < quantity then
    return {'-1'}                                               -- 票數不足
end
local rawUserCount = redis.call('GET', KEYS[2])                 -- ticket:user:count:{typeId}:{memId}
local userCount = rawUserCount and tonumber(rawUserCount) or 0
if userCount + quantity > tonumber(ARGV[2]) then
    return {'-2'}                                               -- 超過個人上限
end
redis.call('INCRBY', KEYS[2], quantity)
if not rawUserCount then redis.call('EXPIRE', KEYS[2], ARGV[3]) end
local result = { tostring(redis.call('DECRBY', KEYS[1], quantity)) }
for i = 1, quantity do                                          -- ticket:seats:{typeId}
    local seat = redis.call('LPOP', KEYS[3])                    -- LPOP 連續取出 = 相鄰座位
    if not seat then break end
    table.insert(result, seat)
end
return result
```

!!! tip "為什麼 Lua 能保證原子性"

    Redis 執行命令是**單執行緒**的，一段 Lua Script 會被當成一個命令完整執行，中間不會插入其他客戶端的命令。所以「判斷 + 扣減」不會被打斷，不需要另外加鎖。

**Redis Key 設計**

| Key | 型別 | 內容 |
|-----|------|------|
| `ticket:type:info:{typeId}` | Hash | 票種名稱、票價、每人上限、售票期間 |
| `ticket:remaining:{typeId}` | String | 剩餘票數（Lua `DECRBY`） |
| `ticket:seats:{typeId}` | List | 可售座位池（`排-座`），`LPOP` 取出即為相鄰座位 |
| `ticket:user:count:{typeId}:{memId}` | String | 會員已購張數 |
| `ticket:init:lock:{ticketName}` | String | 預熱用分散式鎖 |

### Layer 4：非同步落地與降級

``` mermaid
flowchart TB
    S["搶票成功"] --> K{"啟用 kafka profile？"}
    K -->|"是"| P["TicketOrderProducer"] --> T[("Kafka Topic")] --> C["TicketOrderConsumer<br>@KafkaListener"]
    K -->|"否"| A["@Async 執行緒池<br>persistOrder()"]
```

- 啟用 `kafka` profile 時訂單訊息送進 Kafka，由 Consumer 寫入 MySQL
- 沒有 Kafka 環境時自動**降級**為 `@Async` 執行緒池，功能不受影響
- 資料庫端再用**條件式 UPDATE** 防止超賣（見[資料存取與交易](data-access.md)），失敗時記錄補償日誌
- 訂單狀態為「待付款」，付款期限 15 分鐘；金額以搶票當下的票價**快照**計算

## 設計取捨

| 決策 | 好處 | 代價 |
|------|------|------|
| 庫存放 Redis | 每秒數萬次扣減 | Redis 與 DB 短暫不一致，需要補償與對帳 |
| 本地計數器 | 售罄後零網路開銷 | 多台機器時各自的本地值可能落後，只用來「提早擋」不用來「決定成功」 |
| 非同步寫 DB | 回應時間與 DB 無關 | 使用者看到成功時，訂單還沒寫入（最終一致） |
| Semaphore 快速失敗 | 保護下游 | 部分使用者看到「系統繁忙」，需要前端引導重試 |

!!! question "面試延伸：如果 Redis 掛了怎麼辦？"

    - Redis 用主從 + 哨兵（或 Cluster）做高可用
    - 預熱資料可從 DB 重建，搶票期間 Redis 掛掉則暫停售票（寧可不賣，不能超賣）
    - DB 端的條件式 UPDATE 是最後防線，就算上游判斷錯誤也不會讓庫存變負數
