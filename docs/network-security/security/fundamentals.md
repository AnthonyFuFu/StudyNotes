# 資安基礎概念

## 認證（Authentication）vs 授權（Authorization）

```
認證（Authentication）= 你是誰？
  → 驗證身份：帳號密碼、指紋、Token

授權（Authorization）= 你能做什麼？
  → 驗證權限：能不能訪問這個資源

流程：
  用戶輸入帳密
       ↓
  [認證] 你是 John？✅
       ↓
  [授權] John 能訪問 /admin？❌（沒有 ADMIN 角色）
       ↓
  返回 403 Forbidden
```

## 加密基礎

### 對稱加密 vs 非對稱加密

```
對稱加密（AES、DES）：
  加密密鑰 == 解密密鑰
  明文 ──[密鑰]──→ 密文 ──[相同密鑰]──→ 明文
  優點：速度快
  缺點：密鑰傳輸不安全
  使用：儲存加密（資料庫字段加密）

非對稱加密（RSA、ECDSA）：
  公鑰（Public Key）：可以公開，用來加密 / 驗證簽名
  私鑰（Private Key）：必須保密，用來解密 / 簽名
  加密：明文 ──[公鑰]──→ 密文 ──[私鑰]──→ 明文
  簽名：數據 ──[私鑰]──→ 簽名 ──[公鑰]──→ 驗證
  優點：無需傳輸私鑰，安全
  缺點：速度慢（比對稱慢 100~1000 倍）
  使用：HTTPS 握手、JWT RS256 簽名

雜湊（Hash / 摘要）：
  單向，不可逆！
  MD5（已不安全）、SHA-256、BCrypt
  密碼儲存：
  ❌ 明文儲存  → 資料庫洩漏直接完蛋
  ❌ MD5      → 彩虹表攻擊（預計算所有可能的 Hash）
  ✅ BCrypt   → 含有 Salt（隨機鹽），每次結果不同！
```

```java
// BCrypt 密碼加密（Spring Security 內建）
@Bean
public PasswordEncoder passwordEncoder() {
    // strength = 10（工作因子，越大越慢，預設 10）
    // 每次 encode 結果都不同（內含隨機 salt）！
    return new BCryptPasswordEncoder(10);
}

// 使用
String rawPassword = "myPassword123";
String encoded = passwordEncoder.encode(rawPassword);
// 輸出：$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy

// 驗證（不能解密，只能比對！）
boolean matches = passwordEncoder.matches(rawPassword, encoded); // true

// BCrypt hash 結構：
// $2a $ 10 $ N9qo8uLOickgx2ZMRZoMye....
//  ↑版本 ↑強度 ↑salt（22字元）↑hash
// matches 時，從 encoded 中取出 salt，用相同 salt 計算，比對結果
```

## HTTPS / TLS 握手原理

```
TLS 握手流程（簡化）：

Client                              Server
  │─── ClientHello ─────────────────→│
  │    （支援的加密套件、TLS版本）        │
  │←── ServerHello ──────────────────│
  │    （選定加密套件）                 │
  │←── Certificate ──────────────────│
  │    （服務器憑證：包含公鑰）          │
  │←── ServerHelloDone ──────────────│
  │                                  │
  │ 驗證憑證（CA 簽名是否合法？）        │
  │                                  │
  │─── ClientKeyExchange ───────────→│
  │    （用公鑰加密的預主密鑰）          │
  │─── ChangeCipherSpec ────────────→│
  │─── Finished ────────────────────→│
  │←── ChangeCipherSpec ─────────────│
  │←── Finished ─────────────────────│
  │════════ 加密通訊開始 ═════════════│
  │    （使用對稱密鑰，速度快）          │

關鍵點：
1. 非對稱加密用於握手（交換密鑰）
2. 對稱加密用於實際數據傳輸（速度快）
3. CA（證書頒發機構）保證公鑰真實性
```
