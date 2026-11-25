# DSL 查詢語法

!!! abstract "本章重點"

    Elasticsearch 的查詢以 JSON 形式的 DSL 撰寫。本章依序介紹全文查詢、精確查詢、Bool 複合查詢、聚合與巢狀查詢，並說明 `must` 與 `filter` 在評分與快取上的差異。

## 全文查詢

```json
// 1. match 查詢（最常用，全文搜索）
GET /products/_search
{
  "query": {
    "match": {
      "name": {
        "query":    "蘋果 手機",
        "operator": "and"
      }
    }
  }
}
// operator: "or"（預設）→ 包含任一詞即可
// operator: "and"       → 必須同時包含所有詞

// 2. match_phrase 查詢（短語搜索，詞的順序要一致）
GET /products/_search
{
  "query": {
    "match_phrase": {
      "description": {
        "query": "超長續航",
        "slop":  2
      }
    }
  }
}
// slop: 允許詞之間的最大間隔（0 = 完全相鄰）

// 3. multi_match 查詢（同時搜索多個欄位）
GET /products/_search
{
  "query": {
    "multi_match": {
      "query":  "iPhone",
      "fields": ["name^3", "description^1", "category^2"],
      "type":   "best_fields"
    }
  }
}
// ^3 表示 name 欄位的權重是 description 的 3 倍
// type:
//   best_fields：取最高分的欄位（預設）
//   most_fields：多個欄位都匹配分數更高
//   cross_fields：跨欄位搜索（適合姓名分開存）
```

## 精確查詢

```json
// 1. term 查詢（精確匹配，不分詞）
GET /products/_search
{
  "query": {
    "term": {
      "category": {
        "value": "手機"
      }
    }
  }
}
// ⚠️ term 用於 keyword 欄位
// 不要用 term 查詢 text 欄位（因為 text 已被分詞，無法完全匹配）

// 2. terms 查詢（多值精確匹配，類似 SQL IN）
GET /products/_search
{
  "query": {
    "terms": {
      "category": ["手機", "平板", "電腦"]
    }
  }
}

// 3. range 查詢（範圍查詢）
GET /products/_search
{
  "query": {
    "range": {
      "price": {
        "gte": 1000,
        "lte": 5000
      }
    }
  }
}
// gte = greater than or equal（≥）
// lte = less than or equal（≤）
// gt  = greater than（>）
// lt  = less than（<）

// 日期範圍
GET /products/_search
{
  "query": {
    "range": {
      "created_at": {
        "gte": "now-7d/d",
        "lte": "now/d"
      }
    }
  }
}
// now-7d/d = 7天前（取整天）

// 4. exists 查詢（欄位是否存在）
GET /products/_search
{
  "query": {
    "exists": {
      "field": "discount_price"
    }
  }
}

// 5. wildcard 查詢（通配符）
GET /products/_search
{
  "query": {
    "wildcard": {
      "name.keyword": {
        "value": "iPhone*"
      }
    }
  }
}
// ⚠️ wildcard 效能差，避免在高基數欄位上使用
```

## 複合查詢（Bool Query）⭐ 最重要

```json
GET /products/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": { "name": "手機" }
        }
      ],
      "should": [
        { "term":  { "brand": "Apple" }},
        { "range": { "rating": { "gte": 4.5 }}}
      ],
      "must_not": [
        { "term": { "status": "OFFLINE" }}
      ],
      "filter": [
        { "range": { "price": { "gte": 1000, "lte": 10000 }}},
        { "term":  { "category": "手機" }}
      ],
      "minimum_should_match": 1
    }
  }
}
```

**bool 查詢四個子句**

**must（必須匹配）**

- ✅ 影響相關性分數（BM25）
- 條件必須全部滿足（類似 AND）

**should（應該匹配）**

- ✅ 影響相關性分數（滿足越多分越高）
- minimum_should_match：最少要滿足幾個 should

**must_not（必須不匹配）**

- ❌ 不影響相關性分數（只做過濾）
- 條件都不能滿足（類似 NOT）

**filter（過濾）**

- ❌ 不影響相關性分數（比 must 快！）
- 條件必須滿足
- ✅ 結果會被緩存（性能最好）
- → 適合：價格範圍、分類、狀態等不需要影響相關性的條件

**性能建議**

- ① 不需要影響排序的條件 → 放 filter（有緩存，不計算分數）
- ② 需要影響排序的條件 → 放 must / should
- ③ 排除條件 → 放 must_not

```json
// 實戰：電商商品搜索
// 搜索："藍牙耳機"，類別：電子產品，價格 500~2000，有庫存，按評分排序
GET /products/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "multi_match": {
            "query":  "藍牙耳機",
            "fields": ["name^3", "description"]
          }
        }
      ],
      "filter": [
        { "term":  { "category": "電子產品" }},
        { "range": { "price": { "gte": 500, "lte": 2000 }}},
        { "range": { "stock": { "gt": 0 }}}
      ]
    }
  },
  "sort": [
    { "_score":  { "order": "desc" }},
    { "rating":  { "order": "desc" }},
    { "sold_count": { "order": "desc" }}
  ],
  "from": 0,
  "size": 20,
  "highlight": {
    "fields": {
      "name":        { "number_of_fragments": 0 },
      "description": { "fragment_size": 150, "number_of_fragments": 3 }
    },
    "pre_tags":  ["<em>"],
    "post_tags": ["</em>"]
  },
  "_source": ["id", "name", "price", "rating", "images"]
}
```

## 聚合查詢（Aggregation）

```json
// 場景：商品搜索的左側篩選面板（品牌/分類/價格區間）

GET /products/_search
{
  "query": {
    "bool": {
      "must": [{ "match": { "name": "手機" }}]
    }
  },
  "size": 0,
  "aggs": {
    "category_count": {
      "terms": {
        "field": "category",
        "size":  10,
        "order": { "_count": "desc" }
      }
    },
    "brand_count": {
      "terms": {
        "field": "brand",
        "size":  20
      }
    },
    "price_ranges": {
      "range": {
        "field": "price",
        "ranges": [
          { "key": "0-1000",  "from": 0,    "to": 1000  },
          { "key": "1000-3000", "from": 1000, "to": 3000 },
          { "key": "3000-8000", "from": 3000, "to": 8000 },
          { "key": "8000以上",  "from": 8000              }
        ]
      }
    },
    "avg_price": {
      "avg": {
        "field": "price"
      }
    },
    "max_price": {
      "max": {
        "field": "price"
      }
    },
    "price_histogram": {
      "histogram": {
        "field":    "price",
        "interval": 1000,
        "min_doc_count": 1
      }
    },
    "rating_stats": {
      "stats": {
        "field": "rating"
      }
    }
  }
}

// 巢狀聚合（子聚合）：每個分類的平均價格
GET /products/_search
{
  "size": 0,
  "aggs": {
    "by_category": {
      "terms": {
        "field": "category",
        "size":  10
      },
      "aggs": {
        "avg_price": {
          "avg": { "field": "price" }
        },
        "price_range": {
          "stats": { "field": "price" }
        }
      }
    }
  }
}
```

## 巢狀查詢（Nested Query）

```json
// 查詢 attributes 中 key="顏色" AND value="黑色" 的商品
// 必須用 nested query，否則不同 attribute 的 key/value 會交叉匹配！

GET /products/_search
{
  "query": {
    "nested": {
      "path": "attributes",
      "query": {
        "bool": {
          "must": [
            { "term": { "attributes.key":   "顏色" }},
            { "term": { "attributes.value": "黑色" }}
          ]
        }
      }
    }
  }
}
```
