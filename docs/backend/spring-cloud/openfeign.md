# OpenFeign（聲明式 HTTP 客戶端）

!!! abstract "本章重點"

    OpenFeign 讓呼叫其他服務就像呼叫本地介面一樣簡單。本章介紹聲明式 HTTP 客戶端的基本用法，以及攔截器（傳遞 Token、traceId）、逾時與重試這些在正式環境一定要設定的細節。

## 基本使用

```java
// ❌ 傳統方式（RestTemplate）：冗長、硬編碼 URL
@Autowired
private RestTemplate restTemplate;

public User getUser(Long id) {
    return restTemplate.getForObject(
        "http://user-service/api/v1/users/" + id,
        User.class
    );
}

// ✅ OpenFeign：像呼叫本地方法一樣呼叫遠端服務
@FeignClient(
    name       = "user-service",          // 對應 Nacos 服務名
    path       = "/api/v1",               // 統一前綴
    fallback   = UserServiceFallback.class // 降級處理
)
public interface UserServiceClient {

    @GetMapping("/users/{id}")
    UserDTO getUser(@PathVariable Long id);

    @PostMapping("/users")
    UserDTO createUser(@RequestBody CreateUserRequest request);

    @GetMapping("/users")
    PageResult<UserDTO> listUsers(
        @RequestParam int page,
        @RequestParam int size
    );
}

// 啟用 OpenFeign
@SpringBootApplication
@EnableFeignClients(basePackages = "com.example.client")
public class OrderServiceApplication { }
```

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
<!-- 負載均衡（必須，OpenFeign 依賴）-->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-loadbalancer</artifactId>
</dependency>
```

## 攔截器 / 超時 / 重試

```yaml
# application.yml
spring:
  cloud:
    openfeign:
      client:
        config:
          # 全局配置
          default:
            connect-timeout: 2000   # 連接超時 2s
            read-timeout:    5000   # 讀取超時 5s
            logger-level:    BASIC  # 日誌級別：NONE/BASIC/HEADERS/FULL
          # 針對特定服務配置
          user-service:
            connect-timeout: 1000
            read-timeout:    3000
      # 開啟 OkHttp（比預設 URLConnection 效能更好）
      httpclient:
        ok-http:
          enabled: true
```

=== "Feign 攔截器"

    ``` java
    // Feign 攔截器（傳遞 Token / TraceId）
    @Component
    public class FeignAuthInterceptor implements RequestInterceptor {

        @Override
        public void apply(RequestTemplate template) {
            // 從當前請求的 Header 取得 Token，傳遞到下游服務
            ServletRequestAttributes attributes =
                (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();

            if (attributes != null) {
                HttpServletRequest request = attributes.getRequest();
                String token    = request.getHeader("Authorization");
                String traceId  = request.getHeader("X-Trace-Id");

                if (token   != null) template.header("Authorization", token);
                if (traceId != null) template.header("X-Trace-Id", traceId);
            }
        }
    }

    // Feign 重試（謹慎！非冪等操作不能重試）
    @Bean
    public Retryer feignRetryer() {
        // 初始間隔 100ms，最大間隔 1s，最多重試 3 次
        return new Retryer.Default(100, 1000, 3);
    }
    ```

=== "降級實作"

    ``` java
    // 降級實作（Fallback）
    @Component
    public class UserServiceFallback implements UserServiceClient {

        @Override
        public UserDTO getUser(Long id) {
            // 降級：返回預設值，不讓異常傳播
            log.warn("user-service 不可用，返回預設用戶, id={}", id);
            return UserDTO.builder()
                .id(id)
                .username("Unknown")
                .build();
        }

        @Override
        public UserDTO createUser(CreateUserRequest request) {
            throw new ServiceUnavailableException("用戶服務暫時不可用");
        }
    }
    ```

=== "帶原因的 Fallback"

    ``` java
    // 帶原因的 Fallback（可以知道失敗原因）
    @Component
    public class UserServiceFallbackFactory
            implements FallbackFactory<UserServiceClient> {

        @Override
        public UserServiceClient create(Throwable cause) {
            log.error("user-service 呼叫失敗：{}", cause.getMessage());
            return new UserServiceClient() {
                @Override
                public UserDTO getUser(Long id) {
                    return UserDTO.defaultUser(id);
                }
                // ...
            };
        }
    }
    ```

