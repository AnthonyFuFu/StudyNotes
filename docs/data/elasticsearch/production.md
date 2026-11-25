# 生產實戰

## 索引設計最佳實踐

**Index 命名規範**

- ❌ products（不要用單一索引名）
- ✅ products_v1（帶版本號）
    - products_v2（升級 Mapping 時建立新版本）

**使用別名（Alias）**

- products → 指向 products_v1

**重建索引時**

- ① 建立新的 products_v2
- ② 將數據從 v1 複製到 v2（reindex API）
- ③ 將別名 products 指向 v2（零停機！）
- ④ 刪除 products_v1

**Index 別名操作**

POST /_aliases

{

- "actions": [
    - { "add":    { "index": "products_v2", "alias": "products" }},
    - { "remove": { "index": "products_v1", "alias": "products" }}
- ]

}

**分片設計**

- 根據數據量估算：每個分片 10GB\~50GB
- 1億商品 × 約1KB/文件 = 約100GB
- → 3\~5 個主分片
- → 副本數：1（生產）或 2（高可用）

**冷熱數據分離（ILM 索引生命週期管理）**

- Hot（最近7天）：SSD 磁碟，3副本
- Warm（7天\~30天）：HDD 磁碟，1副本，只讀
- Cold（30天以上）：壓縮，1副本
- Delete（90天後）：自動刪除

## 效能調優

```yaml
# 索引設定調優
PUT /products/_settings
{
  "index": {
    "refresh_interval": "30s",
    "number_of_replicas": 0
  }
}
# 批量導入時：
# ① 關閉副本（number_of_replicas: 0）
# ② 增大 refresh_interval（降低刷新頻率）
# 導入完成後再恢復

# JVM 調優（elasticsearch.yml 旁的 jvm.options）
# 設定堆記憶體為物理記憶體的 50%，且不超過 32GB
# -Xms16g
# -Xmx16g
# ⚠️ 不超過 32GB！超過會關閉 Compressed OOPs，反而浪費記憶體
```

```java
// 批量寫入（Bulk API）- 提升寫入效能
@Service
public class BulkIndexService {

    private final ElasticsearchRestTemplate esTemplate;

    public void bulkIndex(List<ProductDocument> products) {
        // 每批 1000 個，避免單次請求太大
        int batchSize = 1000;
        for (int i = 0; i < products.size(); i += batchSize) {
            List<ProductDocument> batch = products.subList(
                i, Math.min(i + batchSize, products.size())
            );

            List<IndexQuery> queries = batch.stream()
                .map(product -> new IndexQueryBuilder()
                    .withId(product.getId().toString())
                    .withObject(product)
                    .build())
                .collect(Collectors.toList());

            esTemplate.bulkIndex(queries, ProductDocument.class);
            log.info("批量索引進度：{}/{}", i + batch.size(), products.size());
        }

        // 強制刷新（讓數據立即可搜索）
        esTemplate.indexOps(ProductDocument.class).refresh();
    }
}
```

```
查詢優化：

✅ 使用 filter 代替 must（有緩存，不計算分數）
✅ 避免深度分頁（from + size > 10000 很慢）
   改用 search_after（基於上一頁最後一條記錄）
✅ 只取需要的欄位（_source filtering）
✅ 避免通配符查詢（wildcard）在高基數欄位
✅ 避免對 text 欄位排序（用 keyword 欄位排序）

深度分頁 → search_after：
GET /products/_search
{
  "query": { "match_all": {} },
  "sort": [
    { "created_at": "desc" },
    { "_id": "desc" }
  ],
  "size": 20,
  "search_after": ["2024-01-15T10:30:00", "12345"]
}
```

## ELK Stack 日誌系統建置

**完整 ELK 日誌流程回顧**

Spring Boot（JSON 日誌）

- ↓ stdout / 文件

Filebeat（輕量日誌採集）

- ↓ beats 協議

Logstash（解析、過濾、轉換）

- ↓ HTTP / 客戶端

Elasticsearch（儲存、索引）

- ↓

Kibana（搜索、視覺化、告警）

**日誌 Index 命名規範**

- {service}-logs-{date}
- order-service-logs-2024.01.15
- user-service-logs-2024.01.15

**常用 Kibana KQL 查詢**

- log_level: "ERROR"
- trace_id: "abc123"
- service: "order-service" AND duration_ms > 1000
- log_message: \*OutOfMemoryError\*

**ILM（Index Lifecycle Management）**

- Hot  → 7天，SSD，可讀寫
- Warm → 30天，HDD，只讀（forceMerge 到 1 個 Segment）
- Cold → 90天，壓縮
- Delete → 自動刪除

```json
// 建立日誌 ILM Policy
PUT /_ilm/policy/logs-policy
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age":  "1d",
            "max_size": "50gb"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink":     { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "allocate":   { "require": { "data": "warm" }}
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "allocate": { "require": { "data": "cold" }}
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```
