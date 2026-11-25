# GraphQL（靈活查詢語言）

## 核心概念

```
GraphQL 解決的問題：

REST 的問題：
  ❌ Over-fetching：返回太多不需要的欄位
     GET /users/123 → 返回 50 個欄位，但我只需要 name 和 email

  ❌ Under-fetching：一個頁面需要多次請求
     GET /users/123       → 取用戶資料
     GET /orders?userId=123 → 取訂單列表
     GET /products/xxx    → 取商品詳情
     需要 3 次請求！

GraphQL 的解決方式：
  客戶端精確描述「我需要什麼」
  服務器只返回需要的欄位
  一次請求可以取多個資源

三個核心操作：
  Query（查詢）：讀取數據，類似 GET
  Mutation（變更）：寫入/修改/刪除，類似 POST/PUT/DELETE
  Subscription（訂閱）：實時數據推送，類似 WebSocket
```

## Spring Boot 整合 GraphQL

```xml
<!-- pom.xml（Spring Boot 3.x 內建 GraphQL 支援）-->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-graphql</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
```

```graphql
# src/main/resources/graphql/schema.graphqls

# ──── 類型定義 ────

type User {
    id:        ID!
    username:  String!
    email:     String!
    orders(page: Int = 0, size: Int = 10): [Order!]!
    createdAt: String!
}

type Order {
    id:        ID!
    status:    OrderStatus!
    amount:    Float!
    items:     [OrderItem!]!
    user:      User!
    createdAt: String!
}

type OrderItem {
    product:   Product!
    quantity:  Int!
    price:     Float!
}

type Product {
    id:          ID!
    name:        String!
    price:       Float!
    description: String
    category:    String!
    stock:       Int!
}

enum OrderStatus {
    PENDING
    PAID
    SHIPPED
    DELIVERED
    CANCELLED
}

# ──── 分頁類型 ────
type PageInfo {
    total:      Int!
    page:       Int!
    size:       Int!
    totalPages: Int!
}

type ProductConnection {
    items:    [Product!]!
    pageInfo: PageInfo!
}

# ──── 輸入類型 ────
input CreateOrderInput {
    userId:  ID!
    address: String!
    items:   [OrderItemInput!]!
}

input OrderItemInput {
    productId: ID!
    quantity:  Int!
}

input ProductFilterInput {
    keyword:  String
    category: String
    minPrice: Float
    maxPrice: Float
}

# ──── 根類型 ────
type Query {
    # 用戶查詢
    user(id: ID!):     User
    me:                User

    # 商品查詢
    product(id: ID!):  Product
    products(
        filter: ProductFilterInput,
        page:   Int = 0,
        size:   Int = 20,
        sort:   String = "id"
    ): ProductConnection!

    # 訂單查詢
    order(id: ID!):    Order
    myOrders(
        status: OrderStatus,
        page:   Int = 0,
        size:   Int = 10
    ): [Order!]!
}

type Mutation {
    createOrder(input: CreateOrderInput!): Order!
    cancelOrder(id: ID!, reason: String): Order!
    updateProductStock(id: ID!, quantity: Int!): Product!
}

type Subscription {
    orderStatusChanged(orderId: ID!): Order!
}
```

