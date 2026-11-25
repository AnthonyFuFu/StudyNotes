---
icon: lucide/cloud
---

# Spring Cloud 微服務

微服務的核心概念，以及 Spring Cloud Alibaba 生態中註冊配置、服務呼叫、閘道與限流熔斷的實作。

**核心技術**：Nacos / OpenFeign / Gateway / Sentinel / 分散式配置

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
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4 chapter
    class p0,p1,p2,p3,p4 points
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
