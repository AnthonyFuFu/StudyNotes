# TCP 深度

## 三次握手（Three-Way Handshake）

```
為什麼需要三次握手？
→ 確認雙方的「發送」和「接收」能力都正常

         Client                    Server
           │                         │
           │──── SYN（seq=x）────────→│  Client 發起連接請求
           │                         │  Server 收到，知道 Client 能發送
           │                         │
           │←─ SYN+ACK（seq=y,ack=x+1）│  Server 確認並回應
           │                         │  Client 收到，知道 Server 能發送和接收
           │                         │
           │──── ACK（ack=y+1）──────→│  Client 確認
           │                         │  Server 收到，知道 Client 能接收
           │                         │
           │    [連接建立 ESTABLISHED] │

SYN：SYNchronize（同步）
ACK：ACKnowledge（確認）
seq：序列號（Sequence Number）
ack：確認號（Acknowledgment Number）= 期望收到的下一個序列號

為什麼不是兩次？
  兩次只能確認 Client 能發、Server 能收
  無法確認 Server 能發、Client 能收
  → 無法保證全雙工連接可靠

為什麼不是四次？
  三次已經足夠確認雙方能力
  第三次 ACK 可以順便攜帶數據
  四次是浪費
```

## 四次揮手（Four-Way Handshake）

```
為什麼需要四次揮手？
→ TCP 是全雙工的，關閉需要雙方各自關閉自己的發送方向

         Client                    Server
           │                         │
           │──── FIN（seq=u）────────→│  Client 說：我不發數據了
           │                         │  [Client → FIN_WAIT_1]
           │                         │
           │←──── ACK（ack=u+1）─────│  Server 說：好的，收到了
           │                         │  [Client → FIN_WAIT_2]
           │                         │  但 Server 可能還有數據要發！
           │                         │  繼續發送剩餘數據...
           │                         │
           │←──── FIN（seq=v）────────│  Server 說：我也不發了
           │                         │  [Server → LAST_ACK]
           │                         │
           │──── ACK（ack=v+1）──────→│  Client 說：好的，收到了
           │                         │  [Client → TIME_WAIT]
           │                         │  [等待 2MSL 後進入 CLOSED]
           │                         │  [Server 收到 ACK → CLOSED]

為什麼不是三次？
  Server 收到 Client 的 FIN 後
  可能還有數據沒發完（半關閉狀態）
  所以 ACK 和 FIN 不能合併
  → 必須四次

TIME_WAIT 等待 2MSL（Maximum Segment Lifetime）的原因：
  MSL = 最大報文生存時間（通常 60 秒）
  等待 2MSL = 120 秒

  原因一：確保最後一個 ACK 能到達 Server
    如果最後的 ACK 丟失，Server 會重發 FIN
    Client 在 TIME_WAIT 期間可以重發 ACK

  原因二：讓舊連接的殘留報文消失
    防止新連接收到上一個連接的遲到報文

TIME_WAIT 過多的問題：
  高並發短連接場景（如爬蟲、壓測）
  大量 TIME_WAIT 佔用端口和記憶體

解決方案：
  net.ipv4.tcp_tw_reuse = 1（允許複用 TIME_WAIT 端口）
  net.ipv4.tcp_fin_timeout = 30（縮短 FIN_WAIT_2 超時）
```

## TCP 可靠傳輸機制

```
TCP 如何保證可靠傳輸？

① 序列號（Sequence Number）
  每個位元組都有編號
  接收方按序列號排序，解決亂序問題

② 確認應答（ACK）
  接收方收到數據後回 ACK
  ACK 號 = 期望收到的下一個序列號

③ 超時重傳（Retransmission）
  發送方等待 ACK 超時 → 重新發送
  RTT（Round Trip Time）動態計算超時時間

④ 滑動視窗（Sliding Window）
  不需要每次都等 ACK，可以連續發多個包
  視窗大小 = 接收方緩衝區剩餘空間（流量控制）

  發送方視窗：
  ┌────────┬────────────────┬────────────┐
  │已發已確認 │  已發未確認     │  未發送     │
  │         │ ← 視窗大小 →  │            │
  └────────┴────────────────┴────────────┘

⑤ 流量控制（Flow Control）
  接收方告知發送方自己的接收視窗大小
  防止發送太快，接收方緩衝區溢出

⑥ 壅塞控制（Congestion Control）
  防止網路本身過載（不是接收方問題）
  四個算法：
  慢啟動      → 初始視窗小，指數增長
  擁塞避免    → 超過閾值，線性增長
  快速重傳    → 收到 3 個重複 ACK，立即重傳
  快速恢復    → 快速重傳後，不降到 1，降到閾值/2
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
