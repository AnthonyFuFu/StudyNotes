# 面試題速查

??? question "TCP 三次握手為什麼不是兩次？"

    兩次只能確認「Client 能發 + Server 能收」

    無法確認「Server 能發 + Client 能收」

    三次才能確保全雙工雙向通訊都正常

??? question "四次揮手為什麼不是三次？"

    TCP 是全雙工，關閉需要雙方各自關閉發送方向

    Server 收到 FIN 後可能還有數據要發（半關閉狀態）

    所以 ACK 和 FIN 不能合併 → 需要四次

??? question "TIME_WAIT 太多怎麼辦？"

    縮短 TIME_WAIT 時間 / 開啟 SO_REUSEADDR / tcp_tw_reuse

??? question "HTTP 和 HTTPS 的區別？"

    HTTPS = HTTP + TLS 加密

    HTTP：明文傳輸，443 → 80 埠

    HTTPS：加密傳輸，預設 443 埠

    HTTPS 確保機密性（加密）/ 完整性（防竄改）/ 身份驗證（憑證）

??? question "HTTP 2.0 解決了什麼問題？"

    解決了 HTTP 1.1 的隊頭阻塞（HOL Blocking）

    通過多路複用，一個連接並行傳輸多個 Stream

    同時提供 Header 壓縮、Server Push

??? question "DNS 解析的完整流程？"

    瀏覽器快取 → OS 快取 → 本地 DNS

    → 根域名服務器 → TLD 服務器 → 權威 DNS

    → 返回 IP → 快取

??? question "HTTPS 一定安全嗎？"

    不一定

    **HTTPS 確保傳輸安全，但不保證**

    - ① 服務器端程式碼安全（SQL 注入等）
    - ② 憑證不被偽造（需要 CA 體系可信）
    - ③ 用戶端安全（被植入根憑證可被中間人攻擊）
