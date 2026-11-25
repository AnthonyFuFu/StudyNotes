# 分散式鏈路追蹤

## SkyWalking 架構

```
為什麼需要鏈路追蹤？

一個用戶請求在微服務中的旅程：

用戶請求
   ↓
API Gateway（10ms）
   ↓
訂單服務（500ms）← 哪裡慢？
   ├→ 用戶服務（20ms）
   ├→ 庫存服務（30ms）
   ├→ MySQL 查詢（400ms）← 原來是這裡！
   └→ Redis 查詢（5ms）

沒有鏈路追蹤：看著 500ms 不知道哪裡慢
有了鏈路追蹤：立刻定位到 MySQL 查詢耗時 400ms

SkyWalking 架構：

┌─────────────────────────────────────────────────────────────┐
│                    應用層（Agent 自動注入）                    │
│  訂單服務              用戶服務              庫存服務           │
│  [SW Agent]          [SW Agent]          [SW Agent]        │
└─────────────────────────────┬───────────────────────────────┘
                              │ gRPC 上報 Span 數據
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    OAP Server（分析引擎）                     │
│  接收 Span → 分析依賴關係 → 計算指標 → 存儲                   │
└──────────────────┬──────────────────────┬───────────────────┘
                   │                      │
                   ↓                      ↓
         ┌──────────────┐       ┌──────────────────┐
         │ Elasticsearch│       │  SkyWalking UI   │
         │（存儲鏈路數據）│       │ （視覺化展示）      │
         └──────────────┘       └──────────────────┘
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

```
SkyWalking UI 關鍵功能：

① 拓撲圖（Topology）
   自動繪製服務依賴關係圖
   顯示每條鏈路的 QPS 和錯誤率

   用戶 → API Gateway → 訂單服務 → MySQL
                                 → 庫存服務
                                 → 支付服務 → 外部支付平台

② Span 詳情（定位瓶頸）
   點開一條 Trace，看到完整的調用樹：

   OrderService.createOrder         [0ms ~ 523ms]  總耗時 523ms
   ├─ UserService.getUser           [5ms ~ 25ms]   耗時 20ms
   ├─ InventoryService.check        [30ms ~ 60ms]  耗時 30ms
   ├─ MySQL: SELECT * FROM orders   [65ms ~ 465ms] 耗時 400ms ← 瓶頸！
   │    SQL: SELECT * FROM orders WHERE user_id=?
   │    行數: 50,000 行 ← 缺少索引！
   └─ Redis: SET order:123          [470ms ~ 475ms] 耗時 5ms

③ 服務指標（Service Metrics）
   SLA、吞吐量、延遲的趨勢圖

④ 告警規則
   - 服務 P99 延遲 > 2s → 告警
   - 服務錯誤率 > 5% → 告警
   - 服務不可用 → 告警
```
