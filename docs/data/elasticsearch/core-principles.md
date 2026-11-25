# 核心原理

## 倒排索引（Inverted Index）⭐ 最重要

```
傳統資料庫的查詢方式（正向索引）：
  SELECT * FROM articles WHERE content LIKE '%Java%'
  → 逐行掃描所有文章，找包含 "Java" 的行
  → 全表掃描，極慢！

Elasticsearch 的倒排索引：
  先對文字進行分詞（Tokenization）
  再建立「詞 → 文件列表」的映射

範例文件：
  Doc 1: "Java 是一門優秀的程式語言"
  Doc 2: "Python 和 Java 都很流行"
  Doc 3: "Java 的 JVM 非常強大"

分詞後：
  Doc 1 → [Java, 優秀, 程式, 語言]
  Doc 2 → [Python, Java, 流行]
  Doc 3 → [Java, JVM, 強大]

倒排索引（Term → 文件 + 位置）：
  ┌──────────┬────────────────────────────────┐
  │  Term    │  Posting List（文件 ID + 頻率）  │
  ├──────────┼────────────────────────────────┤
  │  Java    │  Doc1(1), Doc2(1), Doc3(1)     │
  │  優秀    │  Doc1(1)                        │
  │  程式    │  Doc1(1)                        │
  │  語言    │  Doc1(1)                        │
  │  Python  │  Doc2(1)                        │
  │  流行    │  Doc2(1)                        │
  │  JVM     │  Doc3(1)                        │
  │  強大    │  Doc3(1)                        │
  └──────────┴────────────────────────────────┘

搜索 "Java"：
  直接查倒排索引 → Doc1, Doc2, Doc3 → 毫秒級！
  不需要掃描任何文件內容！

相關性評分（BM25 算法）：
  TF（Term Frequency）：詞在文件中出現的頻率（越高越相關）
  IDF（Inverse Document Frequency）：詞在所有文件中的稀有度（越稀有越重要）
  "Java" 在每篇文章都有 → IDF 較低
  "JVM"  只在 Doc3 有   → IDF 較高
  搜索 "JVM"，Doc3 分數最高！
```

## 分散式架構

```
Elasticsearch 集群架構：

┌─────────────────────────────────────────────────────────┐
│                      ES Cluster                          │
│                                                         │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────┐  │
│  │   Node 1       │  │   Node 2       │  │  Node 3   │  │
│  │  (Master)      │  │  (Data)        │  │  (Data)   │  │
│  │                │  │                │  │           │  │
│  │  Shard 0 (主)  │  │  Shard 1 (主)  │  │ Shard 2(主)│ │
│  │  Shard 1 (副)  │  │  Shard 2 (副)  │  │ Shard 0(副)│ │
│  │  Shard 2 (副)  │  │  Shard 0 (副)  │  │ Shard 1(副)│ │
│  └────────────────┘  └────────────────┘  └───────────┘  │
└─────────────────────────────────────────────────────────┘

核心概念：
  Cluster（集群）：多個 Node 組成，對外是一個整體
  Node（節點）：集群中的一台服務器
    Master Node：管理集群狀態（Index 的創建/刪除、Node 的加入/離開）
    Data Node：儲存數據、執行查詢
    Coordinating Node：接收請求，分發到各 Data Node，聚合結果

  Index（索引）：類比 MySQL 的「表」
  Document（文件）：類比 MySQL 的「行」，JSON 格式
  Field（欄位）：類比 MySQL 的「列」

  Shard（分片）：Index 被切成多個 Shard，分散到不同 Node
    主分片（Primary Shard）：接收寫入請求
    副本分片（Replica Shard）：主分片的備份，可以承接讀請求

分片數設定（重要！）：
  ⚠️ 主分片數在建立 Index 時確定，之後不能修改！
  一般規則：每個分片大小控制在 10GB~50GB
  3 個 Node → 3 個主分片（每個 Node 一個）

容錯性：
  Node 1 宕機 → Shard 0 的副本（在 Node 3）自動升為主分片
  集群繼續正常運行！
```

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
