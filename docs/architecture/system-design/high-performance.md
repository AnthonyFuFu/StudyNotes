# 高效能設計

!!! abstract "本章重點"

    當單一資料庫與單層快取撐不住流量時，就需要分庫分表與更完整的快取設計。本章說明垂直與水平切分的差異，以及快取穿透、擊穿、雪崩三大問題的成因與解法。

## 分庫分表

**什麼時候需要？**

!!! info

    MySQL 單表超過 **1000 萬行** 或 **2GB** 時，查詢效能明顯下降，需要考慮分表。

### 垂直切分 vs 水平切分

=== "垂直分庫（按業務）"

    ``` mermaid
    flowchart LR
        APP["應用"] --> ODB[("訂單數據庫<br>order<br>order_item")]
        APP --> UDB[("用戶數據庫<br>user<br>user_address")]
    ```

=== "水平分表（按數據量）"

    ``` mermaid
    flowchart LR
        R{"id % 2"} -->|"= 0"| T0[("order_0<br>id 0, 2, 4 …")]
        R -->|"= 1"| T1[("order_1<br>id 1, 3, 5 …")]
    ```

### 常見分片策略

Hash 取模：  userId % 4 → 均勻分布，但擴容難

Range 範圍：  id 1\~100萬 → shard0，101\~200萬 → shard1

一致性 Hash：  擴容方便，但實作複雜

### ShardingSphere 配置範例

```yaml
spring:
  shardingsphere:
    datasource:
      names: db0, db1
    rules:
      sharding:
        tables:
          t_order:
            actual-data-nodes: db$->{0..1}.t_order_$->{0..1}
            database-strategy:
              standard:
                sharding-column: user_id
                sharding-algorithm-name: db-inline
            table-strategy:
              standard:
                sharding-column: order_id
                sharding-algorithm-name: table-inline
        sharding-algorithms:
          db-inline:
            type: INLINE
            props:
              algorithm-expression: db$->{user_id % 2}
          table-inline:
            type: INLINE
            props:
              algorithm-expression: t_order_$->{order_id % 2}
```

## 緩存設計（三大問題）

### 問題一：緩存穿透（Cache Penetration）

惡意請求不存在的 ID → Redis 沒有 → MySQL 也沒有 → 每次都打到 DB

**解決方案**

- 1\. 緩存空值（存 null，設短過期時間）
- 2\. 布隆過濾器（Bloom Filter）← 推薦

```java
RBloomFilter<Long> bloomFilter = redisson.getBloomFilter("product:ids");
bloomFilter.tryInit(1000000L, 0.01);
bloomFilter.add(productId);

public Product getProduct(Long id) {
    if (!bloomFilter.contains(id)) {
        return null;
    }
    // 查 Redis → 查 DB
}
```

### 問題二：緩存雪崩（Cache Avalanche）

大量緩存同時過期 → 所有請求打到 DB → DB 崩潰

**解決方案**

- 1\. 過期時間加隨機數（30分鐘 + Random(0\~5分鐘)）
- 2\. 熱點數據設為永不過期（邏輯過期）
- 3\. Redis 叢集，避免單點
- 4\. 熔斷降級保護 DB

```java
long expireTime = 1800 + new Random().nextInt(300);
redisTemplate.opsForValue().set(key, value, expireTime, TimeUnit.SECONDS);
```

### 問題三：緩存擊穿（Cache Breakdown）

熱點 Key 過期的瞬間，大量並發請求同時湧入 DB

**解決方案**

- 1\. 互斥鎖（同一時間只有一個請求重建緩存）
- 2\. 邏輯過期（不設 TTL，在 value 中存過期時間）

```java
public Product getProductWithMutex(Long id) {
    String cacheKey = "product:" + id;
    Product product = getFromCache(cacheKey);
    if (product != null) return product;

    String lockKey = "lock:product:" + id;
    boolean locked = tryLock(lockKey);

    try {
        if (locked) {
            product = productMapper.selectById(id);
            setCache(cacheKey, product, 30, TimeUnit.MINUTES);
        } else {
            Thread.sleep(50);
            return getProductWithMutex(id);
        }
    } finally {
        if (locked) unlock(lockKey);
    }

    return product;
}
```
