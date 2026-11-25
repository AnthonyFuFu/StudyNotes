# 反應式程式設計原理

!!! abstract "本章重點"

    WebFlux 用少量 Event Loop 執行緒處理大量等待 I/O 的連線。本章比較兩種並發模型，說明 Reactive Streams 與背壓、Mono / Flux 的常用運算子，以及「在 Event Loop 上阻塞」這個最大陷阱。

Spring WebFlux 是 Spring 的**非阻塞、反應式** Web 框架，底層預設跑在 **Netty** 上，以 **Project Reactor** 為核心。它解決的問題是：**用少量執行緒處理大量「正在等待 I/O」的連線**。

## 兩種並發模型

=== "Thread-per-Request（Spring MVC）"

    ``` mermaid
    flowchart LR
        R1["請求 1"] --> T1["執行緒 1<br>等待 DB…"]
        R2["請求 2"] --> T2["執行緒 2<br>等待 API…"]
        R3["請求 3"] --> T3["執行緒 3<br>等待 DB…"]
    ```

    一個請求佔一條執行緒，等待時執行緒閒置但不能做別的事。**並發上限 ≈ 執行緒數**。

=== "Event Loop（Spring WebFlux）"

    ``` mermaid
    flowchart LR
        R1["請求 1"] & R2["請求 2"] & R3["請求 N"] --> EL["Event Loop<br>少量執行緒（≈ CPU 核心數）"]
        EL -->|"發出 I/O 後立刻返回"| IO["非阻塞 I/O"]
        IO -->|"資料就緒時回呼"| EL
    ```

    執行緒發出 I/O 請求後**立刻去處理下一件事**，資料就緒時再由回呼接手。**並發上限 ≈ 記憶體與連線數**。

| | Spring MVC | Spring WebFlux |
|---|-----------|----------------|
| 伺服器 | Tomcat（Servlet） | Netty（預設） |
| 執行緒模型 | 每請求一條執行緒，預設 200 條 | Event Loop，執行緒數 ≈ CPU 核心數 |
| I/O | 阻塞 | 非阻塞 |
| 回傳型別 | `User`、`List<User>` | `Mono<User>`、`Flux<User>` |
| 資料庫 | JDBC / JPA | **R2DBC**、Reactive MongoDB / Redis |
| HTTP 客戶端 | `RestTemplate` / `RestClient` | **`WebClient`** |

## Reactive Streams 規範

反應式的核心規範只有四個介面，Reactor、RxJava 都實作它：

``` mermaid
sequenceDiagram
    participant S as Subscriber
    participant P as Publisher
    S->>P: subscribe()
    P->>S: onSubscribe(Subscription)
    S->>P: request(n)：我能處理 n 筆
    P->>S: onNext(資料 1)
    P->>S: onNext(資料 2)
    S->>P: request(n)：再要 n 筆
    P->>S: onComplete() 或 onError()
```

!!! info "背壓（Backpressure）"

    `request(n)` 讓**消費者決定速度**。生產者不能無限制推送，避免快的一方把慢的一方的記憶體塞爆。這是反應式與一般 callback / Future 最大的差別。

## Mono 與 Flux

| 型別 | 代表 | 對應同步寫法 |
|------|------|-------------|
| `Mono<T>` | 0 或 1 個元素 | `T`、`Optional<T>` |
| `Flux<T>` | 0 到 N 個元素（可以是無限串流） | `List<T>`、`Stream<T>` |

``` java
public Mono<StockDetail> getDetail(String symbol) {
    Mono<Stock> stock = stockRepository.findBySymbol(symbol);             // 非阻塞查 DB
    Mono<Quote> quote = finnhubClient.quote(symbol);                     // 非阻塞呼叫外部 API

    return Mono.zip(stock, quote)                                        // 兩個 I/O 同時進行
            .map(t -> new StockDetail(t.getT1(), t.getT2()))
            .timeout(Duration.ofSeconds(3))                              // 逾時控制
            .onErrorResume(e -> stock.map(StockDetail::withoutQuote));   // 外部 API 失敗時降級
}
```

**常用運算子**

| 類別 | 運算子 | 用途 |
|------|--------|------|
| 轉換 | `map`、`flatMap`、`concatMap` | `map` 同步轉換；`flatMap` 接另一個非同步呼叫（並行）；`concatMap` 保持順序 |
| 組合 | `zip`、`merge`、`concat` | 多個來源合併 |
| 錯誤 | `onErrorResume`、`onErrorReturn`、`retryWhen` | 降級、重試 |
| 時間 | `timeout`、`delayElements`、`interval` | 逾時、節流、定時推送 |
| 副作用 | `doOnNext`、`doOnError`、`doFinally` | 紀錄日誌，不改變資料 |

!!! warning "沒有 subscribe 就什麼都不會發生"

    Mono / Flux 是**懶惰的**：只是「描述要做什麼」的管線。在 WebFlux 裡由框架負責訂閱；自己在 Service 裡寫了 `repository.save(x)` 卻沒有把回傳的 `Mono` 串進管線，那筆資料**根本不會寫入**。

## 最大陷阱：在 Event Loop 上阻塞

``` java
// ❌ 錯誤：在反應式管線中呼叫阻塞 API，會卡住 Event Loop，所有請求一起變慢
return Mono.just(jdbcTemplate.queryForObject(sql, Stock.class));

// ✅ 不得不用阻塞 API 時，切到專用的執行緒池
return Mono.fromCallable(() -> jdbcTemplate.queryForObject(sql, Stock.class))
           .subscribeOn(Schedulers.boundedElastic());
```

Event Loop 只有少數幾條執行緒，**任何一個阻塞呼叫都會讓同一條執行緒上的所有請求一起等**。這也是 WebFlux 要求整條鏈路（資料庫驅動、HTTP 客戶端）都必須是非阻塞的原因。

## 什麼時候該用 WebFlux

| 適合 ✅ | 不適合 ❌ |
|--------|----------|
| 大量長連線：WebSocket、SSE、直播聊天室 | 一般 CRUD 後台系統 |
| 串流資料：影片、檔案代理、即時報價 | 依賴大量阻塞函式庫（JDBC、舊 SDK） |
| 閘道 / BFF：大量呼叫下游 API 再組合 | 團隊不熟悉反應式，除錯成本高 |
| Spring Cloud Gateway（本身就是 WebFlux） | 需要 JPA 的延遲載入、複雜交易 |

!!! tip "Java 21 虛擬執行緒改變了選擇"

    虛擬執行緒讓 Spring MVC 用同步寫法也能撐住大量 I/O 等待。現在的建議是：**一般業務系統用 MVC + 虛擬執行緒；真正需要串流、背壓、長連線時才用 WebFlux**。

## 優點與缺點

=== "優點"

    - **資源效率高**：少量執行緒撐起數萬並發連線，記憶體用量低
    - **天生支援串流**：`Flux` 可以邊產生邊回應，適合 SSE、影片、大檔案
    - **背壓**：消費者控制流量，避免記憶體爆掉
    - **宣告式組合**：`zip`、`timeout`、`retry` 讓並行呼叫與容錯寫得很簡潔

=== "缺點"

    - **學習曲線陡**：思維從「一步一步做」變成「描述資料流」
    - **除錯困難**：堆疊追蹤被切碎，需要 `checkpoint()`、`Hooks.onOperatorDebug()` 輔助
    - **生態限制**：整條鏈都要非阻塞；JPA、許多 SDK 無法直接使用
    - **ThreadLocal 失效**：MDC 日誌、交易上下文要改用 Reactor `Context` 傳遞
