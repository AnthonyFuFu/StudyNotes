# gRPC（高效能 RPC 框架）

## 核心原理

```
gRPC 是 Google 開源的高效能 RPC 框架

為什麼用 gRPC？

REST（HTTP/1.1 + JSON）：
  ❌ 文本協議（JSON），序列化/反序列化慢
  ❌ HTTP/1.1 每次請求都要建立連接（或複用，但有限制）
  ❌ 只支援請求-響應模式

gRPC（HTTP/2 + Protobuf）：
  ✅ 二進制協議（Protobuf），序列化比 JSON 快 5~10 倍，體積小 3~5 倍
  ✅ HTTP/2 多路複用（一個連接處理多個請求）
  ✅ 支援四種通訊模式（單向 / 雙向流）
  ✅ 強類型（Protobuf 定義 schema）
  ✅ 跨語言（Java / Go / Python / C++ / Node.js ...）
  ✅ 自動生成客戶端代碼

適用場景：
  微服務間通訊（內部 API）
  需要高效能、低延遲的場景
  需要雙向流的場景（如：即時監控）
  多語言混合的微服務環境

不適合：
  瀏覽器客戶端（需要 gRPC-Web 轉換層）
  公開 API（可讀性差）
```

## Protobuf 定義

```protobuf
// src/main/proto/order.proto

syntax = "proto3";

package com.example.order;

option java_package         = "com.example.grpc.order";
option java_outer_classname = "OrderProto";
option java_multiple_files  = true;

// 導入通用類型
import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

// ──── 消息定義 ────

message Order {
    int64  id         = 1;
    int64  user_id    = 2;
    string status     = 3;
    double amount     = 4;
    string address    = 5;
    repeated OrderItem items = 6;
    google.protobuf.Timestamp created_at = 7;
}

message OrderItem {
    int64  product_id = 1;
    string name       = 2;
    int32  quantity   = 3;
    double price      = 4;
}

message CreateOrderRequest {
    int64  user_id = 1;
    string address = 2;
    repeated OrderItem items = 3;
}

message GetOrderRequest {
    int64 id = 1;
}

message ListOrdersRequest {
    int64  user_id = 1;
    int32  page    = 2;
    int32  size    = 3;
    string status  = 4;
}

message ListOrdersResponse {
    repeated Order orders = 1;
    int64          total  = 2;
}

message OrderStatusUpdate {
    int64  order_id  = 1;
    string status    = 2;
    string message   = 3;
    google.protobuf.Timestamp updated_at = 4;
}

// ──── 服務定義（四種模式）────

service OrderService {

    // ① Unary RPC（單請求/單響應，最常用）
    rpc CreateOrder (CreateOrderRequest) returns (Order);
    rpc GetOrder    (GetOrderRequest)    returns (Order);

    // ② Server Streaming RPC（單請求/多響應）
    // 服務器返回訂單狀態更新的流
    rpc WatchOrderStatus (GetOrderRequest)
        returns (stream OrderStatusUpdate);

    // ③ Client Streaming RPC（多請求/單響應）
    // 客戶端批量發送訂單，服務器返回匯總結果
    rpc BatchCreateOrders (stream CreateOrderRequest)
        returns (ListOrdersResponse);

    // ④ Bidirectional Streaming RPC（雙向流）
    // 即時訂單追蹤
    rpc TrackOrders (stream GetOrderRequest)
        returns (stream OrderStatusUpdate);
}
```

## Spring Boot 整合 gRPC

```xml
<!-- pom.xml -->
<dependencies>
    <dependency>
        <groupId>net.devh</groupId>
        <artifactId>grpc-spring-boot-starter</artifactId>
        <version>2.15.0.RELEASE</version>
    </dependency>
    <dependency>
        <groupId>net.devh</groupId>
        <artifactId>grpc-client-spring-boot-starter</artifactId>
        <version>2.15.0.RELEASE</version>
    </dependency>
</dependencies>

<build>
    <plugins>
        <!-- 自動從 .proto 生成 Java 代碼 -->
        <plugin>
            <groupId>org.xolstice.maven.plugins</groupId>
            <artifactId>protobuf-maven-plugin</artifactId>
            <version>0.6.1</version>
            <configuration>
                <protocArtifact>
                    com.google.protobuf:protoc:3.25.0:exe:${os.detected.classifier}
                </protocArtifact>
                <pluginId>grpc-java</pluginId>
                <pluginArtifact>
                    io.grpc:protoc-gen-grpc-java:1.59.0:exe:${os.detected.classifier}
                </pluginArtifact>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>compile</goal>
                        <goal>compile-custom</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

```yaml
# application.yml（Server 端）
grpc:
  server:
    port: 9090
    enable-reflection: true   # 開啟反射（方便 grpcurl 測試）
    security:
      enabled: false          # 生產環境要開啟 TLS

