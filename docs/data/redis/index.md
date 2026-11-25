---
icon: lucide/layers
---

# Redis 深度

資料結構的底層編碼、持久化與淘汰策略，以及分散式鎖、緩存三大問題、熱 Key / 大 Key 等實戰議題。

**核心技術**：資料結構底層 / 持久化 / 分散式鎖 / 緩存問題 / Cluster

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Redis 深度"])
    c0["01 · 五大資料結構 + 底層編碼"]
    R --> c0
    p0("・String / List / Hash / Set / ZSet<br>・ZipList / SkipList / Dict / IntSet")
    c0 --- p0
    c1["02 · 持久化機制"]
    R --> c1
    p1("・RDB（快照）<br>・AOF（追加日誌）<br>・混合模式（推薦）")
    c1 --- p1
    c2["03 · 記憶體淘汰策略（8 種）"]
    R --> c2
    c3["04 · 分散式鎖"]
    R --> c3
    p3("・SET NX + Lua Script<br>・Redisson（生產推薦）")
    c3 --- p3
    c4["05 · 緩存三大問題"]
    R --> c4
    p4("・緩存穿透<br>・緩存擊穿<br>・緩存雪崩")
    c4 --- p4
    c5["06 · Redis Cluster 架構"]
    R --> c5
    p5("・16384 槽位分配<br>・一致性 Hash")
    c5 --- p5
    c6["07 · 效能優化"]
    R --> c6
    p6("・Pipeline<br>・Lua Script")
    c6 --- p6
    c7["08 · 熱 Key / 大 Key 處理"]
    R --> c7
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5,c6,c7 chapter
    class p0,p1,p3,p4,p5,p6 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 資料結構與底層編碼](data-structures.md)__

    ---

    為什麼要了解底層編碼？ · String · List · Hash · Set …

-   __[02 · 持久化機制](persistence.md)__

    ---

    RDB · AOF · 混合持久化

-   __[03 · 記憶體淘汰策略](eviction.md)__

    ---

    記憶體淘汰策略（8 種）

-   __[04 · 分散式鎖](distributed-lock.md)__

    ---

    SET NX 實作 · Redisson

-   __[05 · 緩存三大問題](cache-problems.md)__

    ---

    緩存穿透 · 緩存擊穿 · 緩存雪崩

-   __[06 · Redis Cluster 架構](cluster.md)__

    ---

    16384 槽位

-   __[07 · 效能優化](performance.md)__

    ---

    Pipeline · Lua Script

-   __[08 · 熱 Key / 大 Key 處理](hot-big-key.md)__

    ---

    熱 Key · 大 Key

</div>

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **String 編碼** | int / embstr（≤44B）/ raw，底層是 SDS |
| **List 編碼** | listpack（小）→ quicklist（大）|
| **Hash 編碼** | listpack（小）→ hashtable，漸進式 rehash |
| **Set 編碼** | intset（純整數）→ hashtable |
| **ZSet 編碼** | listpack（小）→ skiplist + dict，跳表支援範圍查詢 |
| **跳表 vs 紅黑樹** | 跳表範圍查詢更簡單，實作更容易，並發友好 |
| **RDB** | 二進制快照，bgsave fork 子程序，恢復快 |
| **AOF** | 追加命令日誌，everysec 最多丟 1 秒，支援重寫 |
| **混合持久化** | RDB 快照 + AOF 增量，推薦生產使用 |
| **淘汰策略** | 作為緩存用 allkeys-lru，有 TTL 用 volatile-lru |
| **分散式鎖** | SET NX + Lua 釋放，生產用 Redisson（看門狗機制）|
| **緩存穿透** | 布隆過濾器 / 緩存空值 |
| **緩存擊穿** | 互斥鎖重建 / 邏輯過期（熱點數據）|
| **緩存雪崩** | TTL 隨機化 / 多級緩存 / Redis 高可用 |
| **Cluster** | 16384 槽位，CRC16 取模路由，MOVED 重定向 |
| **Pipeline** | 批量命令一次網路往返，提升吞吐量 |
| **Lua Script** | 原子操作，適合限流 / 分散式鎖釋放 |
| **熱 Key** | 本地緩存 / Key 分片打散熱點 |
| **大 Key** | UNLINK 非同步刪除，SCAN 分批刪除，避免阻塞 |
