# OAuth2 完整教學

!!! abstract "本章重點"

    OAuth2 是「授權」協定，讓使用者不必交出密碼就能授權第三方存取資料。本章說明四種授權模式、現代標準的 PKCE，並示範 Spring Boot 整合 Google 等第三方登入。

## OAuth2 核心概念

**OAuth2 解決的問題**

- 你想用「用 Google 帳號登入」某個網站
- 但不想讓那個網站直接拿到你的 Google 密碼！

**四個角色**

- Resource Owner  = 用戶（你）
- Client          = 第三方應用（你要登入的網站）
- Authorization Server = 授權服務器（Google 的登入頁面）
- Resource Server = 資源服務器（Google API，如用戶資料）

## 四種授權模式

### 模式一：授權碼模式（Authorization Code）⭐ 最安全

``` mermaid
sequenceDiagram
    autonumber
    actor U as User
    participant C as Client
    participant A as Auth Server
    participant R as Resource Server
    U->>C: 點擊登入
    C->>A: 重定向 GET /authorize
    U->>A: 登入並授權
    A->>C: 重定向回 redirect_uri（帶 code）
    C->>A: POST /token（code + client_secret）
    A->>C: access_token + refresh_token
    C->>R: GET /userinfo（Bearer token）
    R->>C: 用戶資料
```

| 步驟 | 關鍵參數 |
|------|---------|
| ② `GET /authorize` | `client_id`、`redirect_uri`、`scope=email,profile`、`state=random_string`（防 CSRF）、`response_type=code` |
| ④ 重定向回 `redirect_uri` | `?code=AUTH_CODE&state=random_string` |
| ⑤ `POST /token` | `grant_type=authorization_code`、`code`、`client_secret`（只存在後端） |
| ⑦ `GET /userinfo` | `Authorization: Bearer access_token` |

### 模式二：客戶端憑證模式（Client Credentials）

**適用**：服務器間通訊（沒有用戶參與），例如微服務 A 調用微服務 B。

``` mermaid
sequenceDiagram
    participant A as 微服務 A（Client）
    participant AS as Auth Server
    participant B as 微服務 B
    A->>AS: POST /token<br>grant_type=client_credentials<br>client_id=service-a、client_secret
    AS->>A: access_token
    A->>B: 帶 Token 調用
```

### 模式三：隱式模式（Implicit）⚠️ 已不推薦

直接返回 Access Token（不經過 Code 交換）

→ Token 在 URL 中暴露，不安全！

→ 建議改用 Authorization Code + PKCE

### 模式四：密碼模式（Resource Owner Password）⚠️ 不推薦

用戶直接把帳密給 Client，Client 再去換 Token

→ Client 知道用戶密碼，安全性差！

→ OAuth2.1 已移除此模式

## PKCE（Proof Key for Code Exchange）⭐ 現代標準

問題：純前端 SPA 沒有 client_secret，Authorization Code 可能被截獲

**PKCE 解決方案**

**前端生成**

- code_verifier  = 隨機字串（43-128字元）
- code_challenge = BASE64URL(SHA256(code_verifier))

**授權請求加入**

- code_challenge=xxxxxx
- code_challenge_method=S256

**換 Token 時帶上**

- code_verifier=原始隨機字串
- → 驗證：SHA256(code_verifier) \=\= code_challenge

即使 Authorization Code 被截獲，

攻擊者沒有 code_verifier 也無法換取 Token！

## Spring Boot 整合 OAuth2 第三方登入

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-client</artifactId>
</dependency>
```

```yaml
# application.yml
spring:
  security:
    oauth2:
      client:
        registration:
          google:
            client-id:     ${GOOGLE_CLIENT_ID}
            client-secret: ${GOOGLE_CLIENT_SECRET}
            scope:
              - email
              - profile
          github:
            client-id:     ${GITHUB_CLIENT_ID}
            client-secret: ${GITHUB_CLIENT_SECRET}
            scope:
              - user:email
              - read:user
