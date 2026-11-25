---
icon: lucide/plug
---

# API 設計與通訊協議

RESTful 設計規範，以及 gRPC、WebSocket、GraphQL 各自的適用場景與 Spring Boot 實作。

**核心技術**：RESTful / gRPC / WebSocket / GraphQL

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · RESTful API 設計最佳實踐](restful.md)__

    ---

    REST 設計六大原則 · URI 設計規範 · HTTP 方法與冪等性 · HTTP Status Code 完整規範 · 統一響應格式 …

-   __[02 · gRPC](grpc.md)__

    ---

    核心原理 · Protobuf 定義 · Spring Boot 整合 gRPC · gRPC vs REST 對比

-   __[03 · WebSocket](websocket.md)__

    ---

    WebSocket 原理 · Spring Boot 整合

-   __[04 · GraphQL](graphql.md)__

    ---

    核心概念 · Spring Boot 整合 GraphQL · GraphQL vs REST 比較

</div>

??? abstract "原始學習路線圖"

    ```
    API 設計與通訊協議
    ├── 1️⃣ RESTful API 設計最佳實踐
    │   ├── REST 設計原則
    │   ├── HTTP 方法與冪等性
    │   ├── HTTP Status Code
    │   ├── API 版本管理
    │   ├── 統一響應格式
    │   └── API 安全設計
    ├── 2️⃣ gRPC（高效能 RPC 框架）
    │   ├── 核心原理與 Protobuf
    │   ├── 四種通訊模式
    │   ├── Spring Boot 整合
    │   └── gRPC vs REST 比較
    ├── 3️⃣ WebSocket（即時通訊）
    │   ├── WebSocket 原理
    │   ├── Spring Boot 整合（STOMP）
    │   └── 聊天室實戰
    └── 4️⃣ GraphQL（靈活查詢語言）
        ├── 核心概念（Query / Mutation / Subscription）
        ├── Spring Boot 整合
        └── GraphQL vs REST 比較
    ```

## 重點速覽

### RESTful 設計規範

| HTTP 方法 | 用途 | 冪等性 | 成功 Status |
|----------|------|-------|------------|
| GET | 查詢 | ✅ | 200 OK |
| POST | 新增 | ❌ | 201 Created |
| PUT | 完整更新 | ✅ | 200 OK |
| PATCH | 部分更新 | ❌ | 200 OK |
| DELETE | 刪除 | ✅ | 204 No Content |

### 通訊協議選型

```
對外公開 API     → RESTful（可讀性高，瀏覽器友好）
微服務內部通訊   → gRPC（Protobuf 二進制，比 REST 快 5~10 倍）
即時推播 / 聊天  → WebSocket（持久雙向連接）
複雜前端數據需求 → GraphQL（客戶端精確指定需要的欄位）
```

### gRPC 四種通訊模式

| 模式 | 說明 | 適用場景 |
|------|------|---------|
| Unary | 單請求 / 單響應 | 一般 CRUD 操作 |
| Server Streaming | 單請求 / 多響應 | 訂單狀態監聽 |
| Client Streaming | 多請求 / 單響應 | 批量數據上傳 |
| Bidirectional Streaming | 雙向流 | 即時協作 / 聊天 |

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **REST 設計** | 名詞 URI、HTTP 方法語義、正確 Status Code |
| **冪等性** | GET/PUT/DELETE 冪等，POST 不冪等，用 Idempotency-Key |
| **統一響應** | ApiResponse<T> 包含 success/code/message/data/traceId |
| **異常處理** | @RestControllerAdvice 全局處理，不暴露系統內部資訊 |
| **API 版本** | URI 版本（/v1/）最清晰，舊版本維護後棄用 |
| **gRPC** | Protobuf 二進制協議，HTTP/2，比 REST 快 5\~10 倍 |
| **gRPC 模式** | Unary / Server Streaming / Client Streaming / 雙向流 |
| **WebSocket** | 持久雙向連接，一次握手，服務器主動推送 |
| **STOMP** | WebSocket 上層協議，支援 topic 廣播和 queue 點對點 |
| **GraphQL** | 客戶端精確取需要的欄位，解決 Over/Under-fetching |
| **DataLoader** | 批量加載解決 GraphQL N+1 問題 |
| **選擇建議** | 對外公開 API → REST；微服務內部 → gRPC；即時推送 → WebSocket；複雜前端 → GraphQL |
