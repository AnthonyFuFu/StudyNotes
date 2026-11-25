# HTTP 協議演進

## HTTP 各版本對比

**HTTP 1.0（1996）**

- 每次請求建立新的 TCP 連接，請求完成後斷開
- ❌ 每次都要三次握手，開銷大
- ❌ 無法並行請求

**HTTP 1.1（1997，目前最廣泛）**

- ✅ Keep-Alive：TCP 連接可複用（預設開啟）
- ✅ Pipeline：可以連續發多個請求，不等回應
- ❌ 隊頭阻塞（Head-of-Line Blocking）：
    - 雖然可以發多個請求，但響應必須按順序返回
    - 第一個請求很慢 → 後面的請求都要等
- ❌ Header 每次都要完整發送（無壓縮）
- ❌ 只支援請求-響應模式（服務器不能主動推送）

**HTTP 2.0（2015）**

- ✅ 多路複用（Multiplexing）：
    - 一個 TCP 連接，多個 Stream 並行傳輸
    - 每個 HTTP 請求是一個 Stream
    - Stream 之間互不阻塞（徹底解決隊頭阻塞！）
- ✅ Header 壓縮（HPACK 算法）：
    - 首次發送完整 Header，之後只發差異部分
- ✅ Server Push：
    - 服務器可以主動推送資源（如 HTML 請求時順帶推送 CSS/JS）
- ✅ 二進位格式：比 1.x 的文本格式更高效
- ❌ 底層還是 TCP，TCP 層的隊頭阻塞仍存在
    - （一個 TCP 包丟失 → 所有 Stream 都要等重傳）

**HTTP 3.0（2022，基於 QUIC）**

- ✅ 底層換成 UDP + QUIC（Quick UDP Internet Connections）
- ✅ 徹底解決 TCP 層的隊頭阻塞
    - 每個 Stream 獨立，一個 Stream 的丟包不影響其他 Stream
- ✅ 0-RTT / 1-RTT 握手（比 TLS over TCP 更快建連）
- ✅ 連接遷移：網路切換（WiFi → 4G）不需要重建連接
- ❌ 基於 UDP，某些防火牆/中間件會屏蔽
- ❌ 部署複雜，普及率仍在提升中

## HTTP 狀態碼快速記憶

``` text
1xx  資訊性     100 Continue
2xx  成功       200 OK / 201 Created / 204 No Content
3xx  重定向     301 永久 / 302 臨時 / 304 Not Modified
4xx  客戶端錯誤  400 Bad Request / 401 未認證 / 403 無權限
                404 Not Found / 429 Too Many Requests
5xx  服務器錯誤  500 Internal Error / 502 Bad Gateway
                503 Service Unavailable / 504 Gateway Timeout
```

## HTTP 常用 Header

**請求 Header**

| 項目 | 說明 |
|------|------|
| Host | 請求的域名（必填） |
| Authorization | 認證（Bearer JWT） |
| Content-Type | 請求體類型（application/json） |
| Accept | 客戶端接受的響應類型 |
| User-Agent | 客戶端資訊 |
| Cache-Control | 快取控制 |
| If-None-Match | ETag 快取驗證 |
| If-Modified-Since | 時間快取驗證 |

**響應 Header**

| 項目 | 說明 |
|------|------|
| Content-Type | 響應體類型 |
| Cache-Control | 快取策略（max-age=3600） |
| ETag | 資源版本標識（用於快取驗證） |
| Last-Modified | 最後修改時間 |
| Location | 重定向地址（201 / 301 / 302） |
| Set-Cookie | 設定 Cookie |
| Access-Control-Allow-Origin | 跨域設定（CORS） |

**快取控制**

| 項目 | 說明 |
|------|------|
| Cache-Control: no-cache | 每次都要驗證（可用快取但要確認） |
| Cache-Control: no-store | 完全不快取 |
| Cache-Control: max-age=3600 | 快取 3600 秒，不需要重新請求 |
| Cache-Control: must-revalidate | 過期後必須重新驗證 |
| ETag: "abc123" | 資源版本號 |
| If-None-Match: "abc123" | 驗證快取是否有效 |
| 304 Not Modified | 快取有效，用本地快取 |

**瀏覽器快取流程**

| 項目 | 說明 |
|------|------|
| 第一次請求 | 服務器返回資源 + ETag |
| 第二次請求 | 帶上 If-None-Match: ETag值 |
| 資源未變動 | 服務器返回 304（無需傳送資源本體，省頻寬！） |
| 資源已變動 | 服務器返回 200 + 新資源 + 新 ETag |
