# TCP / IP 模型

## 四層 vs 七層模型對照

| OSI 七層模型 | TCP/IP 四層模型 | 常見協議 |
|-------------|----------------|---------|
| 7. 應用層（Application）<br>6. 表示層（Presentation）<br>5. 會話層（Session） | **應用層** | HTTP / HTTPS / FTP<br>WebSocket / DNS / SMTP |
| 4. 傳輸層（Transport） | **傳輸層** | TCP / UDP |
| 3. 網路層（Network） | **網路層** | IP / ICMP / ARP |
| 2. 資料鏈路層（Data Link）<br>1. 實體層（Physical） | **網路介面層** | Ethernet / Wi-Fi |

**資料封裝過程（從上到下）**

``` mermaid
flowchart TB
    A["應用層<br>HTTP Message（應用資料）"]
    T["傳輸層<br>TCP Segment（加 TCP Header：源 / 目標埠號）"]
    N["網路層<br>IP Packet（加 IP Header：源 / 目標 IP）"]
    D["資料鏈路層<br>Ethernet Frame（加 MAC 地址）"]
    P["實體層<br>0101 二進位位元串"]
    A --> T --> N --> D --> P
```
