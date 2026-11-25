# WebFlux、R2DBC 與 WebClient

## 兩種撰寫端點的方式

=== "註解式 Controller"

    ``` java
    @RestController
    @RequestMapping("/stocks")
    @RequiredArgsConstructor
    public class StockController {
        private final StockService stockService;

        @GetMapping("/{symbol}")
        public Mono<Stock> get(@PathVariable String symbol) {
            return stockService.findBySymbol(symbol);
        }

        @GetMapping(value = "/top-gainers", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
        public Flux<StockQuote> topGainers() {
            return stockService.topGainers();          // 以 SSE 逐筆推送
        }
    }
    ```

    寫法與 Spring MVC 幾乎相同，只是回傳型別換成 `Mono` / `Flux`。**stock-observation 採用這種寫法**。

=== "函數式路由"

    ``` java
    @Bean
    RouterFunction<ServerResponse> routes(StockHandler handler) {
        return route()
            .GET("/stocks/{symbol}", handler::get)
            .GET("/stocks", handler::list)
            .build();
    }
    ```

    路由與處理邏輯分離，沒有反射與註解掃描，啟動較快，適合輕量服務。

## R2DBC：反應式關聯式資料庫

JDBC 的每個方法都是阻塞的，不能用在 WebFlux。**R2DBC（Reactive Relational Database Connectivity）** 是非阻塞的資料庫驅動規範。

``` java
public interface StockQuoteRepository extends ReactiveCrudRepository<StockQuote, Long> {

    Flux<StockQuote> findBySymbolOrderByTradeDateDesc(String symbol);

    @Query("SELECT * FROM stock_quote ORDER BY change_percent DESC LIMIT :limit")
    Flux<StockQuote> findTopGainers(int limit);
}
```

| | JPA（JDBC） | R2DBC |
|---|-------------|-------|
| I/O | 阻塞 | 非阻塞 |
| ORM 功能 | 完整：關聯對映、延遲載入、髒檢查 | ❌ 沒有：不支援 `@OneToMany` 等關聯 |
| 多對多關聯 | 自動處理 | 要自己建中間表 Entity 並手動組合 |
| 交易 | `@Transactional` | `@Transactional` 也可用（改用 `TransactionalOperator` 實作） |
| 支援資料庫 | 幾乎全部 | PostgreSQL、MySQL、MariaDB、SQL Server、H2 等 |

!!! example "我的實作：概念股的多對多關聯"

    stock-observation 的「股票 ↔ 概念股分類」是多對多關係。R2DBC 沒有 `@ManyToMany`，所以建立了中間表 `StockConceptRelation` 與對應的 `StockConceptRelationRepository`，查詢時先取關聯再 `flatMap` 查出股票，組合成結果。

## WebClient：非阻塞 HTTP 客戶端

``` java
@Bean
WebClient finnhubClient(@Value("${finnhub.api-key}") String apiKey) {
    return WebClient.builder()
            .baseUrl("https://finnhub.io/api/v1")
            .defaultHeader("X-Finnhub-Token", apiKey)
            .build();
}

public Mono<Quote> quote(String symbol) {
    return finnhubClient.get()
            .uri(b -> b.path("/quote").queryParam("symbol", symbol).build())
            .retrieve()
            .onStatus(HttpStatusCode::is4xxClientError, r -> Mono.error(new InvalidSymbolException(symbol)))
            .bodyToMono(Quote.class)
            .retryWhen(Retry.backoff(2, Duration.ofMillis(300)));   // 指數退避重試
}
```

| | `RestTemplate` | `RestClient`（Spring 6.1+） | `WebClient` |
|---|----------------|-----------------------------|-------------|
| 模型 | 同步阻塞 | 同步阻塞，流暢 API | 非阻塞 |
| 狀態 | 維護模式 | MVC 專案的新選擇 | WebFlux 首選，MVC 中也能用 |
| 串流 | ❌ | ❌ | ✅ `bodyToFlux` |

## 測試：StepVerifier

``` java
@Test
void findTopGainers_returnsSortedQuotes() {
    StepVerifier.create(stockService.topGainers(3))
        .expectNextMatches(q -> q.getChangePercent() >= 9.5)
        .expectNextCount(2)
        .verifyComplete();
}
```

搭配 `WebTestClient` 測試端點、`reactor-test` 驗證非同步序列，不需要 `Thread.sleep`。

## 設定重點

``` yaml
spring:
  r2dbc:
    url: r2dbc:postgresql://localhost:5432/stock
    pool:
      initial-size: 5
      max-size: 20
  webflux:
    base-path: /api           # 所有端點加上 /api 前綴
```

## 優點與缺點

=== "優點"

    - 端點寫法與 MVC 相近，**註解式 Controller 上手快**
    - `WebClient` 讓「同時呼叫多個外部 API」變得簡單又高效
    - R2DBC 連線使用率高，少量連線就能服務大量請求

=== "缺點"

    - **R2DBC 沒有 ORM 關聯**，複雜的關聯查詢要自己組合
    - 資料庫驅動選擇比 JDBC 少，部分資料庫的功能支援不完整
    - 跟同步程式碼混用時，很容易不小心引入阻塞呼叫
