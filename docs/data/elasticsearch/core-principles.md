# 核心原理

## 倒排索引（Inverted Index）⭐ 最重要

=== "傳統資料庫（正向索引）"

    ``` sql
    SELECT * FROM articles WHERE content LIKE '%Java%'
    ```

    逐行掃描所有文章，找包含 "Java" 的行：**全表掃描，極慢**。

=== "Elasticsearch（倒排索引）"

    先對文字進行分詞（Tokenization），再建立「詞 → 文件列表」的映射。

``` mermaid
flowchart LR
    subgraph DOCS ["範例文件"]
        direction TB
        D1["Doc 1：Java 是一門優秀的程式語言"]
        D2["Doc 2：Python 和 Java 都很流行"]
        D3["Doc 3：Java 的 JVM 非常強大"]
    end
    subgraph TOK ["分詞後"]
        direction TB
        T1["Java ・ 優秀 ・ 程式 ・ 語言"]
        T2["Python ・ Java ・ 流行"]
        T3["Java ・ JVM ・ 強大"]
    end
    D1 --> T1
    D2 --> T2
    D3 --> T3
    TOK --> IDX[("倒排索引<br>Term → Posting List")]
```

| Term | Posting List（文件 ID + 頻率） |
|------|------------------------------|
| **Java** | Doc1(1), Doc2(1), Doc3(1) |
| 優秀 | Doc1(1) |
| 程式 | Doc1(1) |
| 語言 | Doc1(1) |
| Python | Doc2(1) |
| 流行 | Doc2(1) |
| **JVM** | Doc3(1) |
| 強大 | Doc3(1) |

搜索 "Java"：直接查倒排索引 → Doc1, Doc2, Doc3，**毫秒級**，不需要掃描任何文件內容。

!!! info "相關性評分（BM25 算法）"

    - **TF（Term Frequency）**：詞在文件中出現的頻率，越高越相關
    - **IDF（Inverse Document Frequency）**：詞在所有文件中的稀有度，越稀有越重要

    "Java" 在每篇文章都有 → IDF 較低；"JVM" 只在 Doc3 有 → IDF 較高。所以搜索 "JVM" 時，Doc3 分數最高。

## 分散式架構

``` mermaid
block-beta
    columns 3
    block:n1
        columns 1
        t1["Node 1（Master）"]
        a0["Shard 0 主"] a1["Shard 1 副"] a2["Shard 2 副"]
    end
    block:n2
        columns 1
        t2["Node 2（Data）"]
        b1["Shard 1 主"] b2["Shard 2 副"] b0["Shard 0 副"]
    end
    block:n3
        columns 1
        t3["Node 3（Data）"]
        c2["Shard 2 主"] c0["Shard 0 副"] c1["Shard 1 副"]
    end
    classDef title fill:transparent,stroke:transparent,font-weight:bold
    classDef primary stroke-width:3px
    class t1,t2,t3 title
    class a0,b1,c2 primary
    style n1 fill:transparent
    style n2 fill:transparent
    style n3 fill:transparent
```

粗框為主分片（Primary），其餘為副本分片（Replica）。每個主分片的副本都放在其他節點上。

**核心概念**

| 概念 | 說明 | 類比 MySQL |
|------|------|-----------|
| **Cluster**（集群） | 多個 Node 組成，對外是一個整體 | |
| **Node**（節點） | 集群中的一台服務器 | |
| **Index**（索引） | 文件的集合 | 表 |
| **Document**（文件） | JSON 格式的一筆資料 | 行 |
| **Field**（欄位） | 文件中的屬性 | 列 |
| **Shard**（分片） | Index 被切成多個 Shard，分散到不同 Node | |

**節點角色**

- **Master Node**：管理集群狀態（Index 的創建 / 刪除、Node 的加入 / 離開）
- **Data Node**：儲存數據、執行查詢
- **Coordinating Node**：接收請求，分發到各 Data Node，聚合結果

**分片類型**

- **主分片（Primary Shard）**：接收寫入請求
- **副本分片（Replica Shard）**：主分片的備份，可以承接讀請求

!!! warning "分片數設定"

    主分片數在建立 Index 時確定，**之後不能修改**。一般規則：每個分片大小控制在 10GB \~ 50GB；3 個 Node → 3 個主分片（每個 Node 一個）。

!!! success "容錯性"

    Node 1 宕機時，Shard 0 的副本（在 Node 3）會自動升為主分片，集群繼續正常運行。

## 文件寫入流程

```
寫入流程（PUT /index/_doc/1）：

① 請求到達任意 Node（協調節點）
② 計算文件應該寫入哪個 Shard：
   shard = hash(document_id) % primary_shard_count
③ 協調節點將請求轉發到對應的主分片所在的 Node
④ 主分片寫入數據
⑤ 並行複製到所有副本分片
⑥ 所有副本確認寫入成功後，返回客戶端成功

寫入過程（主分片）：
  ① 寫入 Memory Buffer（記憶體緩衝）
  ② 每 1 秒 Refresh 一次（將 Buffer 寫入 Segment 文件）
     → 寫入後 1 秒內可以被搜索（準實時 Near Real-Time，NRT）
  ③ 每 30 分鐘或 Translog 過大 → Flush（Segment 落盤）
  ④ 定期 Merge（合併小 Segment 為大 Segment，提升查詢性能）

Translog（事務日誌）：
  每次寫入都會寫 Translog（WAL 機制，防止數據丟失）
  即使 Node 宕機，重啟後可以從 Translog 恢復
```