```

=== "自定義 OAuth2 用戶服務"

    ``` java
    // Security 配置加入 OAuth2
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .oauth2Login(oauth2 -> oauth2
                .authorizationEndpoint(auth -> auth
                    .baseUri("/oauth2/authorize"))
                .redirectionEndpoint(redirect -> redirect
                    .baseUri("/login/oauth2/code/*"))
                .successHandler(oAuth2AuthenticationSuccessHandler)
                .failureHandler(oAuth2AuthenticationFailureHandler)
                .userInfoEndpoint(userInfo -> userInfo
                    .userService(customOAuth2UserService))
            );
        return http.build();
    }


    // 自定義 OAuth2 用戶服務
    @Service
    @RequiredArgsConstructor
    public class CustomOAuth2UserService extends DefaultOAuth2UserService {

        private final UserRepository userRepository;

        @Override
        public OAuth2User loadUser(OAuth2UserRequest request)
                throws OAuth2AuthenticationException {

            OAuth2User oAuth2User = super.loadUser(request);
            String     provider   = request.getClientRegistration().getRegistrationId();

            OAuth2UserInfo userInfo = OAuth2UserInfoFactory
                .getOAuth2UserInfo(provider, oAuth2User.getAttributes());

            User user = userRepository
                .findByProviderAndProviderId(provider, userInfo.getId())
                .orElseGet(() -> registerNewUser(provider, userInfo));

            updateUser(user, userInfo);
            return UserPrincipal.of(user, oAuth2User.getAttributes());
        }

        private User registerNewUser(String provider, OAuth2UserInfo info) {
            User user = User.builder()
                .provider(provider)
                .providerId(info.getId())
                .name(info.getName())
                .email(info.getEmail())
                .imageUrl(info.getImageUrl())
                .role(Role.USER)
                .build();
            return userRepository.save(user);
        }
    }
    ```

=== "不同 Provider 的用戶資料格式不同，…"

    ``` java
    // 不同 Provider 的用戶資料格式不同，用工廠模式統一
    public abstract class OAuth2UserInfo {
        protected Map<String, Object> attributes;
        public abstract String getId();
        public abstract String getName();
        public abstract String getEmail();
        public abstract String getImageUrl();
    }

    public class GoogleOAuth2UserInfo extends OAuth2UserInfo {
        @Override public String getId()       { return (String) attributes.get("sub"); }
        @Override public String getName()     { return (String) attributes.get("name"); }
        @Override public String getEmail()    { return (String) attributes.get("email"); }
        @Override public String getImageUrl() { return (String) attributes.get("picture"); }
    }

    public class GithubOAuth2UserInfo extends OAuth2UserInfo {
        @Override public String getId()       { return String.valueOf(attributes.get("id")); }
        @Override public String getName()     { return (String) attributes.get("login"); }
        @Override public String getEmail()    { return (String) attributes.get("email"); }
        @Override public String getImageUrl() { return (String) attributes.get("avatar_url"); }
    }
    ```

=== "OAuth2 登入成功後：生成 JWT 返回…"

    ``` java
    // OAuth2 登入成功後：生成 JWT 返回給前端
    @Component
    @RequiredArgsConstructor
    public class OAuth2AuthenticationSuccessHandler
            extends SimpleUrlAuthenticationSuccessHandler {

        private final JwtTokenProvider    jwtTokenProvider;
        private final RefreshTokenService refreshTokenService;

        @Override
        public void onAuthenticationSuccess(HttpServletRequest  request,
                                             HttpServletResponse response,
                                             Authentication      authentication)
                throws IOException {

            UserPrincipal user = (UserPrincipal) authentication.getPrincipal();

            String accessToken  = jwtTokenProvider.generateAccessToken(user);
            String refreshToken = jwtTokenProvider.generateRefreshToken(user);
            refreshTokenService.save(user.getId(), refreshToken);

            String targetUrl = UriComponentsBuilder
                .fromUriString("http://localhost:3000/oauth2/callback")
                .queryParam("token", accessToken)
                .build().toUriString();

            getRedirectStrategy().sendRedirect(request, response, targetUrl);
        }
    }
    ```


!!! example "我的實作：holidayDessert 的 Google 登入"

    使用 `spring-boot-starter-oauth2-client` 實作 **Google 第三方登入**（授權碼流程），並以 Filter 記錄 OAuth2 登入來源；登入後再簽發自己系統的 JWT。

    👉 [Web MVC 請求處理流程](../../backend/spring-boot/web-mvc.md)
