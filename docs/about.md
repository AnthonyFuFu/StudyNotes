---
icon: lucide/user-round
---

# 關於我

## 傅勝宏

**全端工程師 ・ 5.5 年經驗**

擁有 5 年半全端開發經驗，熟悉 Java Spring Boot 後端架構與前後端整合，具備獨立交付完整系統的能力。曾執行系統重構與資料庫優化專案，顯著提升系統效能與可維護性。

技術涵蓋後端架構設計、資料庫調優、Docker / Kubernetes 容器化部署、CI/CD 流水線建置與監控系統整合。熱衷研究底層原理，相信理解「為什麼」比學會「怎麼用」更有價值，這份筆記正是這個理念的具體實踐。

具備強烈自學驅動力，持續追蹤技術趨勢並系統性整理成學習成果。溝通清晰、與人為善，擅長跨部門協作，能在技術與業務之間扮演良好橋樑。

!!! tip "求職中"

    目前積極尋求 **半導體 / 金融產業** 全端工程師機會，期待以紮實的技術底蘊與快速學習的能力，為團隊帶來實質貢獻。

![Java](https://img.shields.io/badge/Java-17%20%7C%2021-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.x-6DB33F?style=for-the-badge&logo=springboot&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-7.x-DC382D?style=for-the-badge&logo=redis&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Containerized-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestration-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Elasticsearch](https://img.shields.io/badge/Elasticsearch-8.x-005571?style=for-the-badge&logo=elasticsearch&logoColor=white)
![Kafka](https://img.shields.io/badge/Apache_Kafka-Event_Driven-231F20?style=for-the-badge&logo=apachekafka&logoColor=white)

## 技術棧

=== "語言 & 框架"

    - Java 17 / 21（Virtual Threads / Record / Sealed Class）
    - Spring Boot 3.x / Spring Cloud / Spring Security
    - MyBatis-Plus / Spring Data JPA / Hibernate

=== "資料庫 & 快取"

    - MySQL 8.0（B+樹索引 / MVCC / 主從複製）
    - Redis（快取 / 分散式鎖 / Session / 限流）
    - Elasticsearch 8.x（全文搜索 / ELK 日誌）

=== "消息佇列"

    - Apache Kafka（高吞吐量 / 事件驅動）
    - RabbitMQ（可靠消息傳遞 / 死信佇列）

=== "容器化 & CI/CD"

    - Docker（多階段建置 / 最小化 Image）
    - Kubernetes（Deployment / Service / HPA / Helm）
    - GitHub Actions / Jenkins Pipeline
    - SonarQube / Trivy / Harbor Registry

=== "監控"

    - Prometheus + Grafana（指標）
    - ELK Stack（日誌）
    - SkyWalking（鏈路追蹤）
    - Spring Boot Actuator（應用健康）

=== "API & 測試"

    - RESTful API / gRPC / WebSocket / GraphQL
    - JUnit 5 / Mockito / Testcontainers / TDD / JaCoCo

## 筆記目錄

這份筆記系統性整理 Java 後端核心知識體系，共 17 個主題。每個主題首頁都有學習地圖、章節導覽與重點速覽。

| # | 主題 | 核心技術 |
|---|------|---------|
| 01 | [系統設計](architecture/system-design/index.md) | CAP / BASE / 分散式事務 / 限流熔斷 / 分庫分表 |
| 02 | [Java 新特性](java/new-features/index.md) | Virtual Threads / Record / Sealed Class / Pattern Matching |
| 03 | [JVM 深度原理](java/jvm/index.md) | 記憶體模型 / GC / 類加載 / JMM / 性能調優 |
| 04 | [資安](network-security/security/index.md) | Spring Security / OAuth2 / JWT / SSO / 攻擊防禦 |
| 05 | [CI/CD 與 DevOps](engineering/cicd/index.md) | Docker / Kubernetes / Jenkins / GitHub Actions / Helm |
| 06 | [監控與可觀測性](engineering/monitoring/index.md) | Prometheus / Grafana / ELK / SkyWalking / SLO |
| 07 | [MySQL 深度優化](data/mysql/index.md) | B+樹索引 / MVCC / 主從複製 / 分庫分表 / 雪花算法 |
| 08 | [設計模式](architecture/design-pattern/index.md) | GoF 23 種 / SOLID 原則 / Spring 中的應用 |
| 09 | [Elasticsearch](data/elasticsearch/index.md) | 倒排索引 / DSL 查詢 / 聚合 / ELK Stack |
| 10 | [API 設計與通訊協議](architecture/api-design/index.md) | RESTful / gRPC / WebSocket / GraphQL |
| 11 | [測試](engineering/testing/index.md) | JUnit 5 / Mockito / Testcontainers / TDD |
| 12 | [Java 並發](java/concurrency/index.md) | Thread / synchronized / AQS / 線程池 / CompletableFuture |
| 13 | [Redis 深度](data/redis/index.md) | 資料結構底層 / 持久化 / 分散式鎖 / 緩存問題 / Cluster |
| 14 | [演算法與資料結構](fundamentals/algorithm/index.md) | 雙指針 / 滑動視窗 / 鏈表 / 樹 / DP / 排序 |
| 15 | [Spring Cloud 微服務](architecture/spring-cloud/index.md) | Nacos / OpenFeign / Gateway / Sentinel / 分散式配置 |
| 16 | [網路基礎](network-security/network/index.md) | TCP / HTTP / HTTPS / DNS / CDN |
| 17 | [前端深度](fundamentals/frontend/index.md) | React / Vue 原理 / 效能優化 / TypeScript |

## 學習方法

本筆記採用 **深度優先** 策略，每個主題不只停留在「會用」的層次，而是深入到 **底層原理**，理解「為什麼這樣設計」。

``` mermaid
flowchart LR
    W["Why<br>為什麼需要？<br>解決了什麼問題？"] --> WT["What<br>核心概念<br>與架構"] --> H["How<br>底層是怎麼<br>實作的？"] --> P["Practice<br>如何在專案中<br>正確使用？"] --> PF["Pitfalls<br>常見陷阱與<br>最佳實踐"]
```

!!! quote "持續學習，持續成長 🚀"

    不理解底層原理的工程師，只是在調用 API 而已。
