# JWT 深入原理與實作

!!! abstract "本章重點"

    JWT 讓伺服器不需要保存 Session 也能驗證使用者。本章拆解 JWT 的三段結構，示範 Spring Security + JWT 的完整實作（含 Refresh Token），並整理 JWT 常見的安全問題與防禦方式。

## JWT 結構詳解

JWT = Header.Payload.Signature

eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9

.

eyJzdWIiOiIxMjMiLCJ1c2VybmFtZSI6IkpvaG4iLCJyb2xlcyI6WyJVU0VSIl19

.

SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c

─────── Base64URL 解碼 ────────

**Header（頭部）**

{

``` text
"alg": "HS256",    ← 簽名算法（HS256 或 RS256）
"typ": "JWT"       ← Token 類型
```

}

**Payload（載荷）**

{

``` text
"sub":      "123",           ← subject（用戶 ID）
"username": "John",          ← 自定義聲明
"roles":    ["USER"],        ← 角色
"iat":      1700000000,      ← issued at（簽發時間）
"exp":      1700086400       ← expiration（過期時間）
```

}

**Signature（簽名）**

HMACSHA256(

- base64UrlEncode(header) + "." + base64UrlEncode(payload),
- secret_key

)

**JWT 驗證原理**

- ① 用 . 分割為三段
- ② 取出 header + payload
- ③ 用相同密鑰重新計算簽名
- ④ 比對計算結果與收到的 Signature
- ⑤ 相同 → 驗證通過（沒有被篡改）
- ⑥ 驗證 exp（過期時間）

- ⚠️ 注意：JWT 的 Payload 只是 Base64 編碼，不是加密！
    - 任何人都可以解碼看到內容！
    - → 不要在 Payload 放敏感信息（密碼、信用卡號等）

**HS256 vs RS256**

- HS256：對稱，同一個 secret 簽名和驗證 → 適合單服務
- RS256：非對稱，私鑰簽名，公鑰驗證   → 適合微服務

## JWT 完整實作

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.12.3</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.12.3</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId>
    <version>0.12.3</version>
    <scope>runtime</scope>
</dependency>
```

```yaml
# application.yml
app:
  jwt:
    secret: "your-super-secret-key-must-be-at-least-256-bits-long-for-HS256"
    access-token-expiration:  900     # 15 分鐘（秒）
    refresh-token-expiration: 604800  # 7 天（秒）
