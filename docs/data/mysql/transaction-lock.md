# 事務與鎖

## 事務隔離級別

```
SQL 標準定義的四種隔離級別（由低到高）：

隔離級別              臟讀   不可重複讀   幻讀
────────────────────────────────────────────────
READ UNCOMMITTED      ✅     ✅          ✅
READ COMMITTED        ❌     ✅          ✅
REPEATABLE READ（預設）❌     ❌          ✅（InnoDB 用 Gap Lock 解決）
SERIALIZABLE          ❌     ❌          ❌

問題定義：
  臟讀（Dirty Read）：
    讀到其他事務未提交的修改
    事務 A 修改了一行但未提交 → 事務 B 讀到了 → A 回滾 → B 讀到的是無效數據！

  不可重複讀（Non-Repeatable Read）：
    同一事務中，兩次讀取同一行，結果不同
    事務 A 讀取 name='John' → 事務 B 修改 name='Jane' 並提交 → 事務 A 再讀取 → 'Jane'

  幻讀（Phantom Read）：
    同一事務中，兩次查詢返回的行數不同
    事務 A 查詢 age>20 的用戶有 5 個 → 事務 B 插入一個 age=25 的用戶 → 事務 A 再查詢 → 6 個！

MySQL 預設隔離級別：REPEATABLE READ
```

```sql
-- 查看隔離級別
SELECT @@transaction_isolation;

-- 設定隔離級別
SET SESSION transaction_isolation = 'READ-COMMITTED';
```

## MVCC（Multi-Version Concurrency Control）

MVCC 是 InnoDB 實現高並發的核心機制。**核心思想**：讀不加鎖，寫不阻塞讀；通過保存數據的多個版本，讓讀操作看到歷史版本。

**InnoDB 每行數據的隱藏欄位**

| row_id（可選） | trx_id | roll_pointer | 數據 |
|---------------|--------|--------------|------|
| 隱藏主鍵 | 最後修改此行的事務 ID | 指向 Undo Log | 實際欄位值 |

**Undo Log 版本鏈**：保存行的歷史版本。

``` mermaid
flowchart LR
    V3["當前版本<br>name='Jane'<br>trx_id=100"] -- roll_pointer --> V2["歷史版本<br>name='John'<br>trx_id=50"] -- roll_pointer --> V1["更早版本<br>name='Joe'<br>trx_id=10"]
```

**ReadView（一致性視圖）**：事務建立快照時記錄

| 欄位 | 意義 |
|------|------|
| `m_ids` | 當前活躍（未提交）的事務 ID 列表 |
| `min_trx_id` | 活躍事務的最小 ID |
| `max_trx_id` | 下一個事務的 ID（尚未分配） |
| `creator_trx_id` | 當前事務的 ID |

**版本可見性判斷**

依序檢查行記錄的 `trx_id`：

| 順序 | 條件 | 結果 |
|------|------|------|
| 1 | `trx_id == creator_trx_id` | ✅ 可見（自己修改的） |
| 2 | `trx_id < min_trx_id` | ✅ 可見（ReadView 建立前已提交） |
| 3 | `trx_id >= max_trx_id` | ❌ 不可見（ReadView 建立後才開始的事務） |
| 4 | `min_trx_id <= trx_id < max_trx_id` 且在 `m_ids` 中 | ❌ 不可見（尚未提交） |
| 5 | `min_trx_id <= trx_id < max_trx_id` 且不在 `m_ids` 中 | ✅ 可見（已提交） |

不可見時，沿著 `roll_pointer` 找 Undo Log 中的上一個版本，再重新判斷，直到找到可見的版本。

| 隔離級別 | ReadView 建立時機 | 效果 |
|---------|-----------------|------|
| **REPEATABLE READ** | 事務開始時建立，整個事務共用同一個 | 同一事務兩次讀取結果相同 |
| **READ COMMITTED** | 每次 SELECT 都建立新的 | 可以讀到其他事務已提交的修改（不可重複讀） |

## 鎖機制

### 表鎖 vs 行鎖：

```
表鎖（Table Lock）：
  鎖定整張表，粒度大，並發低
  MyISAM 使用表鎖
  InnoDB 的 LOCK TABLES 命令

行鎖（Row Lock）：
  InnoDB 預設，鎖定具體的行，並發高
  只有使用到索引才能用行鎖！
  沒有索引 → 升級為表鎖！❌

⚠️ 重要：InnoDB 行鎖是加在索引上的，不是行本身！
```

### 三種行鎖：

```
Record Lock（記錄鎖）：
  鎖定一條具體的索引記錄
  WHERE id = 5 → 鎖定 id=5 這條記錄

Gap Lock（間隙鎖）：
  鎖定索引記錄之間的間隙（不包含記錄本身）
  WHERE id BETWEEN 5 AND 10 → 鎖定 (5, 10) 之間的空隙
  防止其他事務在這個間隙插入新行！→ 解決幻讀！

Next-Key Lock（臨鍵鎖）：
  = Record Lock + Gap Lock
  鎖定一條記錄及其之前的間隙
  InnoDB 預設使用 Next-Key Lock
  WHERE id = 5 → 鎖定 (-∞, 5] 的 Next-Key Lock
```

```sql
-- 死鎖範例：
-- 事務 A                    事務 B
BEGIN;                       BEGIN;
UPDATE orders SET status='PAID' WHERE id=1;   -- 鎖定 id=1
                             UPDATE orders SET status='PAID' WHERE id=2;   -- 鎖定 id=2
UPDATE orders SET status='SHIPPED' WHERE id=2; -- 等待 id=2（被 B 鎖住）
                             UPDATE orders SET status='SHIPPED' WHERE id=1; -- 等待 id=1（被 A 鎖住）
-- 死鎖！MySQL 自動選一個事務回滾

-- 避免死鎖的方法：
-- 1. 固定加鎖順序（總是先鎖 id=1 再鎖 id=2）
-- 2. 縮短事務持有鎖的時間
-- 3. 使用 SELECT ... FOR UPDATE 在事務開始時就鎖定

-- 查看死鎖信息
SHOW ENGINE INNODB STATUS;
```

## 樂觀鎖 vs 悲觀鎖

```java
// 悲觀鎖：假設一定會衝突，先鎖住再操作
@Transactional
public void deductStock(Long productId, Integer quantity) {
    // SELECT ... FOR UPDATE（排他鎖，阻塞其他讀寫）
    Product product = productMapper.selectByIdForUpdate(productId);
    if (product.getStock() < quantity) {
        throw new InsufficientStockException();
    }
    productMapper.deductStock(productId, quantity);
}
// Mapper.xml：SELECT * FROM products WHERE id=#{id} FOR UPDATE

// 樂觀鎖：假設不會衝突，提交時檢查（版本號/CAS）
// 表中加 version 欄位
@Transactional
public boolean deductStock(Long productId, Integer quantity, Integer version) {
    int rows = productMapper.deductStockWithVersion(
        productId, quantity, version
    );
    if (rows == 0) {
        // 版本不匹配（被其他事務修改了）→ 重試
        return false;
    }
    return true;
}
// SQL：UPDATE products
//      SET stock = stock - #{quantity}, version = version + 1
//      WHERE id = #{id} AND version = #{version} AND stock >= #{quantity}

// 什麼時候用哪個？
// 悲觀鎖：衝突頻繁、不能接受重試（如秒殺扣庫存）
// 樂觀鎖：衝突少、可以接受重試（如一般訂單更新）
```
