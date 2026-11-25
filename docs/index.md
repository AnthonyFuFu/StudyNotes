---
icon: lucide/book-open
---

# Study Notes

系統性整理全端工程師的核心知識體系：從 Java 與 JVM 底層、後端與前端框架、資料與訊息，到架構設計、網路資安與工程實踐。每個主題都不只停在「會用」，而是深入到「為什麼這樣設計」，並搭配我在實際專案中的實作。

目前收錄 **7 大分類 · 25 個主題 · 120 個章節**。

## 知識地圖

<div class="grid cards" markdown>

-   :lucide-coffee: __[Java 核心](java/index.md)__

    ---

    語言新特性、JVM 記憶體與 GC、多執行緒並發的底層實作。

    [Java 新特性](java/new-features/index.md) · [JVM 深度原理](java/jvm/index.md) · [Java 並發](java/concurrency/index.md)

-   :lucide-server: __[後端框架](backend/index.md)__

    ---

    Servlet、反應式、微服務與 .NET 四種後端框架的原理與實戰。

    [Spring Boot](backend/spring-boot/index.md) · [WebFlux](backend/webflux/index.md) · [Spring Cloud](backend/spring-cloud/index.md) · [ASP.NET Core](backend/aspnet-core/index.md)

-   :lucide-monitor: __[前端開發](frontend/index.md)__

    ---

    瀏覽器原理、伺服器端模板、三大框架與桌面應用。

    [基礎原理](frontend/fundamentals/index.md) · [伺服器端模板](frontend/templates/index.md) · [Vue](frontend/vue/index.md) · [React](frontend/react/index.md) · [Angular](frontend/angular/index.md) · [Electron](frontend/electron/index.md)

-   :lucide-database: __[資料與訊息](data/index.md)__

    ---

    關聯式資料庫、快取、全文搜尋與訊息佇列。

    [MySQL](data/mysql/index.md) · [Redis](data/redis/index.md) · [Elasticsearch](data/elasticsearch/index.md) · [訊息佇列](data/messaging/index.md)

-   :lucide-blocks: __[架構設計](architecture/index.md)__

    ---

    系統設計、設計模式與服務之間的通訊協議。

    [系統設計](architecture/system-design/index.md) · [設計模式](architecture/design-pattern/index.md) · [API 設計與通訊協議](architecture/api-design/index.md)

-   :lucide-shield: __[網路與資安](network-security/index.md)__

    ---

    TCP / HTTP / TLS 等網路基礎，以及認證授權與攻擊防禦。

    [網路基礎](network-security/network/index.md) · [資安](network-security/security/index.md)

-   :lucide-wrench: __[工程實踐](engineering/index.md)__

    ---

    自動化測試、CI/CD 流水線、監控與可觀測性。

    [測試](engineering/testing/index.md) · [CI/CD 與 DevOps](engineering/cicd/index.md) · [監控與可觀測性](engineering/monitoring/index.md)

</div>

## 我的專案

筆記中的「實戰」章節都來自以下專案，可以直接從這裡跳到對應的說明。

| 專案 | 類型 | 技術 | 筆記 |
|------|------|------|------|
| **holidayDessert** | 電商 + 票券系統 | Spring Boot 3.5、Thymeleaf、Redis Lua、Kafka、STOMP、OpenSearch | [高併發搶票](backend/spring-boot/practice-seckill.md) · [Kafka](data/messaging/kafka.md) · [即時通訊](architecture/api-design/realtime-streaming.md) |
| **holiday_dessert_vue** | 前台 SPA | Vue 3、Vue Router、Vuex、Axios | [Vue 3 前後端分離](frontend/vue/vue3-spa.md) |
| **stock-observation** | 股票觀測 + 直播平台 | Spring Boot 4、WebFlux、R2DBC、MediaMTX | [直播與影片串流](backend/webflux/practice-streaming.md) |
| **microservicecloud** | 微服務 | Spring Cloud、Eureka、Resilience4j、RabbitMQ、K8s | [微服務與 K8s](backend/spring-cloud/practice.md) · [RabbitMQ](data/messaging/rabbitmq.md) |
| **chineseArtwork** | 書畫網站 | ASP.NET Core 8、Razor、EF Core、SQL Server | [ASP.NET Core](backend/aspnet-core/index.md) |
| **chinese_artwork_angular** | 書畫網站前端 | Angular 21、SSR、Angular Material、Tailwind | [SSR 與 Hydration](frontend/angular/ssr-ui.md) |
| **fu-clan-management-system** | 桌面應用 | Electron、React 19、TypeScript、Ant Design、sql.js | [React + TypeScript](frontend/react/react-typescript.md) · [Electron](frontend/electron/index.md) |

## 學習方法

每個主題都依照同一條路徑展開：

``` mermaid
flowchart LR
    W["Why<br>解決什麼問題"] --> WT["What<br>核心概念"] --> H["How<br>底層原理"] --> P["Practice<br>專案實作"] --> PF["Pitfalls<br>陷阱與取捨"]
```

!!! quote ""

    不理解底層原理的工程師，只是在調用 API 而已。

## 技術棧總覽

| 領域 | 技術 |
|------|------|
| **語言** | Java 17 / 21、C#（.NET 8）、TypeScript、JavaScript、Python |
| **後端框架** | Spring Boot 3 / 4（MVC、WebFlux）、Spring Cloud、Spring Security、ASP.NET Core（MVC、Razor Pages） |
| **前端** | Vue 2 / 3、React 19、Angular 21、Thymeleaf、Razor、jQuery、Ant Design、Angular Material、Tailwind CSS |
| **桌面** | Electron、electron-builder |
| **資料存取** | Spring Data JPA、JdbcTemplate、R2DBC、EF Core、sql.js |
| **資料庫** | MySQL 8 / MariaDB、PostgreSQL、SQL Server、SQLite、H2 |
| **快取 / 搜尋** | Redis（Lua、分散式鎖）、OpenSearch / Elasticsearch、Logstash |
| **訊息佇列** | Apache Kafka（Avro、Schema Registry）、RabbitMQ |
| **即時通訊 / 串流** | WebSocket（STOMP、SockJS）、MediaMTX（RTMP / HLS）、HTTP Range |
| **雲端 / AI** | AWS S3、Azure OpenAI、Azure AI Vision、Tesseract OCR |
| **容器 / 編排** | Docker、Docker Compose、Kubernetes（kubeadm、containerd） |
| **CI/CD** | GitHub Actions、GHCR、GitHub Pages、SonarQube |
| **監控** | Prometheus、Grafana、Zipkin、Micrometer、Spring Boot Actuator |
| **測試** | JUnit 5、Mockito、Testcontainers、Reactor Test、Vitest、Testing Library |
