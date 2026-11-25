---
icon: lucide/book-open
---

# Study Notes

系統性整理 Java 後端工程師的核心知識體系：從語言與 JVM 底層、資料儲存、架構設計，到網路資安與工程實踐。每個主題都不只停在「會用」，而是深入到「為什麼這樣設計」。

目前收錄 **6 大分類 · 17 個主題 · 103 個章節**。

## 知識地圖

<div class="grid cards" markdown>

-   __[Java 核心](java/index.md)__

    ---

    Java 語言本身與執行環境：從新版語法特性，到 JVM 的記憶體與 GC，再到多執行緒並發的底層實作。

    [Java 新特性](java/new-features/index.md) · [JVM 深度原理](java/jvm/index.md) · [Java 並發](java/concurrency/index.md)

-   __[資料儲存](data/index.md)__

    ---

    後端系統最常倚賴的三種儲存：關聯式資料庫 MySQL、記憶體快取 Redis、全文搜尋引擎 Elasticsearch。

    [MySQL 深度優化](data/mysql/index.md) · [Redis 深度](data/redis/index.md) · [Elasticsearch](data/elasticsearch/index.md)

-   __[架構設計](architecture/index.md)__

    ---

    從程式碼層級的設計模式，到服務之間的通訊協議、微服務治理，以及整體系統架構的取捨。

    [系統設計](architecture/system-design/index.md) · [設計模式](architecture/design-pattern/index.md) · [Spring Cloud 微服務](architecture/spring-cloud/index.md) · [API 設計與通訊協議](architecture/api-design/index.md)

-   __[網路與資安](network-security/index.md)__

    ---

    網路協議是所有服務溝通的基礎，資安則是每一個對外系統都必須守住的底線。

    [網路基礎](network-security/network/index.md) · [資安](network-security/security/index.md)

-   __[工程實踐](engineering/index.md)__

    ---

    讓程式碼可靠地交付到生產環境並持續運作：自動化測試、CI/CD 流水線、監控與可觀測性。

    [測試](engineering/testing/index.md) · [CI/CD 與 DevOps](engineering/cicd/index.md) · [監控與可觀測性](engineering/monitoring/index.md)

-   __[演算法與前端](fundamentals/index.md)__

    ---

    工程師的基本功與全端視野：演算法與資料結構，以及現代前端框架的運作原理。

    [演算法與資料結構](fundamentals/algorithm/index.md) · [前端深度](fundamentals/frontend/index.md)

</div>

## 學習方法

每個主題都依照同一條路徑展開：

| 步驟 | 問題 |
|------|------|
| **Why** | 為什麼需要這個技術？解決了什麼問題？ |
| **What** | 核心概念與架構是什麼？ |
| **How** | 底層是怎麼實作的？ |
| **Practice** | 如何在實際專案中正確使用？ |
| **Pitfalls** | 有哪些常見陷阱和最佳實踐？ |

!!! quote ""

    不理解底層原理的工程師，只是在調用 API 而已。

## 技術棧總覽

| 領域 | 技術 |
|------|------|
| **語言 & 框架** | Java 17 / 21（Virtual Threads / Record / Sealed Class）<br>Spring Boot 3.x / Spring Cloud / Spring Security<br>MyBatis-Plus / Spring Data JPA / Hibernate |
| **資料庫 & 快取** | MySQL 8.0（B+樹索引 / MVCC / 主從複製）<br>Redis（快取 / 分散式鎖 / Session / 限流）<br>Elasticsearch 8.x（全文搜索 / ELK 日誌） |
| **消息佇列** | Apache Kafka（高吞吐量 / 事件驅動）<br>RabbitMQ（可靠消息傳遞 / 死信佇列） |
| **容器化 & 編排** | Docker（多階段建置 / 最小化 Image）<br>Kubernetes（Deployment / Service / HPA / Helm） |
| **CI/CD** | GitHub Actions / Jenkins Pipeline<br>SonarQube / Trivy / Harbor Registry |
| **監控** | Prometheus + Grafana（指標）<br>ELK Stack（日誌）<br>SkyWalking（鏈路追蹤）<br>Spring Boot Actuator（應用健康） |
| **API 通訊** | RESTful API / gRPC / WebSocket / GraphQL |
| **測試** | JUnit 5 / Mockito / Testcontainers / TDD / JaCoCo |
| **---** |  |
