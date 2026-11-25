# TCP / IP 模型

## 四層 vs 七層模型對照

```
OSI 七層模型          TCP/IP 四層模型      常見協議
──────────────────────────────────────────────────────
7. 應用層（Application）  ┐
6. 表示層（Presentation） ├→ 應用層          HTTP / HTTPS / FTP
5. 會話層（Session）      ┘                  WebSocket / DNS / SMTP

4. 傳輸層（Transport）    → 傳輸層           TCP / UDP

3. 網路層（Network）      → 網路層           IP / ICMP / ARP

2. 資料鏈路層（Data Link）┐
1. 實體層（Physical）     ┘→ 網路介面層       Ethernet / Wi-Fi

資料封裝過程（從上到下）：
應用層    → HTTP Message（應用資料）
傳輸層    → TCP Segment（加 TCP Header：源/目標埠號）
網路層    → IP Packet（加 IP Header：源/目標 IP）
資料鏈路層 → Ethernet Frame（加 MAC 地址）
實體層    → 0101 二進位位元串
```