# application.yml（Client 端）
grpc:
  client:
    order-service:
      address:      "static://localhost:9090"
      negotiation-type: plaintext   # 生產用 TLS
```

```java
// ═══════════════ Server 端實作 ═══════════════

@GrpcService
@RequiredArgsConstructor
@Slf4j
public class OrderGrpcService extends OrderServiceGrpc.OrderServiceImplBase {

    private final OrderService orderService;

    // ① Unary RPC
    @Override
    public void createOrder(CreateOrderRequest request,
                            StreamObserver<Order> responseObserver) {
        try {
            log.info("gRPC createOrder, userId={}", request.getUserId());

            // 業務邏輯
            com.example.model.Order order =
                orderService.create(fromProto(request));

            // 返回響應
            responseObserver.onNext(toProto(order));
            responseObserver.onCompleted();

        } catch (Exception e) {
            log.error("gRPC createOrder 失敗", e);
            responseObserver.onError(
                Status.INTERNAL
                    .withDescription(e.getMessage())
                    .withCause(e)
                    .asRuntimeException()
            );
        }
    }

    // ② Server Streaming RPC
    @Override
    public void watchOrderStatus(GetOrderRequest request,
                                  StreamObserver<OrderStatusUpdate> responseObserver) {
        Long orderId = request.getId();
        log.info("開始監聽訂單狀態，orderId={}", orderId);

        try {
            // 模擬訂單狀態流
            List<String> statuses = List.of("PAID", "PREPARING", "SHIPPED", "DELIVERED");
            for (String status : statuses) {
                Thread.sleep(2000); // 模擬狀態變化

                OrderStatusUpdate update = OrderStatusUpdate.newBuilder()
                    .setOrderId(orderId)
                    .setStatus(status)
                    .setMessage("訂單狀態更新為：" + status)
                    .setUpdatedAt(Timestamps.fromMillis(System.currentTimeMillis()))
                    .build();

                responseObserver.onNext(update); // 推送狀態更新
            }
            responseObserver.onCompleted();

        } catch (Exception e) {
            responseObserver.onError(
                Status.INTERNAL.withDescription(e.getMessage()).asRuntimeException()
            );
        }
    }

    // ③ Client Streaming RPC
    @Override
    public StreamObserver<CreateOrderRequest> batchCreateOrders(
            StreamObserver<ListOrdersResponse> responseObserver) {

        List<com.example.model.Order> createdOrders = new ArrayList<>();

        return new StreamObserver<CreateOrderRequest>() {
            @Override
            public void onNext(CreateOrderRequest request) {
                // 接收客戶端發送的每個請求
                com.example.model.Order order =
                    orderService.create(fromProto(request));
                createdOrders.add(order);
                log.info("批量創建訂單：{}", order.getId());
            }

            @Override
            public void onError(Throwable t) {
                log.error("批量創建訂單出錯", t);
            }

            @Override
            public void onCompleted() {
                // 客戶端發送完畢，返回匯總結果
                ListOrdersResponse response = ListOrdersResponse.newBuilder()
                    .addAllOrders(createdOrders.stream()
                        .map(OrderGrpcService.this::toProto)
                        .collect(Collectors.toList()))
                    .setTotal(createdOrders.size())
                    .build();

                responseObserver.onNext(response);
                responseObserver.onCompleted();
            }
        };
    }

    // Proto 轉換工具方法
    private Order toProto(com.example.model.Order order) {
        return Order.newBuilder()
            .setId(order.getId())
            .setUserId(order.getUserId())
            .setStatus(order.getStatus().name())
            .setAmount(order.getAmount().doubleValue())
            .build();
    }

    private com.example.model.OrderRequest fromProto(CreateOrderRequest proto) {
        return com.example.model.OrderRequest.builder()
            .userId(proto.getUserId())
            .address(proto.getAddress())
            .build();
    }
}

