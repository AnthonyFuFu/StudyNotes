# TCP / IP 模型

!!! abstract "本章重點"

    網路協定是分層設計的，每一層只負責自己的工作。本章對照 OSI 七層與 TCP/IP 四層模型、各層常見的協定，以及資料由上往下封裝的過程。

## 四層 vs 七層模型對照

| OSI 七層模型 | TCP/IP 四層模型 | 常見協議 |
|-------------|----------------|---------|
| 7. 應用層（Application）<br>6. 表示層（Presentation）<br>5. 會話層（Session） | **應用層** | HTTP / HTTPS / FTP<br>WebSocket / DNS / SMTP |
| 4. 傳輸層（Transport） | **傳輸層** | TCP / UDP |
| 3. 網路層（Network） | **網路層** | IP / ICMP / ARP |
| 2. 資料鏈路層（Data Link）<br>1. 實體層（Physical） | **網路介面層** | Ethernet / Wi-Fi |

**資料封裝過程（從上到下）**

| 層 | 資料單位 | 封裝時加上 |
|----|---------|-----------|
| 應用層 | HTTP Message | 應用資料 |
| 傳輸層 | TCP Segment | TCP Header（源 / 目標埠號） |
| 網路層 | IP Packet | IP Header（源 / 目標 IP） |
| 資料鏈路層 | Ethernet Frame | MAC 地址 |
| 實體層 | 位元串 | 0101 二進位訊號 |
