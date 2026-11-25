---
icon: lucide/globe
---

# 網路基礎

TCP/IP 模型、TCP 握手與可靠傳輸、HTTP 各版本演進、TLS 加密、DNS 與 CDN 的運作方式。

**核心技術**：TCP / HTTP / HTTPS / DNS / CDN

## 學習地圖

``` mermaid
mindmap
  root((網路基礎))
    TCP / IP 模型
      四層 / 七層模型
      各層協議對應
    TCP 深度
      三次握手
      四次揮手
      可靠傳輸機制
      常見面試題
    HTTP 協議演進
      HTTP 1.0 / 1.1 / 2.0 / 3.0
      關鍵差異對比
    HTTPS 與 TLS
      TLS 握手流程
      對稱 vs 非對稱加密
      憑證體系
    DNS 解析流程
    CDN 原理
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · TCP / IP 模型](tcp-ip-model.md)__

    ---

    四層 vs 七層模型對照

-   __[02 · TCP 深度](tcp.md)__

    ---

    三次握手 · 四次揮手 · TCP 可靠傳輸機制 · TCP 面試高頻題

-   __[03 · HTTP 協議演進](http.md)__

    ---

    HTTP 各版本對比 · HTTP 狀態碼快速記憶 · HTTP 常用 Header

-   __[04 · HTTPS 與 TLS](https-tls.md)__

    ---

    對稱加密 vs 非對稱加密 · TLS 1.3 握手流程 · SSL 憑證體系

-   __[05 · DNS 解析流程](dns.md)__

    ---

    完整解析過程

-   __[06 · CDN 原理](cdn.md)__

    ---

    CDN 架構與工作流程 · CDN 快取策略

-   __[07 · 面試題速查](interview.md)__

    ---

    面試題速查

</div>

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **TCP 三次握手** | 確保雙向通訊可靠，不能兩次（無法確認 Server 能發）|
| **TCP 四次揮手** | 全雙工各自關閉，不能三次（半關閉狀態）|
| **TIME_WAIT** | 等待 2MSL 確保 ACK 到達 + 舊報文消失 |
| **TCP vs UDP** | TCP 可靠有序，UDP 快速無序，按場景選擇 |
| **HTTP 1.1** | Keep-Alive 複用連接，但有隊頭阻塞 |
| **HTTP 2.0** | 多路複用解決應用層隊頭阻塞，Header 壓縮 |
| **HTTP 3.0** | 基於 QUIC(UDP)，徹底解決 TCP 層隊頭阻塞 |
| **TLS 握手** | 非對稱加密交換金鑰，對稱加密傳輸資料 |
| **前向保密** | 臨時金鑰（ECDHE），即使私鑰洩漏過去通訊也安全 |
| **DNS 流程** | 瀏覽器→OS→本地DNS→根→TLD→權威DNS |
| **CDN** | 邊緣節點就近服務，GSLB 根據 IP 路由到最近節點 |
| **快取策略** | URL 版本化 + 長 TTL，動態內容不快取 |
