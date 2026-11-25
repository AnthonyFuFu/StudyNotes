# 元件選型：Spring Cloud 與 Alibaba 生態對照

!!! abstract "本章重點"

    Spring Cloud 的每個能力都有不同實作可選。本章對照官方 / Netflix 系（Eureka、Resilience4j、Config Server）與 Alibaba 系（Nacos、Sentinel）的差異，並給出選型建議。

Spring Cloud 是一套**規範與抽象**，每個能力都有不同的實作可以選。前面章節介紹的是 Spring Cloud Alibaba（Nacos、Sentinel），我在 microservicecloud 實作的則是 Spring Cloud 官方 / Netflix 系（Eureka、Resilience4j、Config Server）。

## 元件對照

| 能力 | Spring Cloud 官方 / Netflix 系 | Spring Cloud Alibaba | 我的選擇 |
|------|-------------------------------|----------------------|---------|
| 服務註冊與發現 | **Eureka**（AP） | **Nacos**（AP / CP 可切換） | Eureka 雙節點叢集 |
| 設定中心 | **Spring Cloud Config**（Git / 本地檔） | Nacos Config | Config Server |
| 熔斷、限流、降級 | **Resilience4j** | **Sentinel** | Resilience4j |
| 負載均衡 | Spring Cloud LoadBalancer | 同左 | LoadBalancer |
| 服務呼叫 | OpenFeign | OpenFeign / Dubbo | OpenFeign |
| API 閘道 | Spring Cloud Gateway | 同左 | Gateway |
| 訊息驅動 | Spring Cloud Stream / Bus | RocketMQ | RabbitMQ |
| 鏈路追蹤 | Micrometer Tracing + Zipkin | SkyWalking | Zipkin |

!!! info "Netflix OSS 的現況"

    Hystrix、Ribbon、Zuul 都已停止維護，被 **Resilience4j**、**Spring Cloud LoadBalancer**、**Spring Cloud Gateway** 取代。目前 Netflix 系還在積極使用的只剩 **Eureka**。

## 註冊中心：Eureka vs Nacos

``` mermaid
flowchart LR
    P["Provider"] -- "註冊 + 每 30 秒心跳" --> E1["Eureka 7001"]
    E1 <-- "peer 互相複製" --> E2["Eureka 7002"]
    C["Consumer"] -- "拉取服務清單<br>本地快取" --> E2
```

| | Eureka | Nacos |
|---|--------|-------|
| CAP | **AP**：網路分區時仍可註冊與查詢，資料可能短暫不一致 | 臨時實例 AP（Distro 協定）、持久實例 CP（Raft） |
| 自我保護 | 短時間大量心跳失敗時**不剔除實例**，避免誤殺 | 有保護閾值 |
| 健康檢查 | 客戶端心跳 | 心跳 + 伺服器端主動探測 |
| 附帶功能 | 只有註冊中心 | 註冊中心 + 設定中心 + 管理介面 |
| 部署 | 就是一個 Spring Boot 應用 | 獨立服務，需要資料庫（叢集模式） |

!!! warning "Eureka 叢集的坑：hostname 不能都是 localhost"

    Eureka 用 `eureka.instance.hostname` 判斷 peer 是不是自己。本機跑兩台時如果 hostname 都是 `localhost`，會被認為是同一台而**跳過同步**。解法是在 hosts 加上 `eureka7001`、`eureka7002` 兩個名稱；Docker / K8s 環境用容器名稱解析就不會有這個問題。

## 容錯：Resilience4j vs Sentinel

``` mermaid
stateDiagram-v2
    direction LR
    CLOSED: CLOSED（正常放行）
    OPEN: OPEN（直接走 fallback）
    HALF: HALF_OPEN（放少量請求探測）
    CLOSED --> OPEN: 失敗率 ≥ 50%
    OPEN --> HALF: 等待 10 秒
    HALF --> CLOSED: 探測成功
    HALF --> OPEN: 探測失敗
```

| | Resilience4j | Sentinel |
|---|--------------|----------|
| 定位 | 輕量函式庫，嵌入應用程式 | 流量控制平台，附 Dashboard |
| 熔斷 | ✅ 失敗率 / 慢呼叫比例 | ✅ 慢呼叫比例 / 異常比例 / 異常數 |
| 限流 | RateLimiter、Bulkhead | ✅ 更豐富：QPS、執行緒數、熱點參數、系統負載 |
| 規則設定 | 設定檔（可放 Config Server） | Dashboard 動態推送，可持久化到 Nacos |
| 函數式組合 | ✅ 裝飾器模式，可疊加 Retry / TimeLimiter / Bulkhead | 註解為主 |
| 適合 | 中小型系統、偏好設定即程式碼 | 大流量、需要即時調整規則的維運團隊 |

**我的 Resilience4j 設定**（放在 Config Server 統一管理）

``` properties
resilience4j.circuitbreaker.configs.default.sliding-window-type=COUNT_BASED
resilience4j.circuitbreaker.configs.default.sliding-window-size=10
resilience4j.circuitbreaker.configs.default.minimum-number-of-calls=5
resilience4j.circuitbreaker.configs.default.failure-rate-threshold=50
resilience4j.circuitbreaker.configs.default.wait-duration-in-open-state=10s
resilience4j.circuitbreaker.configs.default.permitted-number-of-calls-in-half-open-state=3
resilience4j.circuitbreaker.configs.default.automatic-transition-from-open-to-half-open-enabled=true
resilience4j.circuitbreaker.instances.MemberFeignClient.base-config=default
resilience4j.timelimiter.configs.default.timeout-duration=3s
```

意思是：最近 10 次呼叫中（至少要有 5 次），失敗率達 50% 就熔斷；熔斷 10 秒後放 3 個請求探測；每次呼叫最多等 3 秒。

## 設定中心：Config Server vs Nacos Config

| | Spring Cloud Config | Nacos Config |
|---|---------------------|--------------|
| 儲存 | Git 倉庫 / 本地檔案 | 資料庫 |
| 版本控管 | ✅ 天生有 Git 歷史 | 有歷史版本 |
| 動態刷新 | 需要 `/actuator/refresh` 或 Spring Cloud Bus 廣播 | ✅ 長輪詢自動推送 |
| 管理介面 | 無 | ✅ 有 |

## 怎麼選

- **新專案、想少維運一個元件**：Nacos（註冊 + 設定一套搞定）+ Sentinel
- **要完全跟著 Spring 官方、或部署在 K8s**：K8s 本身有 Service 發現與 ConfigMap，可以只保留 Gateway + Resilience4j + OpenFeign
- **學習目的**：兩套都做過一遍，最能理解每個元件解決的問題
