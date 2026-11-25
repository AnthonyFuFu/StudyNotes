# CDN 原理

## CDN 架構與工作流程

```
CDN（Content Delivery Network）內容分發網路

問題：
  用戶在台灣，服務器在美國
  → 每次請求都要跨越太平洋，延遲高（100ms+）

CDN 解決方式：
  在全球各地部署「邊緣節點」（Edge Node / POP）
  靜態資源快取到距用戶最近的節點
  用戶請求 → 就近的邊緣節點回應 → 延遲低（10ms 以內）

CDN 請求流程：

① 用戶瀏覽器請求 static.example.com/image.jpg
② DNS 查詢 → CDN 廠商的 GSLB（全球負載均衡）
③ GSLB 根據用戶 IP 地理位置，返回最近邊緣節點的 IP
④ 瀏覽器請求最近的邊緣節點

  快取命中（Cache Hit）：
  邊緣節點有快取 → 直接返回（毫秒級）

  快取未命中（Cache Miss）：
  邊緣節點 → 回源（Origin Server 源站）→ 取得資源
  → 快取到邊緣節點 → 返回給用戶
  下次相同請求 → 直接從邊緣節點返回

CDN 適合的資源：
  ✅ 靜態資源：圖片 / 視頻 / JS / CSS / 字型
  ✅ 大文件下載（軟體安裝包）
  ❌ 動態 API 響應（每次結果不同，無法快取）
  ❌ 用戶個人化內容（購物車 / 訂單狀態）
```

## CDN 快取策略

```
快取控制（Cache-Control Header）：
  Cache-Control: public, max-age=31536000, immutable
  → 公開快取（CDN 可以快取）
  → 快取 1 年
  → immutable：資源不會改變，瀏覽器不需要驗證

版本化資源（避免快取污染）：
  ❌ /static/app.js         → 更新後用戶可能拿到舊版本
  ✅ /static/app.abc123.js  → Hash 值隨內容改變
                               → 內容改變 → URL 改變 → CDN 重新快取

CDN 快取清除（Cache Purge / Invalidation）：
  當源站資源更新時，需要清除 CDN 快取
  ① 手動 Purge（CDN 控制台 / API）
  ② URL 版本化（最優雅，不需要 Purge）
  ③ 設定短 TTL（簡單但增加回源頻率）

CDN 安全功能：
  DDoS 防護    → 流量在 CDN 節點被過濾吸收
  WAF          → Web 應用防火牆（SQL 注入 / XSS 過濾）
  HTTPS 加速  → CDN 在邊緣節點終止 TLS，減少 TLS 握手次數
  IP 封鎖      → 封鎖惡意 IP

知名 CDN 廠商：
  Cloudflare / AWS CloudFront / Akamai
  阿里雲 CDN / 騰訊雲 CDN
```
