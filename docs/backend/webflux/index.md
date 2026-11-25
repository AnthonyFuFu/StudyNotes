---
icon: lucide/waves
---

# Spring WebFlux

Spring 的非阻塞、反應式 Web 框架。用少量執行緒處理大量「正在等待 I/O」的連線，特別適合串流、長連線與閘道。

**核心技術**：Reactor（Mono / Flux）/ 背壓 / Netty / R2DBC / WebClient / WebSocket / HLS

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Spring WebFlux"])
    c0["01 · 反應式程式設計原理"]
    R --> c0
    p0("・兩種並發模型<br>・Reactive Streams 規範<br>・Mono 與 Flux<br>・最大陷阱：在 Event Loop 上阻塞<br>・什麼時候該用 WebFlux")
    c0 --- p0
    c1["02 · WebFlux、R2DBC 與 WebClient"]
    R --> c1
    p1("・兩種撰寫端點的方式<br>・R2DBC：反應式關聯式資料庫<br>・WebClient：非阻塞 HTTP 客戶端<br>・測試：StepVerifier<br>・設定重點")
    c1 --- p1
    c2["03 · 實戰：直播與影片串流"]
    R --> c2
    p2("・直播串流架構<br>・直播聊天室：Sinks 廣播<br>・影片點播：HTTP Range 請求<br>・行情資料：外部 API 整合")
    c2 --- p2
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2 chapter
    class p0,p1,p2 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 反應式程式設計原理](reactive.md)__

    ---

    兩種並發模型 · Reactive Streams 規範 · Mono 與 Flux · 最大陷阱：在 Event Loop 上阻塞 …

-   __[02 · WebFlux、R2DBC 與 WebClient](webflux-r2dbc.md)__

    ---

    兩種撰寫端點的方式 · R2DBC：反應式關聯式資料庫 · WebClient：非阻塞 HTTP 客戶端 · 測試：StepVerifier …

-   __[03 · 實戰：直播與影片串流](practice-streaming.md)__

    ---

    直播串流架構 · 直播聊天室：Sinks 廣播 · 影片點播：HTTP Range 請求 · 行情資料：外部 API 整合

</div>

## 優點與缺點

| ✅ 優點 | ❌ 缺點 |
|--------|--------|
| 少量執行緒撐起數萬並發連線 | 學習曲線陡，思維要從「步驟」改成「資料流」 |
| 天生支援串流與背壓 | 堆疊追蹤被切碎，除錯困難 |
| `zip`、`timeout`、`retry` 讓並行與容錯很簡潔 | 整條鏈都要非阻塞，JPA 與許多 SDK 不能用 |
| Spring Cloud Gateway 的基礎 | ThreadLocal 失效，MDC、交易上下文要改用 Context |

!!! tip "MVC 還是 WebFlux？"

    一般業務系統：**Spring MVC + Java 21 虛擬執行緒**。真正需要串流、背壓、大量長連線（直播聊天室、影片代理、即時報價）時才選 WebFlux。

!!! example "我的實作：stock-observation"

    Spring Boot 4 + WebFlux + R2DBC（PostgreSQL / H2）：台股（TWSE / TPEx）與美股（Finnhub）行情、概念股多對多分類、MediaMTX 直播（RTMP → HLS）與 WebSocket 聊天室、HTTP Range 影片點播。