// gRPC 攔截器（實作認證、日誌等）
@Component
public class AuthGrpcInterceptor implements ServerInterceptor {

    private static final Metadata.Key<String> AUTH_KEY =
        Metadata.Key.of("authorization", Metadata.ASCII_STRING_MARSHALLER);

    @Override
    public <Q, R> ServerCall.Listener<Q> interceptCall(
            ServerCall<Q, R> call, Metadata headers,
            ServerCallHandler<Q, R> next) {

        String token = headers.get(AUTH_KEY);
        if (token == null || !token.startsWith("Bearer ")) {
            call.close(Status.UNAUTHENTICATED
                .withDescription("缺少認證 Token"), new Metadata());
            return new ServerCall.Listener<Q>() {};
        }

        // 驗證 JWT Token
        // ...

        return next.startCall(call, headers);
    }
}
```

```java
// ═══════════════ Client 端使用 ═══════════════

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderGrpcClient {

    // 自動注入 gRPC Channel 並創建 Stub
    @GrpcClient("order-service")
    private OrderServiceGrpc.OrderServiceBlockingStub blockingStub;

    @GrpcClient("order-service")
    private OrderServiceGrpc.OrderServiceStub asyncStub;

    // ① Unary RPC - 同步調用
    public Order createOrder(CreateOrderRequest request) {
        try {
            return blockingStub
                .withDeadlineAfter(5, TimeUnit.SECONDS)  // 超時設定
                .createOrder(request);
        } catch (StatusRuntimeException e) {
            log.error("gRPC createOrder 失敗: {}", e.getStatus());
            throw new ServiceException("訂單服務不可用", e);
        }
    }

    // ② Server Streaming - 異步監聽
    public void watchOrderStatus(Long orderId,
                                  Consumer<OrderStatusUpdate> onUpdate,
                                  Runnable onComplete) {
        GetOrderRequest request = GetOrderRequest.newBuilder()
            .setId(orderId)
            .build();

        asyncStub.watchOrderStatus(request, new StreamObserver<OrderStatusUpdate>() {
            @Override
            public void onNext(OrderStatusUpdate update) {
                log.info("收到訂單狀態更新：{}", update.getStatus());
                onUpdate.accept(update);
            }

            @Override
            public void onError(Throwable t) {
                log.error("監聽訂單狀態出錯", t);
            }

            @Override
            public void onCompleted() {
                log.info("訂單狀態監聽完成");
                onComplete.run();
            }
        });
    }

    // ③ Client Streaming - 批量發送
    public ListOrdersResponse batchCreateOrders(
            List<CreateOrderRequest> requests) throws InterruptedException {

        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<ListOrdersResponse> result = new AtomicReference<>();

        StreamObserver<CreateOrderRequest> requestObserver =
            asyncStub.batchCreateOrders(new StreamObserver<ListOrdersResponse>() {
                @Override
                public void onNext(ListOrdersResponse response) {
                    result.set(response);
                }
                @Override public void onError(Throwable t) { latch.countDown(); }
                @Override public void onCompleted()        { latch.countDown(); }
            });

        // 發送多個請求
        for (CreateOrderRequest request : requests) {
            requestObserver.onNext(request);
        }
        requestObserver.onCompleted();

        latch.await(30, TimeUnit.SECONDS);
        return result.get();
    }
}
```

## gRPC vs REST 對比

```
┌──────────────────┬─────────────────────┬───────────────────────┐
│                  │        REST         │        gRPC           │
├──────────────────┼─────────────────────┼───────────────────────┤
│ 協議             │  HTTP/1.1           │  HTTP/2               │
│ 序列化           │  JSON（文本）        │  Protobuf（二進制）    │
│ 效能             │  較慢               │  快 5~10 倍           │
│ 可讀性           │  ✅ 高（人可以讀）   │  ❌ 低（二進制）        │
│ 通訊模式         │  請求-響應           │  單向/雙向流            │
│ 強類型           │  ❌（JSON 弱類型）   │  ✅（Protobuf Schema）  │
│ 瀏覽器支援       │  ✅ 原生支援         │  ❌（需要 gRPC-Web）    │
│ 跨語言           │  ✅                 │  ✅                   │
│ 代碼生成         │  需要 OpenAPI/Swagger│  自動生成              │
│ 適用場景         │  對外 API、公開接口   │  微服務內部通訊         │
└──────────────────┴─────────────────────┴───────────────────────┘
```
