# Sentinel（限流 / 熔斷 / 降級）

!!! abstract "本章重點"

    下游服務變慢時，如果沒有保護機制，上游的執行緒會被耗盡而引發連鎖故障。本章介紹 Sentinel 的資源、規則、流量控制與熔斷降級，以及如何透過 Dashboard 動態調整規則。

## 核心概念

**Sentinel 三大功能**

**限流（Flow Control）**

- 控制請求速率，超過閾值拒絕請求
- 目的：保護服務不被流量壓垮

**熔斷（Circuit Breaker）**

- 當下游服務錯誤率/慢響應率過高時，自動切斷請求
- 目的：防止錯誤擴散（雪崩效應）

**降級（Degrade）**

- 服務不可用時，返回預設值（Fallback）
- 目的：保證核心功能可用

**熔斷器三種狀態**

CLOSED（關閉）

- → 正常通過請求，統計錯誤率

- 錯誤率 / 慢響應率 超過閾值
- ↓

OPEN（打開）

- → 直接拒絕所有請求（快速失敗）

- 等待 timeWindow 秒後
- ↓

HALF_OPEN（半開）

- → 放入一個探測請求
- → 成功 → 回到 CLOSED
- → 失敗 → 回到 OPEN

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-sentinel</artifactId>
</dependency>
<!-- Sentinel Dashboard 整合 -->
<dependency>
    <groupId>com.alibaba.csp</groupId>
    <artifactId>sentinel-transport-simple-http</artifactId>
</dependency>
```

```yaml
# application.yml
spring:
  cloud:
    sentinel:
      transport:
        dashboard: localhost:8080  # Sentinel 控制台地址
        port:      8719            # 本服務暴露給控制台的端口
      eager: true                  # 立即向控制台註冊
      datasource:
        # 從 Nacos 加載規則（持久化）
        flow:
          nacos:
            server-addr: localhost:8848
            data-id:     ${spring.application.name}-flow-rules
            group-id:    SENTINEL_GROUP
            data-type:   json
            rule-type:   flow
```

```java
// 方式一：@SentinelResource 注解
@Service
public class OrderService {

    // blockHandler：限流/熔斷時調用
    // fallback：業務異常時調用
    @SentinelResource(
        value        = "createOrder",
        blockHandler = "createOrderBlocked",
        fallback     = "createOrderFallback"
    )
    public Order createOrder(OrderRequest request) {
        // 可能拋出業務異常
        return orderRepository.save(convert(request));
    }

    // 限流處理（必須和原方法簽名一樣，最後多一個 BlockException）
    public Order createOrderBlocked(OrderRequest request, BlockException ex) {
        log.warn("createOrder 被限流：{}", ex.getRuleLimitApp());
        throw new RateLimitException("系統繁忙，請稍後再試");
    }

    // 降級處理（必須和原方法簽名一樣，最後多一個 Throwable）
    public Order createOrderFallback(OrderRequest request, Throwable ex) {
        log.error("createOrder 發生異常，執行降級：{}", ex.getMessage());
        return Order.defaultOrder(); // 返回預設值
    }
}

// 方式二：程式碼方式定義規則（測試 / 本地開發用）
@PostConstruct
public void initSentinelRules() {
    // 流量控制規則
    FlowRule flowRule = new FlowRule();
    flowRule.setResource("createOrder");
    flowRule.setGrade(RuleConstant.FLOW_GRADE_QPS); // 按 QPS 限流
    flowRule.setCount(100);                          // 每秒最多 100 個請求
    FlowRuleManager.loadRules(List.of(flowRule));

    // 熔斷規則
    DegradeRule degradeRule = new DegradeRule();
    degradeRule.setResource("createOrder");
    // 按錯誤率熔斷
    degradeRule.setGrade(RuleConstant.DEGRADE_GRADE_EXCEPTION_RATIO);
    degradeRule.setCount(0.5);      // 錯誤率 > 50% 觸發熔斷
    degradeRule.setMinRequestAmount(10); // 最少 10 個請求才統計
    degradeRule.setTimeWindow(10);  // 熔斷後等待 10 秒
    DegradeRuleManager.loadRules(List.of(degradeRule));
}

// 方式三：整合 OpenFeign（呼叫下游服務時的熔斷）
@FeignClient(
    name     = "user-service",
    fallback = UserServiceFallback.class
)
public interface UserServiceClient {
    @GetMapping("/users/{id}")
    UserDTO getUser(@PathVariable Long id);
}
```

!!! example "我的實作：我實作的是 Resilience4j"

    microservicecloud 以 Resilience4j 實作 OpenFeign 呼叫的熔斷（失敗率 50% 熔斷、10 秒後半開探測）與 3 秒逾時，搭配 `fallbackFactory` 降級。

    👉 [元件選型：Spring Cloud 與 Alibaba 對照](ecosystem-comparison.md)
