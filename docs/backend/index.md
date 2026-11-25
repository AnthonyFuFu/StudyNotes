---
icon: lucide/server
---

# 後端框架

我實作過的四種後端框架：Servlet 模型的 Spring Boot、反應式的 WebFlux、微服務的 Spring Cloud，以及 .NET 的 ASP.NET Core。每個框架都說明原理、優缺點與實際專案。

<div class="grid cards" markdown>

-   __[Spring Boot（MVC）](spring-boot/index.md)__

    ---

    Java 後端最主流的框架。這個主題從 IoC、自動配置、AOP 代理講到請求處理流程與交易，最後以 holidayDessert 的高併發搶票系統做完整實戰。

    `5 章` · IoC / 自動配置 / AOP / DispatcherServlet / JPA / @Transactional / Redis Lua

-   __[Spring WebFlux](webflux/index.md)__

    ---

    Spring 的非阻塞、反應式 Web 框架。用少量執行緒處理大量「正在等待 I/O」的連線，特別適合串流、長連線與閘道。

    `3 章` · Reactor（Mono / Flux）/ 背壓 / Netty / R2DBC / WebClient / WebSocket / HLS

-   __[Spring Cloud 微服務](spring-cloud/index.md)__

    ---

    微服務的核心概念與各元件原理：先以 Spring Cloud Alibaba（Nacos、Sentinel）說明，再對照我實作的 Spring Cloud 官方 / Netflix 系（Eureka、Resilience4j、Config Server），最後部署到自建的 Kubernetes 叢集。

    `7 章` · Eureka / Nacos / OpenFeign / Gateway / Resilience4j / Sentinel / Config Server / RabbitMQ / Zipkin / K8s

-   __[ASP.NET Core](aspnet-core/index.md)__

    ---

    微軟的跨平台 Web 框架（.NET 8 LTS）。從 Spring Boot 的角度對照學習：中介軟體管線、DI 生命週期、MVC 與 Razor Pages、EF Core 與 Cookie 驗證。

    `3 章` · .NET 8 / Kestrel / Middleware / DI / MVC / Razor Pages（.cshtml）/ EF Core / Cookie 驗證

</div>

## 框架比較

| | Spring Boot（MVC） | Spring WebFlux | Spring Cloud | ASP.NET Core |
|---|-------------------|----------------|--------------|--------------|
| 定位 | 單體 / 一般 Web 應用 | 非阻塞、串流、長連線 | 微服務治理 | .NET 的 Web 框架 |
| 並發模型 | 每請求一條執行緒（可改虛擬執行緒） | Event Loop | 依各服務 | `async` / `await` |
| 伺服器 | Tomcat | Netty | Tomcat / Netty（Gateway） | Kestrel |
| 資料存取 | JPA、JdbcTemplate、MyBatis | R2DBC | 依各服務 | EF Core |
| 模板 | Thymeleaf | Thymeleaf（reactive） | — | Razor（`.cshtml`） |
| 學習曲線 | 低 | 高 | 高 | 低（有 Spring 經驗時） |

## 我的專案

| 專案 | 框架 | 重點 |
|------|------|------|
| holidayDessert | Spring Boot 3.5（MVC） | 高併發搶票、Kafka、STOMP 客服、OAuth2 + JWT、OpenSearch、S3、Azure OpenAI |
| stock-observation | Spring Boot 4 + WebFlux | R2DBC、直播 HLS 代理、WebSocket 聊天室、HTTP Range 串流 |
| microservicecloud | Spring Cloud | Eureka、OpenFeign、Gateway、Resilience4j、Config、RabbitMQ、K8s |
| chineseArtwork | ASP.NET Core 8 | MVC + Razor Pages、Areas、EF Core DB-First、Cookie 驗證 |
