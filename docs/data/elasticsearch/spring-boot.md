# Spring Boot 整合

!!! abstract "本章重點"

    本章示範用 Spring Data Elasticsearch 操作索引與查詢，並比較同步雙寫、MQ 非同步、Canal 監聽 Binlog 等資料庫與 ES 的資料同步方案。

## Spring Data Elasticsearch 整合

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-elasticsearch</artifactId>
</dependency>
```

```yaml
# application.yml
spring:
  elasticsearch:
    uris: http://localhost:9200
    username: elastic
    password: ${ES_PASSWORD}
    connection-timeout: 5s
    socket-timeout:     30s
```

```java
// ES 文件實體
@Document(indexName = "products", createIndex = true)
@Setting(settingPath = "elasticsearch/product-settings.json")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProductDocument {

    @Id
    private Long id;

    @Field(type = FieldType.Text,
           analyzer = "ik_max_word",
           searchAnalyzer = "ik_smart")
    private String name;

    @Field(type = FieldType.Text,
           analyzer = "ik_smart")
    private String description;

    @Field(type = FieldType.Double)
    private Double price;

    @Field(type = FieldType.Keyword)
    private String category;

    @Field(type = FieldType.Keyword)
    private List<String> tags;

    @Field(type = FieldType.Integer)
    private Integer stock;

    @Field(type = FieldType.Keyword)
    private String brand;

    @Field(type = FieldType.Float)
    private Float rating;

    @Field(type = FieldType.Long)
    private Long soldCount;

    @Field(type = FieldType.Keyword,
           index = false)
    private String imageUrl;

    @Field(type = FieldType.Keyword)
    private String status;

    @Field(type = FieldType.Date,
           format = DateFormat.date_time)
    private LocalDateTime createdAt;

    @Field(type = FieldType.Nested)
    private List<ProductAttribute> attributes;

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class ProductAttribute {
        @Field(type = FieldType.Keyword)
        private String key;
        @Field(type = FieldType.Keyword)
        private String value;
    }
}
```

```java
// Repository（簡單查詢）
@Repository
public interface ProductRepository
        extends ElasticsearchRepository<ProductDocument, Long> {

    // 方法名自動生成查詢
    List<ProductDocument> findByCategory(String category);
    List<ProductDocument> findByPriceBetween(Double min, Double max);
    List<ProductDocument> findByNameContaining(String name);

    // 自定義查詢
    @Query("{\"bool\": {\"must\": [{\"match\": {\"name\": \"?0\"}}], " +
           "\"filter\": [{\"term\": {\"status\": \"ACTIVE\"}}]}}")
    Page<ProductDocument> searchActiveByName(String name, Pageable pageable);
}
```

=== "搜索"

    ``` java
    @Service
    @RequiredArgsConstructor
    public class ProductSearchService {

        private final ElasticsearchRestTemplate esTemplate;

        public SearchResult<ProductDocument> search(ProductSearchRequest req) {
            BoolQueryBuilder bool = QueryBuilders.boolQuery();

            // must：全文搜尋，影響相關性分數（name 欄位權重 ×3）
            if (StringUtils.hasText(req.getKeyword())) {
                bool.must(QueryBuilders.multiMatchQuery(req.getKeyword(), "name", "description", "brand")
                        .field("name", 3.0f));
            }
            // filter：精確條件，不計分、可被快取
            if (StringUtils.hasText(req.getCategory())) {
                bool.filter(QueryBuilders.termQuery("category", req.getCategory()));
            }
            bool.filter(QueryBuilders.rangeQuery("price").gte(req.getMinPrice()).lte(req.getMaxPrice()));
            bool.mustNot(QueryBuilders.termQuery("status", "OFFLINE"));

            NativeSearchQuery query = new NativeSearchQueryBuilder()
                    .withQuery(bool)
                    .withSort(SortBuilders.scoreSort().order(SortOrder.DESC))              // 排序
                    .withPageable(PageRequest.of(req.getPage(), req.getSize()))            // 分頁
                    .withHighlightBuilder(new HighlightBuilder().field("name"))            // 高亮
                    .addAggregation(AggregationBuilders.terms("by_brand").field("brand"))  // 聚合：篩選面板
                    .build();

            SearchHits<ProductDocument> hits = esTemplate.search(query, ProductDocument.class);
            return buildSearchResult(hits, req);   // 套用高亮、整理聚合結果
        }
    }
    ```

    ??? example "完整程式碼（178 行）：排序選項、價格區間聚合、欄位過濾、結果處理"

        ``` java
        // ElasticsearchRestTemplate（複雜查詢，推薦！）
        @Service
        @RequiredArgsConstructor
        @Slf4j
        public class ProductSearchService {

            private final ElasticsearchRestTemplate esTemplate;
            private final ProductRepository         productRepository;



            public SearchResult<ProductDocument> search(ProductSearchRequest request) {

                // 1. 建立 bool query
                BoolQueryBuilder boolQuery = QueryBuilders.boolQuery();

                // 全文搜索（影響相關性分數）
                if (StringUtils.hasText(request.getKeyword())) {
                    boolQuery.must(
                        QueryBuilders.multiMatchQuery(request.getKeyword(),
                            "name", "description", "brand")
                            .field("name", 3.0f)          // name 欄位權重 x3
                            .field("description", 1.0f)
                            .field("brand", 2.0f)
                            .type(MultiMatchQueryBuilder.Type.BEST_FIELDS)
                    );
                }

                // 過濾條件（不影響相關性分數，有緩存）
                if (StringUtils.hasText(request.getCategory())) {
                    boolQuery.filter(
                        QueryBuilders.termQuery("category", request.getCategory())
                    );
                }

                if (request.getMinPrice() != null || request.getMaxPrice() != null) {
                    RangeQueryBuilder priceRange = QueryBuilders.rangeQuery("price");
                    if (request.getMinPrice() != null)
                        priceRange.gte(request.getMinPrice());
                    if (request.getMaxPrice() != null)
                        priceRange.lte(request.getMaxPrice());
                    boolQuery.filter(priceRange);
                }

                if (request.getBrands() != null && !request.getBrands().isEmpty()) {
                    boolQuery.filter(
                        QueryBuilders.termsQuery("brand", request.getBrands())
                    );
                }

                // 只顯示有庫存的
                if (Boolean.TRUE.equals(request.getInStockOnly())) {
                    boolQuery.filter(QueryBuilders.rangeQuery("stock").gt(0));
                }

                boolQuery.mustNot(
                    QueryBuilders.termQuery("status", "OFFLINE")
                );

                // 2. 建立 NativeSearchQuery
                NativeSearchQueryBuilder queryBuilder = new NativeSearchQueryBuilder()
                    .withQuery(boolQuery);

                // 3. 排序
                String sortBy = request.getSortBy();
                if ("price_asc".equals(sortBy)) {
                    queryBuilder.withSort(SortBuilders.fieldSort("price").order(SortOrder.ASC));
                } else if ("price_desc".equals(sortBy)) {
                    queryBuilder.withSort(SortBuilders.fieldSort("price").order(SortOrder.DESC));
                } else if ("sales".equals(sortBy)) {
                    queryBuilder.withSort(SortBuilders.fieldSort("soldCount").order(SortOrder.DESC));
                } else if ("rating".equals(sortBy)) {
                    queryBuilder.withSort(SortBuilders.fieldSort("rating").order(SortOrder.DESC));
                } else {
                    // 預設：相關性分數 → 評分 → 銷量
                    queryBuilder.withSort(SortBuilders.scoreSort().order(SortOrder.DESC));
                    queryBuilder.withSort(SortBuilders.fieldSort("rating").order(SortOrder.DESC));
                    queryBuilder.withSort(SortBuilders.fieldSort("soldCount").order(SortOrder.DESC));
                }

                // 4. 分頁
                queryBuilder.withPageable(
                    PageRequest.of(request.getPage(), request.getSize())
                );

                // 5. 高亮
                if (StringUtils.hasText(request.getKeyword())) {
                    HighlightBuilder highlightBuilder = new HighlightBuilder()
                        .field(new HighlightBuilder.Field("name")
                            .numOfFragments(0))              // 0 = 返回完整欄位
                        .field(new HighlightBuilder.Field("description")
                            .fragmentSize(150)
                            .numOfFragments(3))
                        .preTags("<em>")
                        .postTags("</em>");
                    queryBuilder.withHighlightBuilder(highlightBuilder);
                }

                // 6. 聚合（用於左側篩選面板）
                queryBuilder
                    .addAggregation(AggregationBuilders.terms("by_category")
                        .field("category").size(20))
                    .addAggregation(AggregationBuilders.terms("by_brand")
                        .field("brand").size(50))
                    .addAggregation(AggregationBuilders.range("by_price")
                        .field("price")
                        .addRange("0-500",   0,    500)
                        .addRange("500-1000",  500,  1000)
                        .addRange("1000-3000", 1000, 3000)
                        .addRange("3000+",     3000, Double.MAX_VALUE));

                // 7. 只取需要的欄位（節省網路傳輸）
                queryBuilder.withSourceFilter(
                    new FetchSourceFilter(
                        new String[]{"id", "name", "price", "category",
                                     "brand", "rating", "soldCount", "imageUrl", "stock"},
                        null
                    )
                );

                // 8. 執行查詢
                SearchHits<ProductDocument> searchHits =
                    esTemplate.search(queryBuilder.build(), ProductDocument.class);

                // 9. 處理結果
                return buildSearchResult(searchHits, request);
            }

            private SearchResult<ProductDocument> buildSearchResult(
                    SearchHits<ProductDocument> searchHits,
                    ProductSearchRequest request) {

                // 處理高亮
                List<ProductDocument> products = searchHits.stream()
                    .map(hit -> {
                        ProductDocument product = hit.getContent();
                        // 替換高亮欄位
                        if (!hit.getHighlightFields().isEmpty()) {
                            List<String> nameHighlight =
                                hit.getHighlightField("name");
                            if (!nameHighlight.isEmpty()) {
                                product.setName(nameHighlight.get(0));
                            }
                        }
                        return product;
                    })
                    .collect(Collectors.toList());

                // 處理聚合結果
                Map<String, List<AggBucket>> aggregations = new HashMap<>();

                if (searchHits.hasAggregations()) {
                    Aggregations aggs = searchHits.getAggregations();

                    // 分類聚合
                    Terms categoryTerms = aggs.get("by_category");
                    aggregations.put("categories",
                        categoryTerms.getBuckets().stream()
                            .map(b -> new AggBucket(b.getKeyAsString(), b.getDocCount()))
                            .collect(Collectors.toList()));

                    // 品牌聚合
                    Terms brandTerms = aggs.get("by_brand");
                    aggregations.put("brands",
                        brandTerms.getBuckets().stream()
                            .map(b -> new AggBucket(b.getKeyAsString(), b.getDocCount()))
                            .collect(Collectors.toList()));
                }

                return SearchResult.<ProductDocument>builder()
                    .items(products)
                    .total(searchHits.getTotalHits())
                    .page(request.getPage())
                    .size(request.getSize())
                    .aggregations(aggregations)
                    .build();
            }

        ```

=== "索引管理"

    ``` java

        // 批量索引（同步 DB 數據到 ES）
        public void bulkIndex(List<ProductDocument> products) {
            productRepository.saveAll(products);
            log.info("批量索引 {} 個商品", products.size());
        }

        // 更新單個文件
        public void updateProduct(ProductDocument product) {
            productRepository.save(product);
        }

        // 刪除文件
        public void deleteProduct(Long productId) {
            productRepository.deleteById(productId);
        }

        // 完全重建索引（全量同步）
        @Async
        public void reindexAll() {
            log.info("開始全量重建索引...");
            int page = 0, size = 1000;
            long total = 0;

            while (true) {
                List<Product> products = productRepository
                    .findAllActive(PageRequest.of(page, size));
                if (products.isEmpty()) break;

                List<ProductDocument> docs = products.stream()
                    .map(this::toDocument)
                    .collect(Collectors.toList());

                productRepository.saveAll(docs);
                total += docs.size();
                page++;
                log.info("已索引 {} 個商品...", total);
            }

            log.info("全量重建索引完成，共 {} 個商品", total);
        }

        private ProductDocument toDocument(Product product) {
            return ProductDocument.builder()
                .id(product.getId())
                .name(product.getName())
                .description(product.getDescription())
                .price(product.getPrice().doubleValue())
                .category(product.getCategory())
                .brand(product.getBrand())
                .stock(product.getStock())
                .rating(product.getRating())
                .soldCount(product.getSoldCount())
                .imageUrl(product.getMainImage())
                .status(product.getStatus().name())
                .createdAt(product.getCreatedAt())
                .build();
        }
    }
    ```


## DB 與 ES 數據同步方案

```
數據同步策略：

