# Spring Security 核心原理

## 過濾器鏈架構（最重要！）

``` mermaid
flowchart LR
    REQ(["HTTP 請求"]) --> FC["Spring Security<br>Filter Chain"] --> DS["DispatcherServlet"] --> C(["Controller"])
```

請求依序通過以下過濾器（⭐ 為重點）：

| # | Filter | 作用 |
|---|--------|------|
| 1 | `DisableEncodeUrlFilter` | |
| 2 | `WebAsyncManagerIntegrationFilter` | |
| 3 | `SecurityContextHolderFilter` | ⭐ 核心：建立 / 清除 SecurityContext |
| 4 | `HeaderWriterFilter` | |
| 5 | `CorsFilter` | |
| 6 | `CsrfFilter` | ⭐ CSRF 防護 |
| 7 | `LogoutFilter` | |
| 8 | `UsernamePasswordAuthenticationFilter` | ⭐ 表單登入 |
| 9 | `DefaultLoginPageGeneratingFilter` | |
| 10 | `BasicAuthenticationFilter` | |
| 11 | `RequestCacheAwareFilter` | |
| 12 | `AnonymousAuthenticationFilter` | ⭐ 匿名身份 |
| 13 | `ExceptionTranslationFilter` | ⭐ 異常轉換（401 / 403） |
| 14 | `AuthorizationFilter` | ⭐ 授權檢查 |

```java
// 自定義過濾器鏈（Spring Security 6.x 新寫法）
@Configuration
@EnableWebSecurity
@EnableMethodSecurity  // 開啟方法級別授權（@PreAuthorize）
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            // 1. 關閉 CSRF（前後端分離 + JWT 不需要 CSRF）
            .csrf(csrf -> csrf.disable())

            // 2. 關閉 Session（JWT 是無狀態的）
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))

            // 3. 配置路徑權限
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.GET, "/products/**")
                    .hasAnyRole("USER", "ADMIN")
                .anyRequest().authenticated()
            )

            // 4. 加入 JWT 過濾器（在 UsernamePassword 之前）
            .addFilterBefore(jwtAuthFilter,
                UsernamePasswordAuthenticationFilter.class)

            // 5. 異常處理
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(customAuthEntryPoint)   // 401 未認證
                .accessDeniedHandler(customAccessDeniedHandler)   // 403 無權限
            );

        return http.build();
    }

    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}
```

## 認證流程深度解析

```
用戶提交帳密 POST /auth/login
      ↓
UsernamePasswordAuthenticationFilter.attemptAuthentication()
      ↓
  建立 UsernamePasswordAuthenticationToken（未認證）
      ↓
AuthenticationManager.authenticate()
      ↓
ProviderManager（遍歷所有 AuthenticationProvider）
      ↓
DaoAuthenticationProvider.authenticate()
      ↓
  ① UserDetailsService.loadUserByUsername(username)
        → 從 DB 查詢用戶
        → 返回 UserDetails（包含 username、password、roles）
  ② PasswordEncoder.matches(rawPwd, encodedPwd)
        → 驗證密碼
      ↓
  認證成功 → 返回完整的 Authentication（含角色）
      ↓
SecurityContextHolder.setContext(authentication)
      ↓
successfulAuthentication() → 生成 JWT → 返回給客戶端
```

```java
// UserDetails 實作
@Data
@AllArgsConstructor
public class UserPrincipal implements UserDetails {

    private Long   id;
    private String username;
    private String password;
    private Collection<? extends GrantedAuthority> authorities;

    // 從 User 實體轉換
    public static UserPrincipal of(User user) {
        List<GrantedAuthority> authorities = user.getRoles().stream()
            .map(role -> new SimpleGrantedAuthority("ROLE_" + role.getName()))
            .collect(Collectors.toList());
        // ⚠️ hasRole("ADMIN") 自動加上 ROLE_ 前綴
        // 所以存入 authorities 時要加 ROLE_

        return new UserPrincipal(
            user.getId(),
            user.getUsername(),
            user.getPassword(),
            authorities
        );
    }

    @Override public boolean isAccountNonExpired()     { return true; }
    @Override public boolean isAccountNonLocked()      { return true; }
    @Override public boolean isCredentialsNonExpired() { return true; }
    @Override public boolean isEnabled()               { return true; }
}

// UserDetailsService 實作
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    public UserDetails loadUserByUsername(String username)
            throws UsernameNotFoundException {
        User user = userRepository.findByUsername(username)
            .orElseThrow(() ->
                new UsernameNotFoundException("用戶不存在: " + username));
        return UserPrincipal.of(user);
    }
}
```

## SecurityContext 與自定義注解

```java
// SecurityContextHolder - 存放當前認證信息
Authentication auth = SecurityContextHolder
    .getContext()
    .getAuthentication();

UserPrincipal currentUser = (UserPrincipal) auth.getPrincipal();
Long userId = currentUser.getId();

// ✅ 更優雅的方式：自定義注解
// 1. 定義注解
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface CurrentUser {}

// 2. 實作 HandlerMethodArgumentResolver
@Component
public class CurrentUserArgumentResolver
        implements HandlerMethodArgumentResolver {

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(CurrentUser.class)
            && parameter.getParameterType().equals(UserPrincipal.class);
    }

    @Override
    public Object resolveArgument(MethodParameter parameter,
            ModelAndViewContainer mavContainer,
            NativeWebRequest webRequest,
            WebDataBinderFactory binderFactory) {
        Authentication auth = SecurityContextHolder
            .getContext().getAuthentication();
        return (UserPrincipal) auth.getPrincipal();
    }
}

// 3. 在 Controller 直接使用
@GetMapping("/profile")
public UserProfile getProfile(@CurrentUser UserPrincipal user) {
    return userService.getProfile(user.getId());
}
```

## 授權流程（方法級別）

```java
@RestController
@RequestMapping("/orders")
public class OrderController {

    // 需要 ADMIN 角色
    @GetMapping("/all")
    @PreAuthorize("hasRole('ADMIN')")
    public List<Order> getAllOrders() { ... }

    // 需要 ADMIN 或 MANAGER 角色
    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")
    public void deleteOrder(@PathVariable Long id) { ... }

    // SpEL 表達式：只能訪問自己的訂單（或 ADMIN）
    @GetMapping("/{id}")
    @PreAuthorize("@orderSecurity.canAccess(authentication, #id)")
    public Order getOrder(@PathVariable Long id) { ... }

    // 需要特定權限（不是角色）
    @PostMapping
    @PreAuthorize("hasAuthority('order:create')")
    public Order createOrder(@RequestBody OrderRequest req) { ... }
}

// @PostAuthorize - 方法執行後檢查（用於返回值過濾）
@GetMapping("/{id}")
@PostAuthorize("returnObject.userId == authentication.principal.id")
public Order getOrder(@PathVariable Long id) {
    return orderService.findById(id);
}

// 自定義安全規則
@Component("orderSecurity")
public class OrderSecurityService {

    private final OrderRepository orderRepository;

    public boolean canAccess(Authentication auth, Long orderId) {
        UserPrincipal user = (UserPrincipal) auth.getPrincipal();
        // ADMIN 可以訪問所有
        if (user.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"))) {
            return true;
        }
        // 普通用戶只能訪問自己的
        return orderRepository.findById(orderId)
            .map(order -> order.getUserId().equals(user.getId()))
            .orElse(false);
    }
}
```
