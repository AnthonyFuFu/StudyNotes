---
icon: lucide/database
---

# MySQL 深度優化

索引原理、執行計劃、事務與鎖、主從複製到分庫分表，建立完整的 MySQL 調優思路。

**核心技術**：B+樹索引 / MVCC / 主從複製 / 分庫分表 / 雪花算法

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["MySQL 深度優化"])
    c0["01 · 索引原理"]
    R --> c0
    p0("・B+樹索引結構<br>・聚簇索引 vs 非聚簇索引<br>・聯合索引與最左前綴原則<br>・覆蓋索引、索引下推")
    c0 --- p0
    c1["02 · SQL 執行計劃分析"]
    R --> c1
    p1("・EXPLAIN 詳解<br>・慢查詢日誌<br>・常見慢查詢優化")
    c1 --- p1
    c2["03 · 事務與鎖"]
    R --> c2
    p2("・ACID 原理<br>・事務隔離級別<br>・MVCC 多版本並發控制<br>・鎖機制（表鎖、行鎖、間隙鎖）")
    c2 --- p2
    c3["04 · 主從複製與讀寫分離"]
    R --> c3
    p3("・Binlog 複製原理<br>・主從配置<br>・讀寫分離實作")
    c3 --- p3
    c4["05 · 分庫分表"]
    R --> c4
    p4("・垂直切分 vs 水平切分<br>・ShardingSphere 實戰<br>・分散式主鍵生成")
    c4 --- p4
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4 chapter
    class p0,p1,p2,p3,p4 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 索引原理](index-principles.md)__

    ---

    B+樹索引結構 · 聚簇索引 vs 非聚簇索引 · 聯合索引與最左前綴原則 · 覆蓋索引 · 索引下推

-   __[02 · SQL 執行計劃分析](explain.md)__

    ---

    EXPLAIN 詳解 · 慢查詢日誌 · 常見慢查詢優化案例

-   __[03 · 事務與鎖](transaction-lock.md)__

    ---

    事務隔離級別 · MVCC · 鎖機制 · 樂觀鎖 vs 悲觀鎖

-   __[04 · 主從複製與讀寫分離](replication.md)__

    ---

    Binlog 複製原理 · 讀寫分離實作

-   __[05 · 分庫分表](sharding.md)__

    ---

    什麼時候需要分庫分表？ · ShardingSphere 實戰 · 分散式主鍵生成

-   __[06 · 調優檢查清單](checklist.md)__

    ---

    MySQL 調優檢查清單

</div>

## 重點速覽

### 索引核心原理

```
B+樹特性：
  ✅ 所有數據存在葉節點，雙向鏈表串連（支援範圍查詢）
  ✅ 樹高 3~4 層，千萬級數據只需 3 次磁碟 IO
  ✅ 非葉節點只存索引鍵（可存更多鍵，降低樹高）

索引類型：
  聚簇索引（Clustered）  → 主鍵，葉節點存完整行資料
  非聚簇索引（Secondary）→ 葉節點存主鍵值，需回表
  覆蓋索引（Covering）  → 所需欄位都在索引中，不需回表 ✅
```

### 執行計劃 EXPLAIN 速查

| type | 說明 | 效能 |
|------|------|------|
| `system` / `const` | 主鍵/唯一索引等值查詢 | ⭐⭐⭐⭐⭐ |
| `eq_ref` | JOIN 時被驅動表用主鍵 | ⭐⭐⭐⭐⭐ |
| `ref` | 非唯一索引等值查詢 | ⭐⭐⭐⭐ |
| `range` | 索引範圍查詢 | ⭐⭐⭐ |
| `index` | 全索引掃描 | ⭐⭐ |
| `ALL` | 全表掃描 🚨 | ⭐ |

### MVCC 與事務隔離

| 隔離級別 | 臟讀 | 不可重複讀 | 幻讀 |
|---------|------|----------|------|
| READ UNCOMMITTED | ✅ | ✅ | ✅ |
| READ COMMITTED | ❌ | ✅ | ✅ |
| **REPEATABLE READ（預設）** | ❌ | ❌ | ⚠️（Gap Lock 解決）|
| SERIALIZABLE | ❌ | ❌ | ❌ |

!!! info

    MVCC 核心：每行隱藏 `trx_id` + `roll_pointer`，通過 ReadView 判斷可見版本，讀不加鎖實現高並發

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **B+樹** | 葉節點存數據，雙向鏈表，3\~4 層可存千萬行 |
| **聚簇索引** | 主鍵即索引，葉節點存完整行，用自增整數 |
| **回表** | 二級索引查到主鍵，再去聚簇索引取完整行 |
| **覆蓋索引** | 所需欄位都在索引中，避免回表，Extra=Using index |
| **最左前綴** | 聯合索引從最左列開始匹配，範圍查詢後的列失效 |
| **EXPLAIN** | type=ALL 必須優化，Extra=Using filesort 要關注 |
| **MVCC** | 多版本並發控制，ReadView + Undo Log，讀不加鎖 |
| **間隙鎖** | 防止幻讀，鎖定索引間隙，REPEATABLE READ 預設開啟 |
| **主從複製** | Binlog → Relay Log → SQL Thread 重放，注意主從延遲 |
| **雪花算法** | 64位趨勢遞增ID，時間戳+機器ID+序列號 |
