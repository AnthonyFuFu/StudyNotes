# TCP 深度

## 三次握手（Three-Way Handshake）

**為什麼需要三次握手？** 確認雙方的「發送」和「接收」能力都正常。

``` mermaid
sequenceDiagram
    participant C as Client
    participant S as Server
    C->>S: SYN（seq=x）
    Note right of S: 知道 Client 能發送
    S->>C: SYN + ACK（seq=y, ack=x+1）
    Note left of C: 知道 Server 能發送和接收
    C->>S: ACK（ack=y+1）
    Note right of S: 知道 Client 能接收
    Note over C,S: 連接建立 ESTABLISHED
```

| 縮寫 | 意義 |
|------|------|
| SYN | SYNchronize（同步） |
| ACK | ACKnowledge（確認） |
| seq | 序列號（Sequence Number） |
| ack | 確認號（Acknowledgment Number）＝期望收到的下一個序列號 |

??? question "為什麼不是兩次？"

    兩次只能確認 Client 能發、Server 能收；無法確認 Server 能發、Client 能收，因此無法保證全雙工連接可靠。

??? question "為什麼不是四次？"

    三次已經足夠確認雙方能力，第三次 ACK 還可以順便攜帶數據，四次是浪費。

## 四次揮手（Four-Way Handshake）

**為什麼需要四次揮手？** TCP 是全雙工的，關閉需要雙方各自關閉自己的發送方向。

``` mermaid
sequenceDiagram
    participant C as Client
    participant S as Server
    C->>S: FIN（seq=u）：我不發數據了
    Note left of C: FIN_WAIT_1
    S->>C: ACK（ack=u+1）：好的，收到了
    Note left of C: FIN_WAIT_2
    Note right of S: 可能還有數據要發<br>繼續發送剩餘數據…
    S->>C: FIN（seq=v）：我也不發了
    Note right of S: LAST_ACK
    C->>S: ACK（ack=v+1）：好的，收到了
    Note left of C: TIME_WAIT<br>等待 2MSL 後 CLOSED
    Note right of S: 收到 ACK → CLOSED
```

??? question "為什麼不是三次？"

    Server 收到 Client 的 FIN 後，可能還有數據沒發完（半關閉狀態），所以 ACK 和 FIN 不能合併，必須四次。

**TIME_WAIT 為什麼要等 2MSL？**

MSL（Maximum Segment Lifetime）＝最大報文生存時間，通常 60 秒，所以 2MSL ＝ 120 秒。

1. **確保最後一個 ACK 能到達 Server**：如果最後的 ACK 丟失，Server 會重發 FIN，Client 在 TIME_WAIT 期間可以重發 ACK
2. **讓舊連接的殘留報文消失**：防止新連接收到上一個連接的遲到報文

!!! warning "TIME_WAIT 過多的問題"

    高並發短連接場景（如爬蟲、壓測）會產生大量 TIME_WAIT，佔用端口和記憶體。解決方案：

    - `net.ipv4.tcp_tw_reuse = 1`（允許複用 TIME_WAIT 端口）
    - `net.ipv4.tcp_fin_timeout = 30`（縮短 FIN_WAIT_2 超時）

## TCP 可靠傳輸機制

| 機制 | 作用 |
|------|------|
| **① 序列號**（Sequence Number） | 每個位元組都有編號，接收方按序列號排序，解決亂序問題 |
| **② 確認應答**（ACK） | 接收方收到數據後回 ACK，ACK 號＝期望收到的下一個序列號 |
| **③ 超時重傳**（Retransmission） | 發送方等待 ACK 超時就重新發送，RTT 動態計算超時時間 |
| **④ 滑動視窗**（Sliding Window） | 不需要每次都等 ACK，可以連續發多個包；視窗大小＝接收方緩衝區剩餘空間 |
| **⑤ 流量控制**（Flow Control） | 接收方告知自己的接收視窗大小，防止接收方緩衝區溢出 |
| **⑥ 壅塞控制**（Congestion Control） | 防止網路本身過載（不是接收方問題） |

**發送方視窗**

``` mermaid
block-beta
    columns 6
    A["已發已確認"]:1 B["已發未確認<br>← 視窗大小 →"]:3 C["未發送"]:2
```

**壅塞控制四個算法**

``` mermaid
flowchart LR
    SS["慢啟動<br>指數增長"] -->|"超過閾值"| CA["擁塞避免<br>線性增長"]
    CA -->|"3 個重複 ACK"| FR["快速重傳"]
    FR --> FRC["快速恢復<br>降到閾值 / 2"]
    FRC --> CA
```

## TCP 面試高頻題

??? question "TCP 和 UDP 的區別？"

    ```text
    TCP                        UDP
    ─────────────────────────────────────────
    連接導向（三次握手）         無連接
    可靠傳輸（ACK + 重傳）       不可靠（可能丟包）
    有序傳輸                    無序
    流量控制 + 壅塞控制          無控制機制
    速度較慢                    速度快
    適合：HTTP / FTP / Email    適合：視訊 / 遊戲 / DNS
    ```

??? question "TCP 如何處理半連接攻擊（SYN Flood）？"

    ```text
    攻擊：大量偽造 IP 的 SYN 請求
    → 服務器發 SYN+ACK 但永遠等不到第三次 ACK
    → 半連接佇列被塞滿 → 正常連接無法建立

    防禦：
    SYN Cookie：不存儲半連接狀態，用 Hash 驗證第三次 ACK
    縮短 SYN 超時時間
    限制同一 IP 的 SYN 速率
    ```

??? question "Keep-Alive 是什麼？"

    ```text
    TCP Keep-Alive：
      長時間沒有數據傳輸時，定期發探測包
      確認對方還存活
      linux 預設 7200 秒才開始探測

    HTTP Keep-Alive：
      複用同一個 TCP 連接處理多個 HTTP 請求
      避免每次 HTTP 請求都三次握手
      HTTP 1.1 預設開啟
    ```
