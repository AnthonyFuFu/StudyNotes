# DNS 解析流程

## 完整解析過程

```
瀏覽器輸入 www.example.com 的解析過程：

① 瀏覽器快取
   有快取 → 直接用
   沒有 → 繼續

② 作業系統快取（/etc/hosts 文件）
   有記錄 → 直接用
   沒有 → 繼續

③ 本地 DNS 解析器（通常是路由器或 ISP 的 DNS）
   有快取 → 直接回應
   沒有 → 開始遞迴查詢

④ 查詢根域名服務器（Root DNS Server）
   問："誰管 .com？"
   → 返回 .com TLD 服務器的地址

⑤ 查詢 TLD 服務器（Top-Level Domain）
   問："誰管 example.com？"
   → 返回 example.com 的權威 DNS 服務器地址

⑥ 查詢權威 DNS 服務器（Authoritative DNS）
   問："www.example.com 的 IP 是多少？"
   → 返回 IP 地址（如 93.184.216.34）

⑦ 本地 DNS 解析器快取結果（根據 TTL）
   → 返回給客戶端

⑧ 瀏覽器快取 → 建立 TCP 連接 → 發送 HTTP 請求

全程時間：通常 < 100ms（快取命中時 < 1ms）

DNS 記錄類型：
  A     → 域名 → IPv4 地址
  AAAA  → 域名 → IPv6 地址
  CNAME → 域名 → 另一個域名（別名）
  MX    → 郵件服務器地址
  TXT   → 文字記錄（SPF / DKIM / 域名驗證）
  NS    → 名稱服務器

TTL（Time To Live）：
  DNS 記錄的快取有效期
  短 TTL（60s）→ 改 IP 時快速生效，但查詢頻繁
  長 TTL（86400s = 1天）→ 查詢少，但改 IP 時需等較長時間生效

DNS 負載均衡：
  同一個域名配置多個 A 記錄（不同 IP）
  DNS 輪詢返回不同 IP → 達到簡單的負載均衡
  缺點：不考慮服務器健康狀態
```
