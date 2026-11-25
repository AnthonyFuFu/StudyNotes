# 即時通訊與串流

伺服器要「主動」把資料推給瀏覽器時，HTTP 一問一答的模式就不夠用了。我在不同專案用過三種做法：**STOMP over WebSocket**（holidayDessert 客服）、**原生 WebSocket + Reactor**（stock-observation 直播聊天室）、**HLS / HTTP Range**（直播與影片串流）。

## 推送技術比較

| 技術 | 方向 | 協定 | 適合 |
|------|------|------|------|
| 輪詢（Polling） | 瀏覽器定時問 | HTTP | 更新頻率低、最簡單 |
| 長輪詢（Long Polling） | 伺服器有資料才回應 | HTTP | 舊瀏覽器相容 |
| **SSE**（Server-Sent Events） | 伺服器 → 瀏覽器（單向） | HTTP，`text/event-stream` | 即時報價、通知、AI 逐字輸出 |
| **WebSocket** | 雙向 | `ws://`、`wss://` | 聊天室、協作、遊戲 |
| **HLS** | 伺服器 → 瀏覽器 | HTTP 分段檔案 | 直播、大量觀眾 |
| **WebRTC** | 點對點雙向 | UDP | 視訊通話、超低延遲直播 |

## WebSocket 握手

``` mermaid
sequenceDiagram
    participant B as 瀏覽器
    participant S as 伺服器
    B->>S: GET /ws-chat HTTP/1.1<br>Upgrade: websocket<br>Sec-WebSocket-Key: ...
    S->>B: 101 Switching Protocols<br>Sec-WebSocket-Accept: ...
    Note over B,S: 之後同一條 TCP 連線上雙向傳送訊框（frame）
    B->>S: 訊息
    S->>B: 推送
```

## STOMP 與原生 WebSocket

原生 WebSocket 只負責「傳送訊框」，沒有規定訊息格式與路由。**STOMP** 是建立在 WebSocket 上的**訊息協定**，加上了目的地（destination）、訂閱、標頭的概念。

=== "STOMP（holidayDessert 客服）"

    ``` java
    @Configuration
    @EnableWebSocketMessageBroker
    public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
        @Override
        public void registerStompEndpoints(StompEndpointRegistry registry) {
            registry.addEndpoint("/ws-chat")
                    .setAllowedOrigins(AllowedOrigin.OFFICAIL_ARRAY)  // 明確指定允許的來源，不用 "*"
                    .withSockJS();                                    // SockJS：不支援 WebSocket 時降級
        }
        @Override
        public void configureMessageBroker(MessageBrokerRegistry config) {
            config.enableSimpleBroker("/topic", "/queue");            // 廣播 /topic/**、個人 /user/queue/**
            config.setApplicationDestinationPrefixes("/app");         // 前端送到 /app/** → @MessageMapping
        }
    }
    ```

    ``` java
    // 示意：Controller 接收訊息
    @MessageMapping("/chat/{roomUrl}")
    public void send(@DestinationVariable String roomUrl, ChatMessage msg, Principal user) {
        chatService.save(roomUrl, msg);                                   // 先存檔
        messagingTemplate.convertAndSend("/topic/chat/" + roomUrl, msg);  // 存檔成功才廣播
    }
    ```

=== "原生 WebSocket + Reactor（stock-observation）"

    ``` java
    private final Map<String, Sinks.Many<String>> roomSinks = new ConcurrentHashMap<>();

    public Mono<Void> handle(WebSocketSession session) {
        Sinks.Many<String> sink = roomSinks.computeIfAbsent(roomId,
                k -> Sinks.many().multicast().onBackpressureBuffer());
        Mono<Void> input = session.receive().map(WebSocketMessage::getPayloadAsText)
                .doOnNext(sink::tryEmitNext).then();
        Mono<Void> output = session.send(sink.asFlux().map(session::textMessage));
        return Mono.zip(input, output).then();
    }
    ```

| | STOMP（Spring MVC） | 原生 WebSocket（WebFlux） |
|---|---------------------|--------------------------|
| 訊息路由 | ✅ destination、`@MessageMapping` | 自己解析 |
| 訂閱 / 廣播 | ✅ 內建 `/topic` | 自己用 `Sinks` 實作 |
| 只發給特定使用者 | ✅ `/user/queue/...` | 自己維護 session 對照表 |
| 降級 | ✅ SockJS | ❌ |
| 執行緒 | 每個連線佔用資源較多 | Event Loop，極少執行緒 |
| 適合 | 業務型聊天、通知 | 大量連線、高頻推送 |

## holidayDessert 客服聊天室的設計

| 需求 | 做法 |
|------|------|
| 每位會員只有一間聊天室 | `chat_room.MEM_ID` 設 **UNIQUE**，第一次開啟時建立（get-or-create）；並發建立撞到 UNIQUE 時改為查詢既有房間 |
| 房間代碼安全 | 使用 **UUID**，避免出現 `/` 等會破壞 STOMP 路徑的字元 |
| 客服認領 | 後台點選房間即寫入 `chat_room.EMP_ID`，先點的人負責 |
| 訊息不遺失 | 後端**存檔成功後才廣播** |
| 錯誤只通知本人 | 發送失敗時送到 `/user/queue/errors` |

!!! warning "多台伺服器時的問題"

    `enableSimpleBroker` 是**記憶體內**的 Broker，只有連到同一台伺服器的使用者收得到彼此的訊息。水平擴展時要改用 `enableStompBrokerRelay` 接 RabbitMQ / ActiveMQ，或用 Redis Pub/Sub 在多台之間轉發。

## 影音串流

| 技術 | 原理 | 我的使用 |
|------|------|---------|
| **HTTP Range** | 瀏覽器只要檔案的一段 `bytes=start-end`，伺服器回 `206 Partial Content` | 影片點播、拖曳進度條 |
| **HLS** | 影片切成數秒一段的 `.ts`，`.m3u8` 播放清單列出片段，播放器依序下載 | 直播觀看端 |
| **RTMP** | 長連線推送音視訊串流 | OBS / FFmpeg 推流到 MediaMTX |

詳細實作見 [WebFlux 實戰：直播與影片串流](../../backend/webflux/practice-streaming.md)。
