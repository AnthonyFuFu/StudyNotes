# 分庫分表

## 什麼時候需要分庫分表？

```
單表問題：
  MySQL 單表資料量超過 1000 萬行 → 查詢效能下降
  MySQL 單庫連線數、磁碟 IO 成為瓶頸

垂直切分（按業務）：
  ┌─────────────────┐       ┌─────────────────┐
  │   訂單數據庫      │       │   用戶數據庫      │
  │  - orders       │       │  - users         │
  │  - order_items  │       │  - addresses     │
  └─────────────────┘       └─────────────────┘
  優點：業務清晰，解耦
  缺點：跨庫 JOIN 困難，需要分散式事務

水平切分（按數據量）：
  ┌──────────────────┐  ┌──────────────────┐
  │  orders_0         │  │  orders_1         │
  │  user_id % 2 = 0  │  │  user_id % 2 = 1  │
  │  id: 2,4,6,8...   │  │  id: 1,3,5,7...   │
  └──────────────────┘  └──────────────────┘
  優點：每個表數據量減半，效能提升
  缺點：跨表查詢困難，分散式事務複雜
```

## ShardingSphere 實戰

```yaml
# application.yml（ShardingSphere 5.x）
spring:
  shardingsphere:
    datasource:
      names: db0, db1
      db0:
        type: com.zaxxer.hikari.HikariDataSource
        url: jdbc:mysql://host0:3306/order_db0
        username: root
        password: password
      db1:
        type: com.zaxxer.hikari.HikariDataSource
        url: jdbc:mysql://host1:3306/order_db1
        username: root
        password: password

    rules:
      sharding:
        tables:
          t_order:
            # 實際物理表：db0.t_order_0, db0.t_order_1, db1.t_order_0, db1.t_order_1
            actual-data-nodes: db$->{0..1}.t_order_$->{0..1}

            # 分庫策略（按 user_id 決定去哪個庫）
            database-strategy:
              standard:
                sharding-column: user_id
                sharding-algorithm-name: db-inline

            # 分表策略（按 order_id 決定去哪個表）
            table-strategy:
              standard:
                sharding-column: order_id
                sharding-algorithm-name: table-inline

            # 分散式主鍵生成
            key-generate-strategy:
              column: order_id
              key-generator-name: snowflake

        sharding-algorithms:
          db-inline:
            type: INLINE
            props:
              algorithm-expression: db$->{user_id % 2}
          table-inline:
            type: INLINE
            props:
              algorithm-expression: t_order_$->{order_id % 2}

        key-generators:
          snowflake:
            type: SNOWFLAKE

    props:
      sql-show: true   # 顯示實際執行的 SQL（調試用）
```

## 分散式主鍵生成（雪花算法）

```
雪花算法（Snowflake）：Twitter 發明的分散式 ID 生成方案

64 位 Long 型 ID 結構：
┌──────────────────────────────────────────────────────────────┐
│ 0 │ 41位時間戳 │ 10位機器ID │ 12位序列號 │
│符號│（毫秒）    │ (5位DC+5位機器) │ (4096/ms)  │
└──────────────────────────────────────────────────────────────┘

時間戳：41位，可用約 69 年
機器ID：10位，最多 1024 個節點
序列號：12位，每毫秒最多生成 4096 個 ID

特點：
✅ 全局唯一
✅ 趨勢遞增（適合做主鍵，避免 B+樹頻繁頁分裂）
✅ 不依賴資料庫（高效能）
✅ 包含時間戳（可以從 ID 推算大概生成時間）

缺點：
❌ 依賴系統時鐘（時鐘回撥會導致 ID 重複！）
❌ 需要配置不同機器的 workerId
```

```java
// Spring Boot 中使用雪花算法
@Component
public class SnowflakeIdGenerator {

    private final long workerId;
    private final long datacenterId;
    private long sequence        = 0L;
    private long lastTimestamp   = -1L;

    // 各部分位數
    private static final long WORKER_ID_BITS     = 5L;
    private static final long DATACENTER_ID_BITS = 5L;
    private static final long SEQUENCE_BITS      = 12L;

    // 最大值
    private static final long MAX_WORKER_ID      = ~(-1L << WORKER_ID_BITS);      // 31
    private static final long MAX_DATACENTER_ID  = ~(-1L << DATACENTER_ID_BITS);  // 31
    private static final long MAX_SEQUENCE       = ~(-1L << SEQUENCE_BITS);       // 4095

    // 移位
    private static final long WORKER_ID_SHIFT     = SEQUENCE_BITS;               // 12
    private static final long DATACENTER_ID_SHIFT = SEQUENCE_BITS + WORKER_ID_BITS; // 17
    private static final long TIMESTAMP_SHIFT     = SEQUENCE_BITS + WORKER_ID_BITS + DATACENTER_ID_BITS; // 22

    // 起始時間（2024-01-01 00:00:00 UTC）
    private static final long EPOCH = 1704067200000L;

    public SnowflakeIdGenerator(
            @Value("${app.snowflake.worker-id:1}") long workerId,
            @Value("${app.snowflake.datacenter-id:1}") long datacenterId) {
        this.workerId     = workerId;
        this.datacenterId = datacenterId;
    }

    public synchronized long nextId() {
        long timestamp = System.currentTimeMillis();

        // 時鐘回撥處理
        if (timestamp < lastTimestamp) {
            throw new RuntimeException(
                "時鐘回撥，拒絕生成 ID，回撥時間：" + (lastTimestamp - timestamp) + " ms"
            );
        }

        if (timestamp == lastTimestamp) {
            // 同一毫秒內，序列號遞增
            sequence = (sequence + 1) & MAX_SEQUENCE;
            if (sequence == 0) {
                // 序列號溢出，等待下一毫秒
                timestamp = waitNextMillis(lastTimestamp);
            }
        } else {
            sequence = 0L;
        }

        lastTimestamp = timestamp;

        return ((timestamp - EPOCH) << TIMESTAMP_SHIFT)
            | (datacenterId << DATACENTER_ID_SHIFT)
            | (workerId     << WORKER_ID_SHIFT)
            | sequence;
    }

    private long waitNextMillis(long lastTimestamp) {
        long timestamp = System.currentTimeMillis();
        while (timestamp <= lastTimestamp) {
            timestamp = System.currentTimeMillis();
        }
        return timestamp;
    }
}
```