```

=== "類別與共用設定"

    ``` java
    // JWT 工具類
    @Component
    public class JwtTokenProvider {

        @Value("${app.jwt.secret}")
        private String jwtSecret;

        @Value("${app.jwt.access-token-expiration}")
        private long accessTokenExpiration;

        @Value("${app.jwt.refresh-token-expiration}")
        private long refreshTokenExpiration;

        private SecretKey getSigningKey() {
            byte[] keyBytes = Decoders.BASE64.decode(jwtSecret);
            return Keys.hmacShaKeyFor(keyBytes);
        }

    ```

=== "生成 Token"

    ``` java

        public String generateAccessToken(UserPrincipal user) {
            return Jwts.builder()
                .subject(user.getId().toString())
                .claim("username", user.getUsername())
                .claim("roles", user.getAuthorities().stream()
                    .map(GrantedAuthority::getAuthority)
                    .collect(Collectors.toList()))
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis()
                    + accessTokenExpiration * 1000))
                .signWith(getSigningKey())
                .compact();
        }

        public String generateRefreshToken(UserPrincipal user) {
            return Jwts.builder()
                .subject(user.getId().toString())
                .claim("type", "refresh")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis()
                    + refreshTokenExpiration * 1000))
                .signWith(getSigningKey())
                .compact();
        }

    ```

=== "解析 Token"

    ``` java

        private Claims parseToken(String token) {
            return Jwts.parser()
                .verifyWith(getSigningKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
        }

        public Long   getUserId(String token)   { return Long.parseLong(parseToken(token).getSubject()); }
        public String getUsername(String token) { return parseToken(token).get("username", String.class); }

        @SuppressWarnings("unchecked")
        public List<String> getRoles(String token) {
            return parseToken(token).get("roles", List.class);
        }

        public boolean validateToken(String token) {
            try {
                parseToken(token);
                return true;
            } catch (ExpiredJwtException e) {
                log.warn("Token 已過期: {}", e.getMessage());
            } catch (MalformedJwtException e) {
                log.warn("Token 格式錯誤: {}", e.getMessage());
            } catch (UnsupportedJwtException e) {
                log.warn("不支援的 Token: {}", e.getMessage());
            } catch (SecurityException e) {
                log.warn("Token 簽名錯誤: {}", e.getMessage());
            } catch (IllegalArgumentException e) {
                log.warn("Token 為空: {}", e.getMessage());
            }
            return false;
        }

        public boolean isRefreshToken(String token) {
            return "refresh".equals(parseToken(token).get("type", String.class));
        }
    }
    ```


```java
// JWT 認證過濾器
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider        jwtTokenProvider;
    private final CustomUserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest  request,
                                    HttpServletResponse response,
                                    FilterChain         filterChain)
            throws ServletException, IOException {

        String token = extractToken(request);

        if (token != null && jwtTokenProvider.validateToken(token)) {
            String      username    = jwtTokenProvider.getUsername(token);
            UserDetails userDetails = userDetailsService.loadUserByUsername(username);

            UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(
                    userDetails,
                    null,
                    userDetails.getAuthorities()
                );

            authentication.setDetails(
                new WebAuthenticationDetailsSource().buildDetails(request));

            SecurityContextHolder.getContext().setAuthentication(authentication);
        }

        filterChain.doFilter(request, response);
    }

    private String extractToken(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/auth/") || path.startsWith("/actuator/health");
    }
}
```

=== "Auth Controller"

    ``` java
    // Auth Controller（登入/刷新/登出）
    @RestController
    @RequestMapping("/auth")
    @RequiredArgsConstructor
    public class AuthController {

        private final AuthenticationManager authenticationManager;
        private final JwtTokenProvider      jwtTokenProvider;
        private final RefreshTokenService   refreshTokenService;

        // 登入
        @PostMapping("/login")
        public ResponseEntity<TokenResponse> login(
                @Valid @RequestBody LoginRequest request) {

            Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                    request.getUsername(),
                    request.getPassword()
                )
            );

            UserPrincipal user = (UserPrincipal) authentication.getPrincipal();

            String accessToken  = jwtTokenProvider.generateAccessToken(user);
            String refreshToken = jwtTokenProvider.generateRefreshToken(user);

            refreshTokenService.save(user.getId(), refreshToken);

            return ResponseEntity.ok(TokenResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(900L)
                .build());
        }

        // 刷新 Token
        @PostMapping("/refresh")
        public ResponseEntity<TokenResponse> refresh(
                @RequestBody RefreshRequest request) {

            String refreshToken = request.getRefreshToken();

            if (!jwtTokenProvider.validateToken(refreshToken)
                    || !jwtTokenProvider.isRefreshToken(refreshToken)) {
                throw new InvalidTokenException("無效的 Refresh Token");
            }

            Long userId = jwtTokenProvider.getUserId(refreshToken);
            if (!refreshTokenService.isValid(userId, refreshToken)) {
                throw new InvalidTokenException("Refresh Token 已失效");
            }

            UserDetails   userDetails = userDetailsService.loadUserById(userId);
            UserPrincipal user        = (UserPrincipal) userDetails;
            String newAccessToken = jwtTokenProvider.generateAccessToken(user);

            return ResponseEntity.ok(TokenResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(900L)
                .build());
        }

        // 登出
        @PostMapping("/logout")
        public ResponseEntity<Void> logout(@CurrentUser UserPrincipal user) {
            refreshTokenService.delete(user.getId());
            return ResponseEntity.noContent().build();
        }
    }
    ```

=== "Refresh Token 服務"

    ``` java
    // Refresh Token 服務（Redis 儲存）
    @Service
    @RequiredArgsConstructor
    public class RefreshTokenService {

        private final StringRedisTemplate redisTemplate;
        private static final String KEY_PREFIX  = "refresh_token:";
        private static final long   EXPIRE_DAYS = 7;

        public void save(Long userId, String refreshToken) {
            redisTemplate.opsForValue().set(
                KEY_PREFIX + userId, refreshToken,
                EXPIRE_DAYS, TimeUnit.DAYS
            );
        }

        public boolean isValid(Long userId, String refreshToken) {
            String stored = redisTemplate.opsForValue().get(KEY_PREFIX + userId);
            return refreshToken.equals(stored);
        }

        public void delete(Long userId) {
            redisTemplate.delete(KEY_PREFIX + userId);
        }
    }
    ```


## JWT 安全問題與防禦

**常見 JWT 攻擊**

- 1\. Algorithm None 攻擊（alg: none）
    - 攻擊者篡改 header 中的 alg 為 none → 繞過簽名驗證！
    - 防禦：✅ 使用嚴格的 JWT 庫，明確指定允許的算法

- 2\. 算法混淆攻擊（RS256 → HS256）
    - 服務器用 RS256，攻擊者用公鑰當 HS256 的 secret 偽造
    - 防禦：✅ 明確指定算法，不動態信任 header 中的 alg

- 3\. 爆破弱密鑰
    - HS256 使用弱 secret → 可以暴力破解！
    - 防禦：✅ 使用足夠長的隨機 secret（至少 256 bits）
        - ✅ 使用 RS256 非對稱加密

- 4\. Token 洩漏（XSS 攻擊竊取 localStorage 中的 JWT）
    - 防禦：✅ Access Token 存 Memory（不存 localStorage）
        - ✅ Refresh Token 存 HttpOnly Cookie（JS 無法讀取！）

```java
// ✅ Refresh Token 存 HttpOnly Cookie
@PostMapping("/login")
public ResponseEntity<TokenResponse> login(
        @Valid @RequestBody LoginRequest request,
        HttpServletResponse response) {

    // ... 認證邏輯 ...

    // Refresh Token 存 HttpOnly Cookie（JS 無法讀取）
    ResponseCookie cookie = ResponseCookie.from("refreshToken", refreshToken)
        .httpOnly(true)          // ← 防 XSS
        .secure(true)            // ← 只在 HTTPS 傳輸
        .sameSite("Strict")      // ← 防 CSRF
        .path("/auth/refresh")   // ← 只在刷新路徑發送
        .maxAge(Duration.ofDays(7))
        .build();
    response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());

    // Access Token 放 Response Body（前端存 Memory）
    return ResponseEntity.ok(TokenResponse.builder()
        .accessToken(accessToken)
        .expiresIn(900L)
        .build());
}

