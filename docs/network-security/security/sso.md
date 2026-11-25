# SSO 單點登入（Single Sign-On）

## SSO 架構設計

**SSO 目標**：用戶只登入一次，就可以訪問多個系統。

``` mermaid
flowchart TB
    AS["Authorization Server<br>統一認證中心<br>Spring Authorization Server"]
    AS -- "簽發 Token" --> O["訂單系統<br>Resource Server"]
    AS -- "簽發 Token" --> U["用戶系統<br>Resource Server"]
    AS -- "簽發 Token" --> P["商品系統<br>Resource Server"]
```

- 用戶只需在 Authorization Server 登入一次
- 各 Resource Server 用公鑰驗證 JWT，不需要再請求 Auth Server

## Spring Authorization Server 實作

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-authorization-server</artifactId>
</dependency>
```

```java
// Authorization Server 配置
@Configuration
public class AuthorizationServerConfig {

    @Bean
    @Order(1)
    public SecurityFilterChain authServerSecurityFilterChain(
            HttpSecurity http) throws Exception {

        OAuth2AuthorizationServerConfiguration.applyDefaultSecurity(http);
        http.getConfigurer(OAuth2AuthorizationServerConfigurer.class)
            .oidc(Customizer.withDefaults());

        return http
            .exceptionHandling(e -> e
                .authenticationEntryPoint(
                    new LoginUrlAuthenticationEntryPoint("/login")))
            .oauth2ResourceServer(rs -> rs.jwt(Customizer.withDefaults()))
            .build();
    }

    @Bean
    @Order(2)
    public SecurityFilterChain defaultSecurityFilterChain(
            HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
            .formLogin(Customizer.withDefaults());
        return http.build();
    }

    // 已註冊的客戶端
    @Bean
    public RegisteredClientRepository registeredClientRepository() {
        RegisteredClient orderClient = RegisteredClient
            .withId(UUID.randomUUID().toString())
            .clientId("order-service")
            .clientSecret("{bcrypt}" + new BCryptPasswordEncoder()
                .encode("order-secret"))
            .clientAuthenticationMethod(
                ClientAuthenticationMethod.CLIENT_SECRET_BASIC)
            .authorizationGrantType(AuthorizationGrantType.AUTHORIZATION_CODE)
            .authorizationGrantType(AuthorizationGrantType.REFRESH_TOKEN)
            .authorizationGrantType(AuthorizationGrantType.CLIENT_CREDENTIALS)
            .redirectUri("http://order-service/login/oauth2/code/sso")
            .scope(OidcScopes.OPENID)
            .scope(OidcScopes.PROFILE)
            .scope("order:read")
            .scope("order:write")
            .tokenSettings(TokenSettings.builder()
                .accessTokenTimeToLive(Duration.ofMinutes(15))
                .refreshTokenTimeToLive(Duration.ofDays(7))
                .build())
            .build();

        return new InMemoryRegisteredClientRepository(orderClient);
    }

    // JWT 簽名密鑰（RS256 非對稱加密）
    @Bean
    public JWKSource<SecurityContext> jwkSource() {
        KeyPair       keyPair    = generateRsaKey();
        RSAPublicKey  publicKey  = (RSAPublicKey)  keyPair.getPublic();
        RSAPrivateKey privateKey = (RSAPrivateKey) keyPair.getPrivate();

        RSAKey rsaKey = new RSAKey.Builder(publicKey)
            .privateKey(privateKey)
            .keyID(UUID.randomUUID().toString())
            .build();

        return new ImmutableJWKSet<>(new JWKSet(rsaKey));
    }

    private static KeyPair generateRsaKey() {
        try {
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(2048);
            return generator.generateKeyPair();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }

    // 自定義 Token（在 JWT 中加入額外信息）
    @Bean
    public OAuth2TokenCustomizer<JwtEncodingContext> tokenCustomizer() {
        return context -> {
            if (context.getTokenType() == OAuth2TokenType.ACCESS_TOKEN) {
                Authentication principal = context.getPrincipal();
                UserPrincipal  user      = (UserPrincipal) principal.getPrincipal();

                context.getClaims()
                    .claim("userId", user.getId())
                    .claim("roles", user.getAuthorities().stream()
                        .map(GrantedAuthority::getAuthority)
                        .collect(Collectors.toSet()));
            }
        };
    }
}
```

```java
// Resource Server 配置（訂單系統、用戶系統等）
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class ResourceServerConfig {

    @Bean
    public SecurityFilterChain resourceServerFilterChain(
            HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    // 從 Auth Server 的 JWK URI 取得公鑰（自動驗證）
                    .jwkSetUri("http://auth-server/.well-known/jwks.json")
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            );
        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter authoritiesConverter =
            new JwtGrantedAuthoritiesConverter();
        authoritiesConverter.setAuthoritiesClaimName("roles");
        authoritiesConverter.setAuthorityPrefix("");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
        return converter;
    }
}
```
