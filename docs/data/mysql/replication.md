# 主從複製與讀寫分離

## Binlog 複製原理

``` mermaid
flowchart TB
    W(["寫操作 INSERT / UPDATE / DELETE"]) --> M[("Master：Binlog")]
    M -- I/O Thread --> R1
    M -- I/O Thread --> R2
    subgraph Slave1 ["Slave 1"]
        direction LR
        R1[("Relay Log")] -- SQL Thread --> S1["重放 SQL"]
    end
    subgraph Slave2 ["Slave 2"]
        direction LR
        R2[("Relay Log")] -- SQL Thread --> S2["重放 SQL"]
    end
    Slave1 & Slave2 --> Q(["讀操作 SELECT"])
```

**複製流程**

1. Master 執行 SQL，寫入 Binlog
2. Slave 的 I/O Thread 連接 Master，讀取 Binlog
3. Slave 將 Binlog 寫入本地 Relay Log（中繼日誌）
4. Slave 的 SQL Thread 重放 Relay Log 中的 SQL

**Binlog 格式**

| 格式 | 記錄內容 | 特性 |
|------|---------|------|
| `STATEMENT` | SQL 語句 | 體積小，但可能主從不一致 |
| `ROW` :star: | 每一行的實際變化 | 體積大，但準確（推薦） |
| `MIXED` | 混合模式 | 由 MySQL 自動選擇 |

!!! warning "主從延遲問題"

    Master 寫入後立即查 Slave，可能讀到舊資料。解決方案：

    1. **寫後讀**：寫操作之後的讀請求，路由到 Master
    2. **半同步複製**：Master 等至少一個 Slave 確認收到才返回
    3. **並行複製**：Slave 多執行緒重放（MySQL 5.6+）

## 讀寫分離實作（Spring Boot）

```yaml
# application.yml
spring:
  datasource:
    master:
      url: jdbc:mysql://master-host:3306/mydb
      username: root
      password: password
      driver-class-name: com.mysql.cj.jdbc.Driver
    slave1:
      url: jdbc:mysql://slave1-host:3306/mydb
      username: readonly
      password: password
      driver-class-name: com.mysql.cj.jdbc.Driver
    slave2:
      url: jdbc:mysql://slave2-host:3306/mydb
      username: readonly
      password: password
      driver-class-name: com.mysql.cj.jdbc.Driver
```

```java
// 自定義讀寫分離路由
public enum DataSourceType {
    MASTER, SLAVE
}

// ThreadLocal 存放當前數據源類型
public class DataSourceContextHolder {
    private static final ThreadLocal<DataSourceType> CONTEXT_HOLDER =
        new ThreadLocal<>();

    public static void setDataSourceType(DataSourceType type) {
        CONTEXT_HOLDER.set(type);
    }

    public static DataSourceType getDataSourceType() {
        return CONTEXT_HOLDER.get();
    }

    public static void clearDataSourceType() {
        CONTEXT_HOLDER.remove();
    }
}

// 動態數據源路由
@Component
public class DynamicDataSource extends AbstractRoutingDataSource {

    @Override
    protected Object determineCurrentLookupKey() {
        DataSourceType type = DataSourceContextHolder.getDataSourceType();
        return type == null ? DataSourceType.MASTER : type;
    }
}

// AOP 自動切換數據源
@Aspect
@Component
@Order(1)  // 優先於事務切面
public class DataSourceAspect {

    // @Transactional(readOnly=true) → Slave
    // @Transactional → Master
    @Around("@annotation(transactional)")
    public Object around(ProceedingJoinPoint point,
                         Transactional transactional) throws Throwable {
        try {
            if (transactional.readOnly()) {
                DataSourceContextHolder.setDataSourceType(DataSourceType.SLAVE);
            } else {
                DataSourceContextHolder.setDataSourceType(DataSourceType.MASTER);
            }
            return point.proceed();
        } finally {
            DataSourceContextHolder.clearDataSourceType();
        }
    }
}

// 使用
@Service
public class OrderService {

    @Transactional  // → Master（寫操作）
    public Order createOrder(OrderRequest request) { ... }

    @Transactional(readOnly = true)  // → Slave（讀操作）
    public Order getOrder(Long id) { ... }
}

// 生產環境推薦：使用 ShardingSphere 或 MyBatis-Plus 的讀寫分離功能
```
