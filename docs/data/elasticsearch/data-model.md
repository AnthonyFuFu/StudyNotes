# 資料模型

## Mapping（欄位類型定義）

```json
// 建立 Index 並定義 Mapping
PUT /products
{
  "settings": {
    "number_of_shards":   3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "ik_smart_analyzer": {
          "type":      "custom",
          "tokenizer": "ik_smart"
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "id": {
        "type": "long"
      },
      "name": {
        "type":     "text",
        "analyzer": "ik_max_word",
        "fields": {
          "keyword": {
            "type":         "keyword",
            "ignore_above": 256
          }
        }
      },
      "description": {
        "type":     "text",
        "analyzer": "ik_smart"
      },
      "price": {
        "type": "double"
      },
      "category": {
        "type": "keyword"
      },
      "tags": {
        "type": "keyword"
      },
      "stock": {
        "type": "integer"
      },
      "status": {
        "type": "keyword"
      },
      "images": {
        "type": "keyword",
        "index": false
      },
      "location": {
        "type": "geo_point"
      },
      "attributes": {
        "type": "nested",
        "properties": {
          "key":   { "type": "keyword" },
          "value": { "type": "keyword" }
        }
      },
      "created_at": {
        "type":   "date",
        "format": "yyyy-MM-dd HH:mm:ss||yyyy-MM-dd||epoch_millis"
      }
    }
  }
}
```

**常用欄位類型**

text：    全文搜索（會分詞）

- name: "iPhone 15 Pro"
- → 分詞 → ["iPhone", "15", "Pro"]
- → 可以搜 "iPhone" 找到此文件

keyword： 精確匹配（不分詞）

- category: "手機"
- → 必須搜 "手機" 才能找到，搜 "手" 找不到
- → 適合排序、聚合、精確過濾

**text + keyword 雙類型（fields）**

- name 欄位同時支援全文搜索和精確匹配
- name        → text  → 全文搜索（"iPhone"）
- name.keyword → keyword → 排序、聚合（精確匹配）

nested：  嵌套對象（保持對象內欄位的關聯）

**vs object 類型**

- object 的數組會被扁平化（失去關聯）
- nested 保持每個對象的獨立性

index: false  不建立索引（不能被搜索，但可以取回）

- 適合：大圖片 URL、不需要搜索的欄位

## 分析器（Analyzer）

**分析器流程**

原始文本 → Character Filter → Tokenizer → Token Filter → Token 列表

**範例**

原始文本："I LOVE Java Programming!"

- ① Character Filter（字符過濾）：去除 HTML 標籤等
    - → "I LOVE Java Programming!"

- ② Tokenizer（分詞）：按空格、標點切分
    - → ["I", "LOVE", "Java", "Programming"]

- ③ Token Filter（詞語過濾）：
    - lowercase → ["i", "love", "java", "programming"]
    - stop word → 去除停用詞（"i"）→ ["love", "java", "programming"]
    - stemmer   → 詞幹提取 → ["love", "java", "program"]

**中文分詞（IK Analyzer 插件）**

- ik_smart：智能模式，較少分詞（粗粒度）
    - "中華人民共和國" → ["中華人民共和國"]
- ik_max_word：最細粒度，盡量多分詞
    - "中華人民共和國" → ["中華人民共和國", "中華人民", "中華", "人民共和國", ...]

**建議**

- index（建立索引）時 → ik_max_word（盡量多分詞，增加召回率）
- search（搜索時）   → ik_smart（智能分詞，提高精確度）

```bash
# 測試分析器
GET /products/_analyze
{
  "analyzer": "ik_max_word",
  "text": "Java 程式設計入門到精通"
}

# 輸出：
# ["Java", "程式", "程式設計", "設計", "入門", "到", "精通"]
```
