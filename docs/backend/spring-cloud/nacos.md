# Nacos

!!! abstract "本章重點"

    Nacos 同時提供服務註冊發現與設定中心兩項能力，是 Spring Cloud Alibaba 的核心元件。本章說明服務註冊、心跳與健康檢查的流程，以及設定的動態刷新與多環境管理。

## 服務發現（Service Registry）

**服務發現核心流程**

訂單服務啟動

- → 向 Nacos 註冊（ip:port + 服務名 + 健康狀態）
- ↓

用戶服務要呼叫訂單服務

- → 問 Nacos：「order-service 在哪？」
- → Nacos 返回所有健康的 order-service 實例列表
- → 用戶服務根據負載均衡策略選一個呼叫

**Nacos 健康檢查**

- 客戶端主動心跳（預設 5 秒一次）
- 超過 15 秒未收到心跳 → 標記為不健康
- 超過 30 秒未收到心跳 → 從服務列表移除

**臨時實例 vs 永久實例**

- 臨時實例（預設）：客戶端心跳，服務下線自動移除
- 永久實例：Nacos 主動探測，服務下線標記不健康但不移除

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
</dependency>
```

```yaml
# application.yml
spring:
  application:
    name: order-service        # 服務名（必填）
  cloud:
    nacos:
      discovery:
        server-addr: localhost:8848
        namespace: dev         # 命名空間（環境隔離）
        group: DEFAULT_GROUP
        # 元數據（可用於路由決策）
        metadata:
          version: v1
          region: cn-east
```

```java
// 主類開啟服務發現
@SpringBootApplication
@EnableDiscoveryClient
public class OrderServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(OrderServiceApplication.class, args);
    }
}

// 查詢服務實例（底層 API，了解原理用）
@Autowired
private DiscoveryClient discoveryClient;

public void printInstances() {
    List<ServiceInstance> instances =
        discoveryClient.getInstances("user-service");

    instances.forEach(instance ->
        log.info("實例：{}:{}", instance.getHost(), instance.getPort())
    );
}
```

## 配置中心（Config Center）

**為什麼需要配置中心？**

- ❌ 傳統方式：配置寫在 application.yml
    - → 修改配置需要重新打包部署
    - → 多個服務的配置散落各處，難以管理
    - → 生產環境密碼暴露在程式碼中

- ✅ 配置中心：
    - → 統一管理所有服務的配置
    - → 修改配置即時生效（不需要重啟）
    - → 配置版本管理（可以回滾）
    - → 環境隔離（dev / staging / prod）

**Nacos 配置 DataId 命名規則**

- ${spring.application.name}-${spring.profiles.active}.${file-extension}
- 例：order-service-dev.yaml

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-config</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-bootstrap</artifactId>
</dependency>
```

```yaml
# bootstrap.yml（比 application.yml 更早加載）
spring:
  application:
    name: order-service
  profiles:
    active: dev
  cloud:
    nacos:
      config:
        server-addr: localhost:8848
        namespace: dev
        group: DEFAULT_GROUP
        file-extension: yaml
        # 共享配置（多個服務共用）
        shared-configs:
          - data-id: common-dev.yaml
            group: DEFAULT_GROUP
            refresh: true
        # 擴展配置（優先級更高）
        extension-configs:
          - data-id: order-service-extra.yaml
            group: DEFAULT_GROUP
            refresh: true
```

```java
// 動態刷新配置（@RefreshScope）
@RestController
@RefreshScope  // ⭐ 加上這個注解，配置更新後自動刷新
public class OrderController {

    @Value("${order.timeout:30}")
    private int orderTimeout;

    @Value("${order.max-items:100}")
    private int maxItems;

    @GetMapping("/config")
    public Map<String, Object> getConfig() {
        return Map.of(
            "timeout",  orderTimeout,
            "maxItems", maxItems
        );
    }
}

// 監聽配置變化
@Component
public class ConfigChangeListener {

    @NacosValue(value = "${order.timeout:30}", autoRefreshed = true)
    private int orderTimeout;

    // 方式二：@ConfigurationProperties（推薦，類型安全）
    @Configuration
    @ConfigurationProperties(prefix = "order")
    @RefreshScope
    @Data
    public static class OrderProperties {
        private int    timeout  = 30;
        private int    maxItems = 100;
        private String currency = "TWD";
    }
}
```

!!! example "我的實作：我實作的是 Eureka"

    microservicecloud 使用 Eureka 雙節點叢集作為註冊中心、Config Server 作為設定中心；與 Nacos 的差異整理在元件選型章節。

    👉 [元件選型：Spring Cloud 與 Alibaba 對照](ecosystem-comparison.md)
