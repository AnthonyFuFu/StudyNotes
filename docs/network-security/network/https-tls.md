# HTTPS 與 TLS

## 對稱加密 vs 非對稱加密

```
對稱加密（AES / ChaCha20）：
  加密和解密用同一把金鑰
  ✅ 速度快（適合大量資料）
  ❌ 金鑰如何安全傳遞？（雞生蛋的問題）

非對稱加密（RSA / ECDSA）：
  公鑰（Public Key）：任何人都可以拿到，用來加密
  私鑰（Private Key）：只有自己保留，用來解密
  ✅ 解決金鑰傳遞問題
  ❌ 速度慢（只適合小量資料，如金鑰交換）

HTTPS 的聰明做法：
  用「非對稱加密」安全地交換「對稱加密金鑰」
  之後通訊全用「對稱加密」（速度快）
  → 兼顧安全和效能！
```

## TLS 1.3 握手流程（簡化版）

```
         Client                      Server
           │                           │
           │─── Client Hello ─────────→│
           │    （支援的 TLS 版本）        │
           │    （支援的加密套件列表）      │
           │    （Client 隨機數）         │
           │                           │
           │←── Server Hello ──────────│
           │    （選定的加密套件）         │
           │    （Server 隨機數）         │
           │←── Certificate ───────────│
           │    （Server 的 SSL 憑證）    │
           │←── Server Key Exchange ───│
           │    （ECDHE 公鑰參數）        │
           │←── Server Hello Done ─────│
           │                           │
           │  Client 驗證憑證（CA 鏈）    │
           │  生成 Pre-Master Secret    │
           │─── Client Key Exchange ──→│
           │    （用 Server 公鑰加密的     │
           │      Pre-Master Secret）   │
           │                           │
           │  雙方各自計算 Master Secret  │
           │  （Client隨機數+Server隨機數  │
           │    +Pre-Master Secret）    │
           │                           │
           │─── Change Cipher Spec ───→│  之後用對稱加密
           │─── Finished ─────────────→│
           │←── Change Cipher Spec ────│
           │←── Finished ──────────────│
           │                           │
           │   [TLS 握手完成，開始傳輸]    │

TLS 1.3 改進（比 TLS 1.2 更快更安全）：
  ✅ 握手從 2-RTT 降到 1-RTT（更快建連）
  ✅ 0-RTT 恢復（重連不需要完整握手）
  ✅ 移除不安全的加密算法（RSA 金鑰交換、RC4 等）
  ✅ 強制前向保密（Forward Secrecy）
     → 即使私鑰洩漏，過去的通訊也無法解密

前向保密（Forward Secrecy）：
  每次連接生成臨時金鑰（ECDHE）
  連接結束後金鑰銷毀
  → 攻擊者錄下加密流量，未來即使拿到服務器私鑰也無法解密
```

## SSL 憑證體系（CA 信任鏈）

```
憑證頒發流程：
  ① 網站生成公私鑰對
  ② 向 CA（Certificate Authority）提交 CSR（含公鑰 + 域名）
  ③ CA 驗證域名所有權（DNS 記錄 / 文件驗證）
  ④ CA 用自己的私鑰對憑證簽名
  ⑤ 網站部署憑證

驗證流程（瀏覽器）：
  ① 收到服務器憑證
  ② 查看憑證是哪個 CA 簽發的
  ③ 用 CA 的公鑰驗證憑證簽名
  ④ 驗證域名是否匹配
  ⑤ 驗證憑證是否過期 / 是否被吊銷

信任鏈（Chain of Trust）：
  Root CA（根憑證，預裝在操作系統）
      ↓ 簽名
  Intermediate CA（中間憑證）
      ↓ 簽名
  End-entity Certificate（網站憑證）

常見憑證類型：
  DV（Domain Validation）：只驗證域名所有權，最快（分鐘級）
  OV（Organization Validation）：驗證企業身份（天級）
  EV（Extended Validation）：最嚴格的驗證（週級，瀏覽器顯示公司名）

免費憑證：Let's Encrypt（DV，90天自動續期）

HSTS（HTTP Strict Transport Security）：
  服務器告訴瀏覽器：這個域名只能用 HTTPS
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  → 防止 SSL Stripping 攻擊
```
