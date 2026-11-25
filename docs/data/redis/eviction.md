# 記憶體淘汰策略（8 種）

!!! abstract "本章重點"

    Redis 記憶體用完時，淘汰策略決定要刪掉哪些資料。本章整理 8 種淘汰策略的差異，以及 LRU 與 LFU 在 Redis 中的近似實作與選擇建議。

當 Redis 記憶體達到 maxmemory 上限時，

**根據 maxmemory-policy 決定如何騰出空間**

**針對設有 TTL（過期時間）的 key**

``` text
volatile-lru    → 淘汰最近最少使用的 key（LRU）
volatile-lfu    → 淘汰使用頻率最低的 key（LFU）
```

- volatile-random → 隨機淘汰
- volatile-ttl    → 淘汰 TTL 最短的 key（即將過期）

**針對所有 key**

``` text
allkeys-lru     → 從所有 key 中淘汰 LRU ✅（最常用）
allkeys-lfu     → 從所有 key 中淘汰 LFU
```

- allkeys-random  → 從所有 key 中隨機淘汰

**不淘汰**

- noeviction      → 記憶體滿時直接返回錯誤（預設，生產不推薦）

**LRU vs LFU**

**LRU（Least Recently Used）**

- 按最近使用時間，淘汰最久沒用的
- 問題：偶爾用一次的 key 會佔據位置

**LFU（Least Frequently Used）**

- 按使用頻率，淘汰最少用的
- 更精準，但實作更複雜

**選擇建議**

- 作為緩存使用 → allkeys-lru（最常見）
- 有明確 TTL  → volatile-lru
- 熱點數據明顯 → allkeys-lfu

```yaml
# redis.conf 配置
maxmemory 4gb
maxmemory-policy allkeys-lru
```
