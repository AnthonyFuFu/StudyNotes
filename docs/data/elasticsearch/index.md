---
icon: lucide/search
---

# Elasticsearch

從倒排索引與分詞原理出發，掌握 DSL 查詢、Spring Boot 整合與生產環境調優。

**核心技術**：倒排索引 / DSL 查詢 / 聚合 / ELK Stack

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Elasticsearch"])
    c0["01 · 核心原理"]
    R --> c0
    p0("・倒排索引（Inverted Index）<br>・分散式架構（Cluster / Node / Shard）<br>・文件讀寫流程")
    c0 --- p0
    c1["02 · 資料模型"]
    R --> c1
    p1("・Index / Document / Field<br>・Mapping（欄位類型定義）<br>・分析器（Analyzer）")
    c1 --- p1
    c2["03 · DSL 查詢語法"]
    R --> c2
    p2("・全文查詢（match / multi_match）<br>・精確查詢（term / terms / range）<br>・複合查詢（bool）<br>・聚合查詢（aggregation）<br>・高亮 / 排序 / 分頁")
    c2 --- p2
    c3["04 · Spring Boot 整合"]
    R --> c3
    p3("・Spring Data Elasticsearch<br>・ElasticsearchRestTemplate<br>・完整電商搜索實戰")
    c3 --- p3
    c4["05 · 生產實戰"]
    R --> c4
    p4("・效能調優<br>・索引設計最佳實踐<br>・ELK Stack 日誌系統")
    c4 --- p4
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4 chapter
    class p0,p1,p2,p3,p4 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 核心原理](core-principles.md)__

    ---

    倒排索引（Inverted Index）⭐ 最重要 · 分散式架構 · 文件寫入流程

-   __[02 · 資料模型](data-model.md)__

    ---

    Mapping · 分析器

-   __[03 · DSL 查詢語法](dsl-query.md)__

    ---

    全文查詢 · 精確查詢 · 複合查詢（Bool Query）⭐ 最重要 · 聚合查詢 · 巢狀查詢

-   __[04 · Spring Boot 整合](spring-boot.md)__

    ---

    Spring Data Elasticsearch 整合 · DB 與 ES 數據同步方案

-   __[05 · 生產實戰](production.md)__

    ---

    索引設計最佳實踐 · 效能調優 · ELK Stack 日誌系統建置

</div>

## 重點速覽

### 倒排索引原理

```
文件內容 → 分詞 → 建立倒排索引

詞（Term） → 文件列表（Posting List）
"Java"     → [Doc1, Doc2, Doc3]
"Spring"   → [Doc1, Doc3]

搜索 "Java" → 直接查倒排索引 → 毫秒級返回
（無需掃描任何文件內容！）

相關性評分（BM25）：
  TF（詞頻）× IDF（稀有度）→ 越稀有的詞越重要
```

### DSL 查詢核心

```json
{
  "query": {
    "bool": {
      "must":     [{ "multi_match": { "query": "iPhone", "fields": ["name^3", "description"] }}],
      "filter":   [{ "term": { "category": "手機" }},
                   { "range": { "price": { "gte": 1000, "lte": 10000 }}}],
      "must_not": [{ "term": { "status": "OFFLINE" }}]
    }
  },
  "sort":      [{ "_score": "desc" }, { "rating": "desc" }],
  "highlight": { "fields": { "name": {}}},
  "aggs":      { "by_brand": { "terms": { "field": "brand" }}}
}
```

!!! info

    **must**：影響相關性分數 | **filter**：不影響分數，有緩存，效能最好

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **倒排索引** | 詞 → 文件列表，O(1) 查詢，BM25 相關性評分 |
| **分散式架構** | Cluster/Node/Shard，主副本，自動容錯 |
| **Mapping** | text（分詞）/ keyword（不分詞），設計好不能輕易修改 |
| **分析器** | ik_max_word（索引時）/ ik_smart（搜索時）|
| **match** | 全文搜索，分詞後匹配，影響相關性分數 |
| **term** | 精確匹配，不分詞，用於 keyword 欄位 |
| **bool query** | must / should / must_not / filter 四個子句 |
| **filter** | 不影響分數，有緩存，效能最好，放過濾條件 |
| **聚合** | terms / range / histogram，用於統計和篩選面板 |
| **數據同步** | Canal + MQ 監聽 Binlog，最終一致性 |
| **分頁** | 深度分頁用 search_after，避免 from > 10000 |
| **批量寫入** | Bulk API，每批 1000 條，暫時關閉副本和 refresh |
| **ILM** | Hot → Warm → Cold → Delete，自動管理日誌索引 |
