# 實戰：直播與影片串流

!!! abstract "本章重點"

    直播、聊天室與影片點播都是長時間佔用連線的場景，正好是 WebFlux 擅長的地方。本章拆解 stock-observation 的 HLS 代理、Reactor Sinks 聊天室廣播，以及 HTTP Range 影片串流。

!!! abstract "專案：stock-observation"

    Spring Boot 4 + WebFlux + R2DBC（PostgreSQL / H2）。同時涵蓋三個領域：台股 / 美股行情資料、**直播串流**（MediaMTX + WebSocket 聊天室）、**影片點播**（HTTP Range 串流）。這三個都是「長時間佔用連線」的場景，正是 WebFlux 擅長的地方。

## 直播串流架構

``` mermaid
flowchart TB
    OBS["OBS / FFmpeg（推流端）"] -- "RTMP :1935" --> MTX["MediaMTX（轉封裝）"]
    MTX -- "HLS :8888" --> APP["Spring WebFlux（LiveStreamController 代理）"]
    APP -- ".m3u8 / .ts" --> B["瀏覽器（hls.js 播放）"]
```

| 協定 | 方向 | 延遲 | 說明 |
|------|------|------|------|
| **RTMP** | 推流（主播 → 伺服器） | 1 \~ 3 秒 | 基於 TCP，OBS、FFmpeg 都支援，但瀏覽器無法直接播放 |
| **HLS** | 拉流（伺服器 → 觀眾） | 6 \~ 30 秒 | 切成 `.ts` 小片段 + `.m3u8` 播放清單，走一般 HTTP，可用 CDN |
| **WebRTC** | 雙向 | < 1 秒 | 點對點、UDP，延遲最低但架設最複雜 |

**為什麼要由 Spring 代理 HLS？** 統一入口與網域（避免 CORS）、之後可以在代理層加上權限驗證與觀看人數統計。

``` java
@GetMapping("/{roomId}/index.m3u8")
public Mono<Void> getPlaylist(@PathVariable String roomId, ServerHttpResponse response) {
    // 以 WebClient 向 MediaMTX 取回播放清單，邊收邊寫回瀏覽器，不在記憶體累積整個檔案
    return liveStreamService.proxy(roomId, "index.m3u8", response);
}
```

## 直播聊天室：Sinks 廣播

每個直播間（`roomId`）有獨立的廣播頻道，用 Reactor 的 **`Sinks.Many`** 實作一對多推送：

``` java
private final Map<String, Sinks.Many<String>> roomSinks = new ConcurrentHashMap<>();

@Override
public Mono<Void> handle(WebSocketSession session) {
    String roomId = extractRoomId(session);           // ws://.../ws/chat?roomId=room001
    Sinks.Many<String> sink = roomSinks.computeIfAbsent(roomId,
            k -> Sinks.many().multicast().onBackpressureBuffer());

    Mono<Void> input = session.receive()              // 收到訊息 → 推進該房間的 Sink
            .map(WebSocketMessage::getPayloadAsText)
            .doOnNext(sink::tryEmitNext)
            .then();

    Mono<Void> output = session.send(                 // 訂閱 Sink → 推給這個連線
            sink.asFlux().map(session::textMessage));

    return Mono.zip(input, output).then();            // 任一方結束（斷線）就結束
}
```

``` mermaid
flowchart LR
    A["觀眾 A 發言"] --> S["Sinks.Many<br>room001"]
    S --> A2["觀眾 A"]
    S --> B["觀眾 B"]
    S --> C["觀眾 C"]
```

!!! info "跟 Servlet WebSocket 的差別"

    WebFlux 的 `WebSocketHandler` 把「收」與「送」都表示成 `Flux`。一萬個觀眾連線**不需要一萬條執行緒**，只是一萬個訂閱者，記憶體用量很低。holidayDessert 的客服聊天室用的是 Servlet 版的 **STOMP over WebSocket**，比較見 [即時通訊與串流](../../architecture/api-design/realtime-streaming.md)。

## 影片點播：HTTP Range 請求

瀏覽器的 `<video>` 拖曳進度條時，會送出 **Range 請求**只要檔案的一部分：

``` mermaid
sequenceDiagram
    participant B as 瀏覽器 video
    participant S as WebFlux
    B->>S: GET /video/local/sample.mp4<br>Range: bytes=1048576-2097151
    S->>B: 206 Partial Content<br>Content-Range: bytes 1048576-2097151/52428800<br>Accept-Ranges: bytes
    Note over B: 使用者拖到 70%
    B->>S: Range: bytes=36700160-
    S->>B: 206 Partial Content（從新位置開始）
```

| 標頭 | 方向 | 意義 |
|------|------|------|
| `Range: bytes=start-end` | 請求 | 只要這個範圍 |
| `206 Partial Content` | 回應 | 回傳部分內容（不是 200） |
| `Content-Range: bytes start-end/total` | 回應 | 回傳的範圍與檔案總大小 |
| `Accept-Ranges: bytes` | 回應 | 告訴瀏覽器支援範圍請求，進度條才能拖 |

**遠端影片代理**：用 `WebClient` 把 Range 標頭原封不動轉給遠端伺服器，再把回應的 `Flux<DataBuffer>` 直接寫回瀏覽器。整個過程**不會把影片載入記憶體**，這就是串流的意義。

``` java
public Mono<Void> streamRemote(String videoUrl, String rangeHeader, ServerHttpResponse response) {
    return buildRemoteRequest(videoUrl, rangeHeader)       // 轉發 Range 標頭
            .exchangeToMono(clientResponse -> {
                copyHeaders(clientResponse, response);     // 206、Content-Range…
                Flux<DataBuffer> body = clientResponse.bodyToFlux(DataBuffer.class);
                return response.writeWith(body);           // 邊收邊寫，背壓自動生效
            });
}
```

## 行情資料：外部 API 整合

- **台股**：TWSE / TPEx 開放資料，一鍵匯入全台上市 + 上櫃股票基本資料
- **美股**：Finnhub API 取得即時報價、K 線、公司資料
- 以 `WebClient` 非阻塞呼叫，`Mono.zip` 同時取得 DB 資料與外部報價

## 學到的事

| 問題 | 解法 |
|------|------|
| 影片串流佔滿記憶體 | 用 `Flux<DataBuffer>` 串流，不要 `byte[]` 讀整個檔案 |
| 斷線後 Sink 沒有清理 | `doFinally` 中扣除觀看人數，房間沒人時移除 Sink |
| AOP 記錄反應式方法耗時不準 | 方法回傳 `Mono` 的瞬間就結束了，要在 `doOnSubscribe` / `doFinally` 計時 |
| 本地開發沒有 PostgreSQL | 切換成 `r2dbc-h2` 記憶體資料庫 |
