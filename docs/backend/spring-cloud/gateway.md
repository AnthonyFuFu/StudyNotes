# Spring Cloud Gateway

!!! abstract "本章重點"

    API 閘道是所有外部請求的統一入口，負責路由、認證、限流與日誌。本章介紹 Spring Cloud Gateway 的 Route / Predicate / Filter 三大概念與請求流程，並示範如何依 Header 實作灰度發布。

## 核心架構

``` mermaid
flowchart TB
    C(["客戶端請求"]) --> HM["Gateway Handler Mapping → Web Handler<br>匹配路由"]
    HM --> PRE
    subgraph PRE ["Pre Filter Chain（前置過濾器）"]
        direction LR
        p1["認證過濾器<br>驗證 JWT"] --> p2["限流過濾器<br>令牌桶"] --> p3["日誌過濾器<br>記錄請求"]
    end
    PRE --> DS["下游微服務（轉發請求）"]
    DS --> POST
    subgraph POST ["Post Filter Chain（後置過濾器）"]
        direction LR
        q1["響應頭過濾器"] --> q2["日誌過濾器<br>記錄響應"]
    end
    POST --> R(["返回客戶端"])
```

```yaml
# application.yml（Gateway 配置）
spring:
  cloud:
    gateway:
      routes:
        # 訂單服務路由
        - id:  order-service-route
          uri: lb://order-service      # lb:// = 從 Nacos 負載均衡
          predicates:
            - Path=/api/v1/orders/**   # 路徑匹配
            - Method=GET,POST          # HTTP 方法匹配
            - Header=X-Request-Type, order  # Header 匹配
          filters:
            - StripPrefix=0            # 不去除路徑前綴
            - AddRequestHeader=X-Gateway-Source, true  # 新增請求頭
            - AddResponseHeader=X-Response-Time, ${T(System).currentTimeMillis()}
            # 限流（令牌桶）
            - name: RequestRateLimiter
              args:
                redis-rate-limiter.replenishRate:  100  # 每秒補充 100 個令牌
                redis-rate-limiter.burstCapacity:  200  # 桶的容量 200
                key-resolver: "#{@userKeyResolver}"     # 限流 key 策略

        # 用戶服務路由
        - id:  user-service-route
          uri: lb://user-service
          predicates:
            - Path=/api/v1/users/**

        # 靜態資源路由（直接返回）
        - id:  static-route
          uri: https://static.example.com
          predicates:
            - Path=/static/**

      # 全局過濾器配置
      default-filters:
        - DedupeResponseHeader=Access-Control-Allow-Credentials Access-Control-Allow-Origin

      # 全局跨域配置
      globalcors:
        cors-configurations:
          '[/**]':
            allowed-origins: "*"
            allowed-methods: "*"
            allowed-headers: "*"
```

```java
// 自定義全局過濾器（JWT 認證）
@Component
@Order(-1)  // 優先級（數字越小越先執行）
@Slf4j
public class AuthGlobalFilter implements GlobalFilter {

    private final JwtTokenProvider jwtProvider;

    // 不需要認證的路徑
    private static final Set<String> WHITE_LIST = Set.of(
        "/api/v1/auth/login",
        "/api/v1/auth/register",
        "/api/v1/products"
    );

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getURI().getPath();

        // 白名單放行
        if (WHITE_LIST.stream().anyMatch(path::startsWith)) {
            return chain.filter(exchange);
        }

        // 驗證 JWT Token
        String token = exchange.getRequest()
            .getHeaders()
            .getFirst("Authorization");

        if (token == null || !token.startsWith("Bearer ")) {
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }

        try {
            String jwt    = token.substring(7);
            Claims claims = jwtProvider.parseToken(jwt);
            String userId = claims.getSubject();

            // 將用戶 ID 傳遞給下游服務
            ServerHttpRequest mutatedRequest = exchange.getRequest()
                .mutate()
                .header("X-User-Id", userId)
                .build();

            return chain.filter(exchange.mutate()
                .request(mutatedRequest)
                .build());

        } catch (Exception e) {
            log.warn("JWT 驗證失敗：{}", e.getMessage());
            exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
            return exchange.getResponse().setComplete();
        }
    }
}

// 限流 key 策略（按用戶 ID 限流）
@Bean
public KeyResolver userKeyResolver() {
    return exchange -> Mono.justOrEmpty(
        exchange.getRequest().getHeaders().getFirst("X-User-Id")
    ).defaultIfEmpty("anonymous");
}

// 按 IP 限流
@Bean
public KeyResolver ipKeyResolver() {
    return exchange -> Mono.just(
        Objects.requireNonNull(
            exchange.getRequest().getRemoteAddress()
        ).getAddress().getHostAddress()
    );
}
```

## 灰度發布（金絲雀發布）

```yaml
# 灰度路由：Header 帶有 X-Version:v2 的請求路由到新版本
spring:
  cloud:
    gateway:
      routes:
        # 灰度版本（新版本，10% 流量）
        - id:  order-service-canary
          uri: lb://order-service-v2
          predicates:
            - Path=/api/v1/orders/**
            - Header=X-Version, v2       # Header 匹配
          filters:
            - StripPrefix=0

        # 正式版本（舊版本，90% 流量）
        - id:  order-service-stable
          uri: lb://order-service-v1
          predicates:
            - Path=/api/v1/orders/**
```
