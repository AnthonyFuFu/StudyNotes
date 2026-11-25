# 資料存取與交易

Spring Boot 存取關聯式資料庫有好幾種方式，各有適用場景。holidayDessert 同時用了 **Spring Data JPA** 和 **JdbcTemplate**。

## 三種資料存取方式

=== "Spring Data JPA"

    ``` java
    public interface ProductRepository extends JpaRepository<Product, Integer> {
        // 依方法名稱自動產生 SQL
        List<Product> findByCategoryIdAndStatusOrderByCreateTimeDesc(Integer categoryId, String status);

        @Query("SELECT p FROM Product p WHERE p.price BETWEEN :min AND :max")
        Page<Product> findByPriceRange(BigDecimal min, BigDecimal max, Pageable pageable);
    }
    ```

=== "JdbcTemplate"

    ``` java
    @Repository
    @RequiredArgsConstructor
    public class OrderDao {
        private final JdbcTemplate jdbcTemplate;

        public int markPaid(int orderId) {
            // 自己寫 SQL，完全掌控執行計畫
            return jdbcTemplate.update(
                "UPDATE orders SET status = 'PAID' WHERE order_id = ? AND status = 'PENDING'", orderId);
        }
    }
    ```

=== "MyBatis"

    ``` java
    @Mapper
    public interface MemberMapper {
        @Select("SELECT * FROM member WHERE mem_id = #{id}")   // #{} 會用 PreparedStatement，防 SQL 注入
        Member findById(Integer id);
    }
    ```

| | Spring Data JPA | JdbcTemplate | MyBatis |
|---|-----------------|--------------|---------|
| 抽象層級 | 高（ORM，操作物件） | 低（直接寫 SQL） | 中（SQL 與物件對映） |
| 開發速度 | ✅ 最快，CRUD 不用寫 SQL | 慢 | 中 |
| SQL 掌控度 | ❌ 低，複雜查詢不好寫 | ✅ 完全掌控 | ✅ 高 |
| 效能陷阱 | N+1 查詢、延遲載入 | 少 | 少 |
| 適合 | 標準 CRUD、領域模型清楚 | 報表、批次、條件式更新 | 複雜 SQL 多的業務系統 |

!!! warning "JPA 的 N+1 問題"

    查詢 100 筆訂單，存取每筆的 `order.getItems()` 時又各發 1 次查詢，總共 101 次。解法：`JOIN FETCH`、`@EntityGraph`，或在列表查詢改用 DTO 投影。

## 連線池：HikariCP

Spring Boot 預設的連線池。建立資料庫連線（TCP 握手 + 認證）很貴，連線池預先建好一批連線重複使用。

| 參數 | 預設 | 說明 |
|------|------|------|
| `maximum-pool-size` | 10 | 最大連線數，**不是越大越好**，常見公式：`CPU 核心數 × 2 + 磁碟數` |
| `minimum-idle` | 同上 | 最少閒置連線 |
| `connection-timeout` | 30s | 拿不到連線多久後拋例外 |
| `max-lifetime` | 30min | 連線最長存活時間，需**短於資料庫的 `wait_timeout`** |

## @Transactional 原理

``` mermaid
sequenceDiagram
    participant C as 呼叫方
    participant P as 代理（TransactionInterceptor）
    participant S as 目標方法
    participant DB as 資料庫連線
    C->>P: createOrder()
    P->>DB: 取得連線，setAutoCommit(false)
    Note over P: 連線綁定到 ThreadLocal
    P->>S: 執行業務邏輯
    alt 正常結束
        P->>DB: commit()
    else 拋出 RuntimeException
        P->>DB: rollback()
    end
```

**傳播行為（Propagation）**

| 傳播 | 已有交易時 | 沒有交易時 | 用途 |
|------|-----------|-----------|------|
| `REQUIRED`（預設） | 加入 | 新建 | 一般業務方法 |
| `REQUIRES_NEW` | **暫停外層，另開新交易** | 新建 | 寫稽核日誌、補償紀錄：外層失敗也要保留 |
| `NESTED` | 建立 Savepoint | 新建 | 局部失敗只回滾一段 |
| `SUPPORTS` | 加入 | 不使用交易 | 查詢方法 |

### @Transactional 失效的常見原因

| 情境 | 原因 | 解法 |
|------|------|------|
| **同一類別內自我呼叫** | `this.method()` 沒有經過代理 | 拆到另一個 Bean，或注入自己 |
| 方法不是 `public` | 代理只攔截 public 方法 | 改為 public |
| 拋出 checked exception | 預設只對 `RuntimeException` / `Error` 回滾 | `@Transactional(rollbackFor = Exception.class)` |
| 例外被 `try-catch` 吞掉 | 代理沒看到例外 | 重新拋出，或 `setRollbackOnly()` |
| 在 `@Async` 執行緒中 | 交易綁定在 ThreadLocal，換執行緒就沒了 | 在非同步方法內自己開交易 |

## 用資料庫防止超賣：條件式 UPDATE

就算前面有 Redis 擋住，**資料庫仍然是最後一道防線**。holidayDessert 搶票訂單落地時使用條件式更新（示意）：

``` sql
UPDATE ticket_type
   SET type_remaining = type_remaining - ?
 WHERE type_id = ?
   AND type_remaining >= ?      -- 庫存不足時影響 0 筆，不會變成負數
```

回傳影響筆數為 0 就代表庫存不足，交由補償邏輯處理。這比「先 SELECT 再 UPDATE」安全，因為判斷和扣減在**同一條 SQL 內原子完成**（InnoDB 會加行鎖）。

## 優點與缺點

=== "優點"

    - **宣告式交易**：一個註解處理開啟、提交、回滾，業務程式碼乾淨
    - **選擇多**：JPA 快速開發、JdbcTemplate 精細控制，可以在同一專案混用
    - **統一例外**：各家資料庫錯誤轉成 `DataAccessException` 體系

=== "缺點"

    - **交易邊界看不見**：代理機制導致自我呼叫、非 public 方法等陷阱
    - **JPA 學習曲線**：持久化上下文、髒檢查、延遲載入，不理解就容易出現效能問題
