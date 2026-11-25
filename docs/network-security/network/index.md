---
icon: lucide/globe
---

# 網路基礎

TCP/IP 模型、TCP 握手與可靠傳輸、HTTP 各版本演進、TLS 加密、DNS 與 CDN 的運作方式。

**核心技術**：TCP / HTTP / HTTPS / DNS / CDN / Nginx

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["網路基礎"])
    c0["01 · TCP / IP 模型"]
    R --> c0
    p0("・四層 vs 七層模型對照")
    c0 --- p0
    c1["02 · TCP 深度"]
    R --> c1
    p1("・三次握手<br>・四次揮手<br>・TCP 可靠傳輸機制<br>・TCP 面試高頻題")
    c1 --- p1
    c2["03 · HTTP 協議演進"]
    R --> c2
    p2("・HTTP 各版本對比<br>・HTTP 狀態碼快速記憶<br>・HTTP 常用 Header")
    c2 --- p2
    c3["04 · HTTPS 與 TLS"]
    R --> c3
    p3("・對稱加密 vs 非對稱加密<br>・TLS 1.3 握手流程<br>・SSL 憑證體系")
    c3 --- p3
    c4["05 · DNS 解析流程"]
    R --> c4
    p4("・完整解析過程")
    c4 --- p4
    c5["06 · CDN 原理"]
    R --> c5
    p5("・CDN 架構與工作流程<br>・CDN 快取策略")
    c5 --- p5
    c6["07 · Nginx 反向代理與負載均衡"]
    R --> c6
    p6("・為什麼前面要放 Nginx<br>・為什麼 Nginx 能撐住大量連線<br>・常用設定<br>・負載均衡策略<br>・我的實作：StudyNotes 的部署")
    c6 --- p6
    c7["08 · 面試題速查"]
    R --> c7
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5,c6,c7 chapter
    class p0,p1,p2,p3,p4,p5,p6 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · TCP / IP 模型](tcp-ip-model.md)__

    ---

    網路協定是分層設計的，每一層只負責自己的工作。

-   __[02 · TCP 深度](tcp.md)__

    ---

    TCP 是可靠傳輸的基礎。

-   __[03 · HTTP 協議演進](http.md)__

    ---

    HTTP 從 1.0 演進到 3.0，每一版都在解決上一版的效能瓶頸。

-   __[04 · HTTPS 與 TLS](https-tls.md)__

    ---

    HTTPS = HTTP + TLS。

-   __[05 · DNS 解析流程](dns.md)__

    ---

    在瀏覽器輸入網址後，DNS 負責把網域名稱轉成 IP。

-   __[06 · CDN 原理](cdn.md)__

    ---

    CDN 把靜態資源快取到離使用者最近的邊緣節點，大幅降低延遲與源站壓力。

-   __[07 · Nginx 反向代理與負載均衡](nginx.md)__

    ---

    幾乎所有網站的最前面都站著一台 Nginx：負責 HTTPS、靜態檔案、反向代理與負載均衡。

-   __[08 · 面試題速查](interview.md)__

    ---

    把網路基礎的高頻面試題整理成問答，點開題目即可看到精簡的參考答案。

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
