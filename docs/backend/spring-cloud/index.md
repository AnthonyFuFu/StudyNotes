---
icon: lucide/cloud
---

# Spring Cloud 微服務

微服務的核心概念與各元件原理：先以 Spring Cloud Alibaba（Nacos、Sentinel）說明，再對照我實作的 Spring Cloud 官方 / Netflix 系（Eureka、Resilience4j、Config Server），最後部署到自建的 Kubernetes 叢集。

**核心技術**：Eureka / Nacos / OpenFeign / Gateway / Resilience4j / Sentinel / Config Server / RabbitMQ / Zipkin / K8s

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Spring Cloud 微服務"])
    c0["01 · 微服務核心概念"]
    R --> c0
    p0("・單體 vs 微服務<br>・Spring Cloud 生態全覽")
    c0 --- p0
    c1["02 · Nacos"]
    R --> c1
    p1("・服務發現（Service Registry）<br>・配置中心（Config Center）")
    c1 --- p1
    c2["03 · OpenFeign（聲明式 HTTP 客戶端）"]
    R --> c2
    p2("・基本使用<br>・攔截器 / 超時 / 重試<br>・整合 Sentinel 熔斷")
    c2 --- p2
    c3["04 · Spring Cloud Gateway"]
    R --> c3
    p3("・路由（Route）<br>・斷言（Predicate）<br>・過濾器（Filter）<br>・限流 / 認證 / 灰度發布")
    c3 --- p3
    c4["05 · Sentinel（限流 / 熔斷 / 降級）"]
    R --> c4
    p4("・核心概念<br>・流量控制規則<br>・熔斷降級規則<br>・Spring Boot 整合")
    c4 --- p4
    c5["06 · 元件選型：Spring Cloud 與 Alibaba 對照"]
    R --> c5
    p5("・Eureka vs Nacos<br>・Resilience4j vs Sentinel<br>・Config Server vs Nacos Config")
    c5 --- p5
    c6["07 · 實戰：微服務專案與 K8s 部署"]
    R --> c6
    p6("・Eureka 叢集 + OpenFeign + Gateway<br>・Resilience4j 熔斷降級<br>・RabbitMQ 事件 + Zipkin + Prometheus<br>・Docker Compose → kubeadm K8s")
    c6 --- p6
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5,c6 chapter
    class p0,p1,p2,p3,p4,p5,p6 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 微服務核心概念](microservices.md)__

    ---

    單體 vs 微服務 · Spring Cloud 生態全覽

-   __[02 · Nacos](nacos.md)__

    ---

    服務發現 · 配置中心

-   __[03 · OpenFeign](openfeign.md)__

    ---

    基本使用 · 攔截器 / 超時 / 重試

-   __[04 · Spring Cloud Gateway](gateway.md)__

    ---

    核心架構 · 灰度發布

-   __[05 · Sentinel](sentinel.md)__

    ---

    核心概念

-   __[06 · 元件選型：Spring Cloud 與 Alibaba 對照](ecosystem-comparison.md)__

    ---

    元件對照 · 註冊中心 · 容錯 · 設定中心 · 怎麼選

-   __[07 · 實戰：微服務專案與 K8s 部署](practice.md)__

    ---

    架構總覽 · Gateway 路由 · OpenFeign 降級 · RabbitMQ 事件 · 部署演進

</div>

## 核心要點總結

| 組件 | 核心功能 | 關鍵設定 |
|------|---------|---------|
| **Nacos 服務發現** | 服務註冊 / 發現 / 健康檢查 | server-addr / namespace |
| **Nacos 配置中心** | 統一配置 / 動態刷新 | @RefreshScope / bootstrap.yml |
| **OpenFeign** | 聲明式 HTTP 客戶端 | @FeignClient / 攔截器傳遞 Token |
| **Gateway** | 路由 / 認證 / 限流 / 跨域 | 全局 Filter / KeyResolver |
| **Sentinel 限流** | QPS / 並發數控制 | FlowRule |
| **Sentinel 熔斷** | 錯誤率 / 慢響應率控制 | DegradeRule |
| **Sentinel 降級** | 異常時返回預設值 | @SentinelResource fallback |
| **灰度發布** | Header 路由到新版本 | Predicate + 多路由 |