① 同步雙寫（簡單，但有一致性問題）
  @Transactional
  public Product createProduct(ProductRequest request) {
      Product product = productRepo.save(request);    // 寫 DB
      esService.index(toDocument(product));            // 寫 ES
      return product;
  }
  問題：ES 寫失敗但 DB 成功 → 數據不一致！

② 異步雙寫（解耦，最終一致性）
  @Transactional
  public Product createProduct(ProductRequest request) {
      Product product = productRepo.save(request);
      // 事務提交後，異步同步到 ES
      eventPublisher.publishEvent(new ProductCreatedEvent(product));
      return product;
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  @Async
  public void syncToEs(ProductCreatedEvent event) {
      esService.index(toDocument(event.getProduct()));
  }

③ Canal（監聽 MySQL Binlog）← 生產推薦
  MySQL Binlog → Canal → MQ（Kafka/RabbitMQ）→ ES Sync Service → ES
  完全解耦，任何 DB 變更都能同步
  即使 ES Sync Service 掛了，MQ 會保留消息
```

```java
// Canal 消費者（監聽 MySQL 變更同步 ES）
@Component
@RequiredArgsConstructor
@Slf4j
public class ProductCanalConsumer {

    private final ProductSearchService searchService;

    @RabbitListener(queues = "canal.product.changes")
    public void handleProductChange(CanalMessage message) {
        switch (message.getEventType()) {
            case INSERT, UPDATE -> {
                ProductDocument doc = convertToDocument(message.getData());
                searchService.updateProduct(doc);
                log.info("同步商品到 ES：{}", doc.getId());
            }
            case DELETE -> {
                Long productId = extractId(message.getData());
                searchService.deleteProduct(productId);
                log.info("從 ES 刪除商品：{}", productId);
            }
        }
    }
}
```
