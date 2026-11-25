---
icon: lucide/leaf
---

# Spring Boot（MVC）

Java 後端最主流的框架。這個主題從 IoC、自動配置、AOP 代理講到請求處理流程與交易，最後以 holidayDessert 的高併發搶票系統做完整實戰。

**核心技術**：IoC / 自動配置 / AOP / DispatcherServlet / JPA / @Transactional / Redis Lua / Azure OpenAI / Tesseract OCR

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Spring Boot（MVC）"])
    c0["01 · 核心原理：IoC、自動配置與 AOP"]
    R --> c0
    p0("・IoC 與依賴注入<br>・Bean 生命週期<br>・自動配置原理<br>・AOP 與代理")
    c0 --- p0
    c1["02 · Web MVC 請求處理流程"]
    R --> c1
    p1("・一個請求經過哪些元件<br>・Filter、Interceptor、AOP 的差別<br>・Thread-per-Request 模型<br>・全域例外處理<br>・API 文件：springdoc-openapi")
    c1 --- p1
    c2["03 · 資料存取與交易"]
    R --> c2
    p2("・三種資料存取方式<br>・連線池：HikariCP<br>・@Transactional 原理<br>・用資料庫防止超賣：條件式 UPDATE")
    c2 --- p2
    c3["04 · 實戰：高併發搶票系統"]
    R --> c3
    p3("・為什麼不能直接查資料庫扣庫存<br>・活動生命週期<br>・四層防護<br>・設計取捨")
    c3 --- p3
    c4["05 · 實戰：AI、OCR 與周邊整合"]
    R --> c4
    p4("・整合一覽<br>・Azure OpenAI<br>・Azure AI Vision：圖片描述<br>・Tesseract OCR<br>・報表與文件")
    c4 --- p4
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4 chapter
    class p0,p1,p2,p3,p4 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 核心原理：IoC、自動配置與 AOP](core.md)__

    ---

    Spring Boot = Spring Framework + 自動配置 + 內嵌伺服器 + Starter。

-   __[02 · Web MVC 請求處理流程](web-mvc.md)__

    ---

    一個 HTTP 請求進到 Spring MVC 後，會依序經過 Filter、DispatcherServlet、HandlerMapping、Interceptor 與 HandlerAdapter。

-   __[03 · 資料存取與交易](data-access.md)__

    ---

    本章比較 JPA、JdbcTemplate、MyBatis 三種資料存取方式與 HikariCP 連線池設定，深入 `@Transactional` 的代理原理、傳播行為與常見的失效原因，最後說明用條件式 UPDATE 防止超賣。

-   __[04 · 實戰：高併發搶票系統](practice-seckill.md)__

    ---

    瞬間數千人搶同一批票，直接扣資料庫庫存會鎖競爭、連線耗盡甚至超賣。

-   __[05 · 實戰：AI、OCR 與周邊整合](practice-integrations.md)__

    ---

    業務系統常常要整合外部能力：大型語言模型、圖片辨識、文字辨識、報表與加密。

</div>

## 優點與缺點

| ✅ 優點 | ❌ 缺點 |
|--------|--------|
| 約定優於配置，新專案幾分鐘就能跑起來 | 自動配置與代理是「魔法」，不懂原理很難除錯 |
| 生態最完整：資料、快取、MQ、安全、雲端都有 Starter | 啟動較慢、記憶體用量大 |
| 同步寫法直覺，堆疊追蹤完整 | Thread-per-Request，大量慢速 I/O 時執行緒會耗盡 |
| 內嵌伺服器，打包成一個 JAR 方便容器化 | 依賴龐大，JAR 動輒上百 MB |

!!! example "我的實作：holidayDessert"

    Spring Boot 3.5 + Java 17 的甜點電商暨票券系統：前台購物網站與後台管理、Google OAuth2 登入、JWT、Redis 分散式鎖與 Lua、Kafka 非同步訂單、STOMP 客服聊天室、OpenSearch、AWS S3 分片上傳、Azure OpenAI、Tesseract OCR、PDF / Excel 報表；GitHub Actions 建置映像推送到 GHCR。