// 刷新時從 Cookie 讀取
@PostMapping("/refresh")
public ResponseEntity<TokenResponse> refresh(
        @CookieValue("refreshToken") String refreshToken) {
    // ... 刷新邏輯 ...
}
```

**Token 設計最佳實踐**

**Access Token**

- ✅ 短效（15 分鐘）
- ✅ 存在前端 Memory 變數（不存 localStorage）
- ✅ 頁面關閉後自動消失

**Refresh Token**

- ✅ 長效（7 天）
- ✅ 存在 HttpOnly Cookie（防 XSS）
- ✅ 存在 Redis（可以主動吊銷）
- ✅ Refresh Token 輪換（每次刷新換一個新的）

**Token 吊銷策略**

- ① 等待自然過期（簡單，但有延遲）
- ② Redis 黑名單（存已登出的 Token 的 jti）
- ③ 縮短 Access Token 有效期 + Refresh Token 存 Redis（推薦）

!!! example "我的實作：holidayDessert 的 JWT"

    以 `jjwt` 簽發與驗證 Token，並在 Spring Security 之前加一層 **JWT 驗證 Filter**；前台另提供 Google OAuth2 登入。Filter / Interceptor / AOP 的分工見 Web MVC 章節。

    👉 [Web MVC 請求處理流程](../../backend/spring-boot/web-mvc.md)
