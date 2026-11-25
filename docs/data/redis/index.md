---
icon: lucide/layers
---

# Redis 深度

資料結構的底層編碼、持久化與淘汰策略，以及分散式鎖、緩存三大問題、熱 Key / 大 Key 等實戰議題。

**核心技術**：資料結構底層 / 持久化 / 分散式鎖 / 緩存問題 / Cluster

## 學習地圖

``` mermaid
mindmap
  root((Redis 深度))
    五大資料結構 + 底層編碼
      String / List / Hash / Set / ZSet
      ZipList / SkipList / Dict / IntSet
    持久化機制
      RDB（快照）
      AOF（追加日誌）
      混合模式（推薦）
    記憶體淘汰策略（8 種）
    分散式鎖
      SET NX + Lua Script
      Redisson（生產推薦）
    緩存三大問題
      緩存穿透
      緩存擊穿
      緩存雪崩
    Redis Cluster 架構
      16384 槽位分配
      一致性 Hash
    效能優化
      Pipeline
      Lua Script
    熱 Key / 大 Key 處理
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
