# 分散式鏈路追蹤

## SkyWalking 架構

**一個用戶請求在微服務中的旅程**

``` mermaid
flowchart LR
    U(["用戶請求"]) --> GW["API Gateway<br>10ms"] --> OS["訂單服務<br>500ms ← 哪裡慢？"]
    OS --> US["用戶服務<br>20ms"]
    OS --> IS["庫存服務<br>30ms"]
    OS --> DB[("MySQL 查詢<br>400ms ← 原來是這裡！")]
    OS --> RD[("Redis 查詢<br>5ms")]
```

- **沒有鏈路追蹤**：看著 500ms 不知道哪裡慢
- **有了鏈路追蹤**：立刻定位到 MySQL 查詢耗時 400ms

**SkyWalking 架構**

``` mermaid
flowchart TB
    subgraph APPS ["應用層（Agent 自動注入）"]
        direction LR
        A1["訂單服務<br>SW Agent"]
        A2["用戶服務<br>SW Agent"]
        A3["庫存服務<br>SW Agent"]
    end
    OAP["OAP Server（分析引擎）<br>接收 Span → 分析依賴關係 → 計算指標 → 存儲"]
    APPS -- "gRPC 上報 Span 數據" --> OAP
    OAP --> ES[("Elasticsearch<br>存儲鏈路數據")]
    OAP --> UI["SkyWalking UI<br>視覺化展示"]
```

## Spring Boot 整合（OpenTelemetry 現代標準）

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
    <version>2.1.0</version>
</dependency>
```

```yaml
# application.yml
management:
  tracing:
    sampling:
      probability: 1.0   # 採樣率：1.0 = 100%（生產建議 0.1 = 10%）
  otlp:
    tracing:
      endpoint: http://skywalking-oap:4317

logging:
  pattern:
    level: "%5p [${spring.application.name:},%X{traceId:-},%X{spanId:-}]"
```

```java
// 自定義 Span（追蹤業務操作）
@Service
@RequiredArgsConstructor
public class OrderService {

    private final Tracer tracer;

    public Order createOrder(OrderRequest request) {
        Span span = tracer.nextSpan()
            .name("createOrder")
            .tag("userId",    request.getUserId().toString())
            .tag("productId", request.getProductId().toString())
            .start();

        try (Tracer.SpanInScope ws = tracer.withSpan(span)) {
            Order order = processOrder(request);

            span.tag("orderId", order.getId().toString())
                .tag("amount",  order.getAmount().toString());

            return order;

        } catch (Exception e) {
            span.tag("error", e.getMessage()).error(e);
            throw e;
        } finally {
            span.end();  // 必須結束 Span
        }
    }

    // 使用 @Observed 注解（更簡潔，自動建立 Span + Metrics）
    @Observed(
        name            = "order.payment",
        contextualName  = "處理訂單支付",
        lowCardinalityKeyValues = {"service", "order"}
    )
    public void processPayment(Long orderId) {
        // 自動追蹤這個方法
    }
}

// 跨服務傳遞 TraceId（Feign 客戶端攔截器）
@Component
public class TraceIdPropagationInterceptor implements RequestInterceptor {

    private final Tracer tracer;

    @Override
    public void apply(RequestTemplate template) {
        Span currentSpan = tracer.currentSpan();
        if (currentSpan != null) {
            template.header("X-Trace-Id",
                currentSpan.context().traceId());
        }
    }
}
```

## 鏈路追蹤實戰分析

**① 拓撲圖（Topology）**：自動繪製服務依賴關係圖，顯示每條鏈路的 QPS 和錯誤率。

``` mermaid
flowchart LR
    U(["用戶"]) --> GW["API Gateway"] --> OS["訂單服務"]
    OS --> DB[("MySQL")]
    OS --> IS["庫存服務"]
    OS --> PS["支付服務"] --> EXT["外部支付平台"]
```

**② Span 詳情（定位瓶頸）**：點開一條 Trace，看到完整的調用樹與每段耗時。

``` mermaid
gantt
    title OrderService.createOrder（總耗時 523ms）
    dateFormat x
    axisFormat %Lms
    section 調用
    UserService.getUser（20ms）        : 5, 25
    InventoryService.check（30ms）     : 30, 60
    MySQL SELECT orders（400ms）瓶頸    : crit, 65, 465
    Redis SET order:123（5ms）          : 470, 475
```

!!! warning "瓶頸分析"

    `SELECT * FROM orders WHERE user_id=?` 掃描了 50,000 行，原因是缺少索引。

**③ 服務指標（Service Metrics）**：SLA、吞吐量、延遲的趨勢圖。

**④ 告警規則**

- 服務 P99 延遲 > 2s → 告警
- 服務錯誤率 > 5% → 告警
- 服務不可用 → 告警