```java
// GraphQL Controller（@Controller，不是 @RestController）

// ──── Query 解析器 ────
@Controller
@RequiredArgsConstructor
public class UserGraphQLController {

    private final UserService    userService;
    private final OrderService   orderService;

    @QueryMapping  // 對應 schema 中的 query.user
    public User user(@Argument Long id) {
        return userService.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("用戶不存在：" + id));
    }

    @QueryMapping
    public User me(@AuthenticationPrincipal UserPrincipal currentUser) {
        return userService.findById(currentUser.getId()).orElseThrow();
    }

    // 解析 User.orders 欄位（N+1 問題：用 DataLoader 解決）
    @SchemaMapping(typeName = "User", field = "orders")
    public CompletableFuture<List<Order>> orders(
            User user,
            @Argument int page,
            @Argument int size,
            DataLoader<Long, List<Order>> orderLoader) {
        // DataLoader 自動批量合併 N 個用戶的訂單查詢為 1 個查詢！
        return orderLoader.load(user.getId());
    }
}

@Controller
@RequiredArgsConstructor
public class ProductGraphQLController {

    private final ProductService productService;

    @QueryMapping
    public Product product(@Argument Long id) {
        return productService.findById(id).orElseThrow();
    }

    @QueryMapping
    public ProductConnection products(
            @Argument ProductFilterInput filter,
            @Argument int page,
            @Argument int size,
            @Argument String sort) {

        Page<Product> productPage = productService.search(filter, page, size, sort);

        return ProductConnection.builder()
            .items(productPage.getContent())
            .pageInfo(PageInfo.builder()
                .total((int) productPage.getTotalElements())
                .page(page)
                .size(size)
                .totalPages(productPage.getTotalPages())
                .build())
            .build();
    }
}

// ──── Mutation 解析器 ────
@Controller
@RequiredArgsConstructor
public class OrderGraphQLController {

    private final OrderService              orderService;
    private final SimpMessagingTemplate     messagingTemplate;

    @MutationMapping
    public Order createOrder(@Argument CreateOrderInput input,
                              @AuthenticationPrincipal UserPrincipal user) {
        return orderService.create(input, user.getId());
    }

    @MutationMapping
    public Order cancelOrder(@Argument Long id,
                              @Argument String reason) {
        return orderService.cancel(id, reason);
    }

    // ──── Subscription 解析器 ────
    @SubscriptionMapping
    public Flux<Order> orderStatusChanged(@Argument Long orderId) {
        // 返回 Flux（響應式流），每次訂單狀態變化都推送
        return orderService.watchOrderStatus(orderId)
            .map(status -> orderService.findById(orderId).orElseThrow());
    }
}

// ──── DataLoader（解決 N+1 問題）────
@Configuration
public class DataLoaderConfig {

    @Bean
    public BatchLoaderRegistry batchLoaderRegistry(OrderService orderService) {
        BatchLoaderRegistry registry = new DefaultBatchLoaderRegistry();

        // 批量加載用戶的訂單（多個用戶的訂單查詢合併為一次）
        registry.forTypePair(Long.class, List.class)
            .withName("orderLoader")
            .registerBatchLoader((userIds, env) -> {
                // userIds = [1, 2, 3, 4, 5]（所有需要查訂單的用戶 ID）
                Map<Long, List<Order>> orderMap =
                    orderService.findByUserIds(new ArrayList<>(userIds));
                // 返回與 userIds 順序對應的結果
                return Flux.fromIterable(userIds)
                    .map(id -> orderMap.getOrDefault(id, Collections.emptyList()));
            });

        return registry;
    }
}
```

```yaml
# application.yml
spring:
  graphql:
    graphiql:
      enabled: true    # 開啟 GraphiQL 瀏覽器（開發環境）
      path: /graphiql
    path: /graphql     # GraphQL 端點路徑
    websocket:
      path: /graphql-ws  # Subscription 用 WebSocket
    schema:
      printer:
        enabled: true  # 打印 Schema（開發用）
```

```graphql
# 客戶端查詢範例

# ① 精確取需要的欄位
query GetUserProfile {
    me {
        id
        username
        email
        # 只取最近 5 個訂單，只要 id 和 status
        orders(page: 0, size: 5) {
            id
            status
            amount
        }
    }
}

# ② 一次請求取多個資源
query GetOrderDetail($orderId: ID!) {
    order(id: $orderId) {
        id
        status
        amount
        user {
            username
            email
        }
        items {
            quantity
            price
            product {
                name
                imageUrl
            }
        }
    }
}

# ③ 商品搜索
query SearchProducts($keyword: String!, $page: Int) {
    products(
        filter: { keyword: $keyword, minPrice: 100, maxPrice: 5000 }
        page: $page
        size: 20
        sort: "rating"
    ) {
        items {
            id
            name
            price
            rating
        }
        pageInfo {
            total
            totalPages
        }
    }
}

# ④ Mutation
mutation CreateNewOrder($input: CreateOrderInput!) {
    createOrder(input: $input) {
        id
        status
        amount
    }
}

# ⑤ Subscription（即時訂閱）
subscription WatchOrder($orderId: ID!) {
    orderStatusChanged(orderId: $orderId) {
        id
        status
        updatedAt
    }
}
```

## GraphQL vs REST 比較

```
┌──────────────────┬─────────────────────┬───────────────────────┐
│                  │        REST         │       GraphQL         │
├──────────────────┼─────────────────────┼───────────────────────┤
│ 數據獲取          │ 固定結構             │ 客戶端自定義           │
│ Over-fetching    │ ❌ 常見              │ ✅ 完全避免            │
│ Under-fetching   │ ❌ 常見              │ ✅ 一次請求解決        │
│ API 端點         │ 多個（每個資源一個）   │ 單一（/graphql）       │
│ 版本管理          │ 需要（v1, v2）       │ 不需要（欄位演化）      │
│ 學習曲線          │ ✅ 低               │ ❌ 較高               │
│ 快取             │ ✅ HTTP 快取         │ ❌ 較複雜（需 Apollo）  │
│ N+1 問題         │ 需手動處理           │ DataLoader 解決        │
│ 文件             │ Swagger/OpenAPI     │ GraphiQL（自文件化）    │
│ 適用場景          │ 公開 API、簡單場景   │ 複雜前端需求、BFF 層    │
└──────────────────┴─────────────────────┴───────────────────────┘

BFF（Backend For Frontend）模式：
  不同客戶端（Web / iOS / Android）有不同的數據需求
  GraphQL 作為 BFF 層，各客戶端按需查詢
  避免為每個客戶端維護不同的 REST API
```
