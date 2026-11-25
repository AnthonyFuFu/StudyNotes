# SQL 執行計劃分析

!!! abstract "本章重點"

    查詢變慢時，第一步永遠是看執行計劃。本章逐一解讀 EXPLAIN 的每個欄位（特別是 `type`、`key`、`rows`、`Extra`），說明如何開啟慢查詢日誌，並整理常見的慢查詢優化案例。

## EXPLAIN 詳解

```sql
EXPLAIN SELECT u.name, o.amount
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.status = 'ACTIVE'
  AND o.amount > 100
ORDER BY o.created_at DESC
LIMIT 10;
```

**EXPLAIN 輸出範例**

| id | select_type | table | type | possible_keys | key | key_len | rows | filtered | Extra |
|----|-------------|-------|------|---------------|-----|---------|------|----------|-------|
| 1 | SIMPLE | u | `ref` | status_idx | status_idx | 62 | 500 | 100% | Using where |
| 1 | SIMPLE | o | `ref` | user_id_idx | user_id_idx | 8 | 10 | 33% | Using index condition |

### type 欄位（效能由好到差）：

system  > const > eq_ref > ref > range > index > ALL

system：表中只有一行

const： 主鍵或唯一索引等值查詢（最多一行）

- WHERE id = 1

eq_ref：JOIN 時，被驅動表用主鍵/唯一索引等值查詢

- JOIN users u ON o.user_id = u.id

ref：   非唯一索引等值查詢（可能多行）

- WHERE status = 'ACTIVE'

range： 索引範圍查詢

- WHERE age BETWEEN 20 AND 30
- WHERE id IN (1,2,3)

index： 全索引掃描（比 ALL 好，因為索引比表小）

- 只查詢索引中的欄位

ALL：   全表掃描 ← 最差！必須優化！

- 沒有使用任何索引

### Extra 欄位常見值：

| Extra 值 | 意義 |
|------|------|
| Using index | ✅ 覆蓋索引，不需要回表 |
| Using where | Server 層過濾，索引不能完全過濾 |
| Using index condition | ✅ 索引下推（ICP） |
| Using filesort | ⚠️ 需要額外排序（沒有用到索引排序） |
| Using temporary | ⚠️ 使用臨時表（GROUP BY / DISTINCT 效能差） |
| Using join buffer | ⚠️ JOIN 沒有用到索引 |

## 慢查詢日誌

```sql
-- 開啟慢查詢日誌
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 1;        -- 超過 1 秒的 SQL 記錄
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';

-- 也記錄沒有用到索引的查詢
SET GLOBAL log_queries_not_using_indexes = ON;

-- 查看慢查詢日誌
# Time: 2024-01-01T10:00:00
# Query_time: 3.456  Lock_time: 0.001  Rows_sent: 100  Rows_examined: 5000000
SELECT * FROM orders WHERE status = 'PAID' ORDER BY created_at DESC LIMIT 100;

-- 分析工具：mysqldumpslow
mysqldumpslow -s t -t 10 /var/log/mysql/slow.log
# -s t：按查詢時間排序
# -t 10：顯示前 10 條

-- 更強大的工具：pt-query-digest
pt-query-digest /var/log/mysql/slow.log
```

## 常見慢查詢優化案例

```sql
-- ❌ 案例1：對索引欄位做函數操作（索引失效！）
SELECT * FROM orders WHERE YEAR(created_at) = 2024;

-- ✅ 優化：改寫為範圍查詢
SELECT * FROM orders
WHERE created_at >= '2024-01-01'
  AND created_at < '2025-01-01';

---

-- ❌ 案例2：隱式類型轉換（索引失效！）
-- user_id 欄位是 VARCHAR，但傳入整數
SELECT * FROM users WHERE user_id = 123;
-- MySQL 自動轉換：CAST(user_id AS INT) = 123 → 全表掃描！

-- ✅ 優化：類型要一致
SELECT * FROM users WHERE user_id = '123';

---

-- ❌ 案例3：OR 條件（可能索引失效）
SELECT * FROM users WHERE name = 'John' OR email = 'john@example.com';
-- name 和 email 分別有索引，但 OR 可能導致全表掃描

-- ✅ 優化：改用 UNION
SELECT * FROM users WHERE name = 'John'
UNION
SELECT * FROM users WHERE email = 'john@example.com';

---

-- ❌ 案例4：SELECT *（查詢不需要的欄位）
SELECT * FROM orders WHERE user_id = 1;

-- ✅ 優化：只查需要的欄位（可以利用覆蓋索引）
SELECT id, amount, status FROM orders WHERE user_id = 1;

---

-- ❌ 案例5：JOIN 過多或缺少索引
SELECT * FROM orders o
JOIN users u ON o.user_id = u.id  -- u.id 有主鍵索引 ✅
JOIN products p ON o.product_id = p.id  -- p.id 有主鍵索引 ✅
JOIN categories c ON p.category_id = c.id;  -- category_id 沒有索引！❌

-- ✅ 優化：為 JOIN 欄位建立索引
ALTER TABLE products ADD INDEX idx_category_id (category_id);

---

-- ❌ 案例6：深度分頁（OFFSET 很大）
SELECT * FROM orders LIMIT 1000000, 10;  -- 掃描 100萬行！

-- ✅ 優化：遊標分頁
SELECT * FROM orders WHERE id > :lastId ORDER BY id LIMIT 10;
```
