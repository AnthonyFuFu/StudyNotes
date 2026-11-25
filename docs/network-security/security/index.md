---
icon: lucide/shield-check
---

# 資安

認證與授權的基本觀念，Spring Security、JWT、OAuth2、SSO 的原理與實作，以及常見攻擊的防禦方式。

**核心技術**：Spring Security / OAuth2 / JWT / SSO / 攻擊防禦

## 學習地圖

``` mermaid
mindmap
  root((資安))
    資安基礎概念
      認證 vs 授權
      OWASP Top 10 常見漏洞
      加密基礎（對稱/非對稱）
    Spring Security 核心原理
      過濾器鏈架構
      SecurityContext
      認證流程
      授權流程
    JWT 深入原理與實作
      JWT 結構
      完整實作
      JWT 安全問題
    OAuth2 完整教學
      四種授權模式
      Spring Authorization Server
      第三方登入（Google / GitHub）
    SSO 單點登入
      OAuth2 + JWT 實現 SSO
    常見攻擊防禦
      SQL 注入
      XSS
      CSRF
      其他攻擊
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 資安基礎概念](fundamentals.md)__

    ---

    認證（Authentication）vs 授權 · 加密基礎 · HTTPS / TLS 握手原理

-   __[02 · Spring Security 核心原理](spring-security.md)__

    ---

    過濾器鏈架構 · 認證流程深度解析 · SecurityContext 與自定義注解 · 授權流程

-   __[03 · JWT 深入原理與實作](jwt.md)__

    ---

    JWT 結構詳解 · JWT 完整實作 · JWT 安全問題與防禦

-   __[04 · OAuth2 完整教學](oauth2.md)__

    ---

    OAuth2 核心概念 · 四種授權模式 · PKCE（Proof Key for Code Exchange）⭐ 現代標準 · Spring Boot 整合 OAuth2 第三方登入

-   __[05 · SSO 單點登入](sso.md)__

    ---

    SSO 架構設計 · Spring Authorization Server 實作

-   __[06 · 常見攻擊防禦](attack-defense.md)__

    ---

    SQL 注入 · XSS · CSRF · 其他重要攻擊防禦

</div>

## 重點速覽

### 認證與授權架構
```
用戶登入 → Spring Security Filter Chain
    → AuthenticationManager
    → DaoAuthenticationProvider
    → UserDetailsService（查 DB）
    → BCryptPasswordEncoder（驗密碼）
    → 生成 JWT（Access Token + Refresh Token）
    → 返回 Token 給客戶端

後續請求 → JwtAuthenticationFilter
    → 驗證 JWT 簽名 / 過期時間
    → 設定 SecurityContextHolder
    → @PreAuthorize 方法級授權
```

### JWT 安全設計

| 項目 | 策略 |
|------|------|
| **Access Token** | 短效（15 分鐘），存前端 Memory |
| **Refresh Token** | 長效（7 天），存 HttpOnly Cookie + Redis |
| **簽名算法** | RS256（非對稱）適合微服務 |
| **吊銷機制** | Redis 黑名單 / Refresh Token 輪換 |

### 常見攻擊防禦

| 攻擊類型 | 防禦方式 |
|---------|---------|
| **SQL 注入** | Prepared Statement，MyBatis 用 `#{}` 不用 `${}` |
| **XSS** | 輸出編碼 + CSP Header + HttpOnly Cookie |
| **CSRF** | JWT + Bearer Header 天然防禦；Session 需 CSRF Token |
| **暴力破解** | Redis 計數 + 帳號鎖定策略 |
| **重放攻擊** | Idempotency-Key + Redis setIfAbsent |

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **BCrypt** | 含 Salt 的單向 Hash，密碼儲存唯一選擇 |
| **Spring Security** | 過濾器鏈架構，DaoAuthenticationProvider 認證流程 |
| **JWT 結構** | Header.Payload.Signature，Payload 不加密只編碼 |
| **JWT 設計** | Access Token 短效存 Memory，Refresh Token 長效存 HttpOnly Cookie + Redis |
| **OAuth2** | 授權碼模式最安全，PKCE 適合純前端，客戶端憑證適合服務間 |
| **SSO** | Auth Server（簽發 JWT）+ Resource Server（驗證 JWT）|
| **SQL 注入** | 用預處理語句，MyBatis 用 #{} 不用 ${} |
| **XSS** | 輸出編碼 + CSP Header + HttpOnly Cookie |
| **CSRF** | JWT + Bearer Header 天然防 CSRF，Session 需要 CSRF Token |
| **暴力破解** | Redis 計數 + 鎖定策略 |
| **敏感數據** | AES-256-GCM 加密儲存 |
| **冪等性** | Idempotency-Key + Redis setIfAbsent 防重放 |
