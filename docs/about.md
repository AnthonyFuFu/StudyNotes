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

=== "後端"

    - Java 17 / 21（Virtual Threads / Record / Sealed Class）
    - Spring Boot 3 / 4（MVC、WebFlux）、Spring Cloud、Spring Security
    - C# / .NET 8：ASP.NET Core MVC、Razor Pages、EF Core
    - Spring Data JPA / JdbcTemplate / R2DBC

=== "前端"

    - Vue 2 / 3（Router、Vuex）、React 19、Angular 21（SSR、Signals）
    - TypeScript、Thymeleaf、Razor（.cshtml）、jQuery
    - Ant Design、Angular Material、Tailwind CSS
    - Electron 桌面應用

=== "資料 & 訊息"

    - MySQL 8 / MariaDB、PostgreSQL、SQL Server、SQLite
    - Redis（Lua Script / 分散式鎖 / 高併發搶票）
    - OpenSearch / Elasticsearch、Logstash
    - Apache Kafka（Avro）、RabbitMQ

=== "DevOps & 監控"

    - Docker / Docker Compose、Kubernetes（kubeadm 自建叢集）、Helm
    - GitHub Actions、Jenkins、GHCR、GitHub Pages、SonarQube
    - **Harbor** 私有映像倉庫、**Argo CD** GitOps 部署（公司使用）
    - **AWS**：S3、EC2、EKS、RDS 等（公司使用）
    - Prometheus + Grafana、Zipkin、Micrometer

=== "整合 & 其他"

    - AWS S3（分片上傳）、Azure OpenAI、Azure AI Vision、Tesseract OCR
    - WebSocket（STOMP）、MediaMTX 直播（RTMP / HLS）
    - iText PDF、Apache POI、SheetJS
    - Python 爬蟲（pandas、BeautifulSoup）

## 專案作品

<div class="grid cards" markdown>

-   __holidayDessert__

    ---

    甜點電商暨會員票券管理系統。Spring Boot 3.5 + Thymeleaf，Redis Lua 四層防護高併發搶票、Kafka 非同步訂單、STOMP 客服聊天室、Google OAuth2 + JWT、OpenSearch、S3、Azure OpenAI。

    [高併發搶票](backend/spring-boot/practice-seckill.md) · [即時通訊](architecture/api-design/realtime-streaming.md)

-   __holiday_dessert_vue__

    ---

    holidayDessert 前台的 Vue 3 SPA 版本，與後端分開部署，STOMP 即時客服。

    [Vue 3 前後端分離](frontend/vue/vue3-spa.md)

-   __stock-observation__

    ---

    Spring Boot 4 WebFlux 股票觀測與直播平台：台股 / 美股行情、概念股分類、MediaMTX 直播、HTTP Range 影片串流。

    [直播與影片串流](backend/webflux/practice-streaming.md)

-   __microservicecloud__

    ---

    Spring Cloud 微服務：Eureka 叢集、OpenFeign、Gateway、Resilience4j、Config Server、RabbitMQ、Zipkin、Prometheus，部署到 kubeadm 自建 K8s。

    [微服務與 K8s 部署](backend/spring-cloud/practice.md)

-   __chineseArtwork__

    ---

    ASP.NET Core 8 中華書畫網站：MVC + Razor Pages、Areas 後台、EF Core DB-First、Cookie 驗證，Python 爬取字典資料。

    [ASP.NET Core](backend/aspnet-core/index.md)

-   __chinese_artwork_angular__

    ---

    同主題的 Angular 21 前端：standalone 元件、懶加載路由、SSR + 預渲染、Angular Material + Tailwind。

    [SSR 與 Hydration](frontend/angular/ssr-ui.md)

-   __fu-clan-management-system__

    ---

    傅氏宗親會管理系統：Electron + React 19 + TypeScript + Ant Design，本機 SQLite，三平台自動打包。

    [Electron 桌面應用](frontend/electron/index.md)

-   __AnthonyFu-Learning__

    ---

    Java 後端深度學習筆記的原始專案，也就是本網站的內容來源。

    [Study Notes 首頁](index.md)

</div>

## 學習方法

本筆記採用 **深度優先** 策略，每個主題不只停留在「會用」的層次，而是深入到 **底層原理**，理解「為什麼這樣設計」。

``` mermaid
flowchart LR
    W["Why<br>為什麼需要？<br>解決了什麼問題？"] --> WT["What<br>核心概念<br>與架構"] --> H["How<br>底層是怎麼<br>實作的？"] --> P["Practice<br>如何在專案中<br>正確使用？"] --> PF["Pitfalls<br>常見陷阱與<br>最佳實踐"]
```

!!! quote "持續學習，持續成長 🚀"

    不理解底層原理的工程師，只是在調用 API 而已。
