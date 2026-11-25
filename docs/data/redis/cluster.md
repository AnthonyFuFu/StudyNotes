# Redis Cluster 架構

!!! abstract "本章重點"

    單台 Redis 的記憶體與吞吐量有上限，Redis Cluster 把資料分散到多個節點。本章說明 16384 個槽位的分配方式、客戶端如何找到正確的節點，以及節點故障時的自動切換。

## 16384 槽位（Slot）

**Redis Cluster 不使用一致性 Hash，使用槽位分配**

集群將 key 空間分為 16384 個 slot（0 \~ 16383）

每個 key 根據 CRC16(key) % 16384 計算所屬 slot

每個 Master 節點負責一部分 slot

**3 主 3 從範例**

- Master1：slot 0 \~ 5460
- Master2：slot 5461 \~ 10922
- Master3：slot 10923 \~ 16383
- Slave1：Master1 的副本
- Slave2：Master2 的副本
- Slave3：Master3 的副本

**請求路由**

- 客戶端發送 GET order:123
- 計算 CRC16("order:123") % 16384 = 7890
- → 屬於 Master2 的範圍
- → 如果連的不是 Master2，返回 MOVED 7890 master2_ip:port
- → 客戶端重新連到 Master2

**Hash Tag（強制同槽）**

- 多個 key 加上相同的 {} 標記
- MSET {user:1}:name "Alice" {user:1}:email "alice@example.com"
- → {} 內容相同 → 計算相同 slot → 在同一個節點
- → 可以使用 MSET / MGET 等多 key 命令

**節點故障處理**

- Master1 宕機
- → Slave1 等待 cluster-node-timeout（預設 15s）
- → Slave1 發起選舉，其他 Master 投票
- → Slave1 升為新 Master
- → 繼續服務

```yaml
# application.yml（Spring Boot 連接 Redis Cluster）
spring:
  redis:
    cluster:
      nodes:
        - redis-node1:6379
        - redis-node2:6379
        - redis-node3:6379
        - redis-node4:6379
        - redis-node5:6379
        - redis-node6:6379
      max-redirects: 3  # 最多重定向次數
    lettuce:
      cluster:
        refresh:
          adaptive: true          # 自動感知集群拓撲變化
          period: 30s
```
