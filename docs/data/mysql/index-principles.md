# 索引原理

!!! abstract "本章重點"

    索引是 MySQL 效能最關鍵的一環。本章從 B+ 樹的結構說明為什麼千萬筆資料只需要 3 次磁碟 IO，再介紹聚簇與非聚簇索引、回表、最左前綴原則、覆蓋索引與索引下推。

## B+樹索引結構

**為什麼用 B+樹而不是其他結構？**

| 結構 | 問題 |
|------|------|
| 二元搜尋樹（BST） | 最壞退化成鏈表 O(n) |
| 紅黑樹 | 樹高大，磁碟 IO 多 |
| Hash | 無法範圍查詢 |
| B 樹 | 非葉節點也存數據，葉節點之間無連接 |
| **B+樹** | ✅ 最適合資料庫 |

**B+樹特點**

- ✅ 所有數據存在葉節點（非葉節點只存索引鍵）
- ✅ 葉節點用雙向鏈表串連（支援範圍查詢）
- ✅ 樹高低（通常 3\~4 層），磁碟 IO 少
- ✅ 非葉節點可以存更多鍵（磁碟頁空間利用率高）

**B+樹結構示意**

``` mermaid
block-beta
    columns 6
    space:2 r["30"]:2 space:2
    space:6
    i1["10 ｜ 20"]:3 i2["40 ｜ 50"]:3
    space:6
    l1["1"] l2["10"] l3["20"] l4["30"] l5["40"] l6["50"]
    r --> i1
    r --> i2
    i1 --> l1
    i1 --> l2
    i1 --> l3
    i2 --> l4
    i2 --> l5
    i2 --> l6
    classDef leaf stroke-width:2px
    class l1,l2,l3,l4,l5,l6 leaf
```

最下層為葉節點：存完整行資料或主鍵，並以雙向鏈表串連，支援範圍查詢。

!!! info "樹高 3 層能存多少行？"

    InnoDB 頁大小預設 16KB。假設主鍵 8 bytes、指針 6 bytes，每條 14 bytes：

    - 一個非葉節點能存：16KB / 14 ≈ **1170 個鍵**
    - 3 層能存：1170 × 1170 × 16（每葉節點約 16 條）≈ **2000 萬行**

    千萬行資料，查詢只需 3 次磁碟 IO。

## 聚簇索引 vs 非聚簇索引

=== "聚簇索引（Clustered Index）"

    InnoDB 的主鍵索引，**葉節點直接存完整行資料**，每張表只能有一個。主鍵查詢直接在 B+樹找到葉節點並取出完整數據，最快。

    **主鍵選擇原則**

    - ✅ 使用自增整數（`INT` / `BIGINT AUTO_INCREMENT`）
    - ✅ 避免使用 UUID（隨機性導致頻繁頁分裂，性能差）
    - ✅ 越短越好（影響非聚簇索引的大小）

=== "非聚簇索引（Secondary Index）"

    又稱二級索引，**葉節點存的是「主鍵值」**，不是完整行資料。非主鍵查詢需要先查二級索引、再回聚簇索引取資料，這個過程叫「回表」。

**回表（Table Lookup）**

``` sql
SELECT * FROM users WHERE name = 'John';
```

``` mermaid
flowchart LR
    Q(["WHERE name = 'John'"]) --> S["① name 二級索引<br>找到主鍵 id = 5"]
    S --> C["② 聚簇索引<br>用 id = 5 查完整行資料"]
    C --> R(["返回結果"])
```

兩次 B+樹查詢。要避免回表，可以使用覆蓋索引（見下方）。

## 聯合索引與最左前綴原則

```java
// 建立聯合索引
CREATE INDEX idx_name_age_city ON users(name, age, city);

// B+樹排序方式：先按 name，name 相同按 age，age 相同按 city

// ✅ 可以使用索引：
SELECT * FROM users WHERE name = 'John';                        // 用 name
SELECT * FROM users WHERE name = 'John' AND age = 25;          // 用 name + age
SELECT * FROM users WHERE name = 'John' AND age = 25 AND city = 'Taipei'; // 全用

// ✅ 範圍查詢（最左前綴必須是等值）：
SELECT * FROM users WHERE name = 'John' AND age > 20;          // name 等值 + age 範圍

// ❌ 無法使用索引（跳過了最左列）：
SELECT * FROM users WHERE age = 25;                            // 跳過 name
SELECT * FROM users WHERE city = 'Taipei';                     // 跳過 name, age

// ❌ 範圍查詢後的列無法用索引：
SELECT * FROM users WHERE name = 'John' AND age > 20 AND city = 'Taipei';
// city 索引失效！（age 已是範圍查詢）

// ✅ 最佳實踐：選擇性高的列放前面
// 選擇性 = 不重複值數量 / 總行數
// gender（男/女）選擇性低 → 放後面
// name（很多不同名字）選擇性高 → 放前面
```

## 覆蓋索引（Covering Index）

```java
// 覆蓋索引：查詢所需的所有欄位都在索引中，不需要回表！

// 建立索引
CREATE INDEX idx_name_age ON users(name, age);

// ✅ 覆蓋索引（只查 name 和 age，都在索引中）
SELECT name, age FROM users WHERE name = 'John';
// EXPLAIN 中 Extra 欄位顯示：Using index ← 覆蓋索引！

// ❌ 需要回表（查了 email，不在索引中）
SELECT name, age, email FROM users WHERE name = 'John';

// ✅ 實際應用：分頁優化
// ❌ 深度分頁（OFFSET 很大時極慢）
SELECT * FROM orders ORDER BY created_at LIMIT 1000000, 10;
// 需要掃描 1000010 行，然後丟棄前 1000000 行！

// ✅ 覆蓋索引 + 延遲關聯
SELECT * FROM orders o
JOIN (
    SELECT id FROM orders ORDER BY created_at LIMIT 1000000, 10
) t ON o.id = t.id;
// 先用覆蓋索引只取主鍵（快），再 JOIN 取完整資料

// ✅ 更好的方案：遊標分頁（記錄上一頁最後一個 ID）
SELECT * FROM orders
WHERE id > 最後一個id
ORDER BY id
LIMIT 10;
```

## 索引下推（Index Condition Pushdown，ICP）

索引下推（Index Condition Pushdown，MySQL 5.6+）把部分 WHERE 條件交給儲存引擎在索引層過濾。

``` sql
CREATE INDEX idx_name_age ON users(name, age);

SELECT * FROM users WHERE name LIKE 'J%' AND age = 25;
```

=== "無 ICP"

    ``` mermaid
    flowchart LR
        A["儲存引擎<br>找出所有 name LIKE 'J%'"] --> B["全部回表<br>（可能很多行）"] --> C["Server 層<br>過濾 age = 25"]
    ```

=== "有 ICP"

    ``` mermaid
    flowchart LR
        A["儲存引擎<br>找出 name LIKE 'J%'"] --> B["索引層直接過濾<br>age = 25"] --> C["只有符合的才回表"]
    ```

大幅減少回表次數。`EXPLAIN` 的 Extra 顯示 `Using index condition`，代表使用了 ICP。
