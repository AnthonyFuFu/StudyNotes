# Testcontainers（真實環境整合測試）

!!! abstract "本章重點"

    用 H2 或 Mock 測試，常常跟正式環境的行為不一致。Testcontainers 在測試時用 Docker 啟動真正的 MySQL、Redis、Kafka；本章說明原理、整合方式，以及搭配 Flyway 管理測試資料。

## 核心原理

**問題**

- @DataJpaTest 使用 H2 記憶體資料庫
- 但 H2 語法和 MySQL 不完全兼容！
- 在 H2 通過的測試，在真實 MySQL 可能失敗！

**Testcontainers 的解決方式**

- 在測試執行時，自動啟動 Docker 容器（真實的 MySQL）
- 測試完成後自動銷毀容器
- → 測試環境和生產環境完全一致！

**前提**

- 本地/CI 環境需要有 Docker

## 整合 MySQL + Redis

=== "方式一：每個測試類獨立容器"

    ``` java
    // 方式一：每個測試類獨立容器（隔離性好，但慢）
    @SpringBootTest
    @Testcontainers
    class OrderRepositoryTest {

        @Container
        static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test")
            .withInitScript("sql/init.sql");  // 初始化 SQL

        @Container
        static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
            .withExposedPorts(6379);

        // 動態設定數據源（Container 啟動後才知道端口）
        @DynamicPropertySource
        static void configureProperties(DynamicPropertyRegistry registry) {
            registry.add("spring.datasource.url",      mysql::getJdbcUrl);
            registry.add("spring.datasource.username", mysql::getUsername);
            registry.add("spring.datasource.password", mysql::getPassword);
            registry.add("spring.redis.host",          redis::getHost);
            registry.add("spring.redis.port",
                () -> redis.getMappedPort(6379));
        }
    }

    // 方式二：共享容器（所有測試類共用，速度快）✅ 推薦
    ```

=== "1. 定義基礎類"

    ``` java
    // 1. 定義基礎類（所有整合測試繼承它）
    @SpringBootTest
    @ActiveProfiles("test")
    public abstract class BaseIntegrationTest {

        // static + @Container → 所有測試共用同一個容器
        @Container
        protected static final MySQLContainer<?> MYSQL =
            new MySQLContainer<>("mysql:8.0")
                .withDatabaseName("testdb")
                .withUsername("test")
                .withPassword("test")
                .withReuse(true);  // 開啟容器複用（更快！）

        @Container
        protected static final GenericContainer<?> REDIS =
            new GenericContainer<>("redis:7-alpine")
                .withExposedPorts(6379)
                .withReuse(true);

        @Container
        protected static final KafkaContainer KAFKA =
            new KafkaContainer(DockerImageName.parse("confluentinc/cp-kafka:7.4.0"))
                .withReuse(true);

        static {
            // Ryuk 容器管理（自動清理）
            Startables.deepStart(MYSQL, REDIS, KAFKA).join();
        }

        @DynamicPropertySource
        static void configureProperties(DynamicPropertyRegistry registry) {
            // MySQL
            registry.add("spring.datasource.url",      MYSQL::getJdbcUrl);
            registry.add("spring.datasource.username", MYSQL::getUsername);
            registry.add("spring.datasource.password", MYSQL::getPassword);

            // Redis
            registry.add("spring.redis.host",
                REDIS::getHost);
            registry.add("spring.redis.port",
                () -> REDIS.getMappedPort(6379));

            // Kafka
            registry.add("spring.kafka.bootstrap-servers",
                KAFKA::getBootstrapServers);
        }
    }
    ```

=== "2. 繼承基礎類"

    ``` java
    // 2. 繼承基礎類
    @Testcontainers
    class OrderServiceIntegrationTest extends BaseIntegrationTest {

        @Autowired
        private OrderService    orderService;

        @Autowired
        private OrderRepository orderRepository;

        @BeforeEach
        void setUp() {
            orderRepository.deleteAll();
        }

        @Test
        @DisplayName("完整訂單建立 + 查詢流程（真實 MySQL）")
        void createAndQueryOrder_WithRealMySQL() {
            // Act
            CreateOrderRequest request = CreateOrderRequest.builder()
                .userId(1L)
                .address("台北市")
                .items(List.of(new OrderItemRequest(1L, 3)))
                .build();

            Order created = orderService.create(request);

            // 從真實 MySQL 查詢
            Order fromDb = orderRepository.findById(created.getId()).orElseThrow();

            assertThat(fromDb.getUserId()).isEqualTo(1L);
            assertThat(fromDb.getStatus()).isEqualTo(OrderStatus.PENDING);
        }

        @Test
        @DisplayName("Redis 緩存測試（真實 Redis）")
        void getOrder_ShouldUseCache_WithRealRedis() {
            // 第一次查詢（從 DB，並寫入 Redis）
            Order order = orderService.findById(1L);

            // 第二次查詢（應該從 Redis 取）
            Order cached = orderService.findById(1L);

            // 驗證 DB 只被查詢了一次
            verify(orderRepository, times(1)).findById(1L);
            assertThat(cached).isEqualTo(order);
        }
    }
    ```


## Kafka 整合測試

```java
@Testcontainers
class OrderEventIntegrationTest extends BaseIntegrationTest {

    @Autowired
    private KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate;

    @Autowired
    private OrderEventConsumer orderEventConsumer;

    @Test
    @DisplayName("訂單事件 Kafka 生產者/消費者整合測試")
    void orderEvent_ShouldBeConsumedSuccessfully() throws Exception {
        // 使用 CountDownLatch 等待消費者處理
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<OrderCreatedEvent> receivedEvent = new AtomicReference<>();

        // Mock 消費者的處理邏輯（或驗證副作用）
        doAnswer(invocation -> {
            receivedEvent.set(invocation.getArgument(0));
            latch.countDown();
            return null;
        }).when(orderEventConsumer).handleOrderCreated(any());

        // 發送事件
        OrderCreatedEvent event = new OrderCreatedEvent(1L, 1L, new BigDecimal("500"));
        kafkaTemplate.send("order-created", event);

        // 等待消費者處理（最多 10 秒）
        boolean consumed = latch.await(10, TimeUnit.SECONDS);

        assertThat(consumed).isTrue();
        assertThat(receivedEvent.get().getOrderId()).isEqualTo(1L);
    }
}
```

## Flyway 與測試資料管理

```java
// 使用 @Sql 執行測試 SQL
@DataJpaTest
class OrderRepositoryTest {

    @Autowired
    private OrderRepository orderRepository;

    @Test
    @Sql("/sql/insert-test-orders.sql")  // 測試前執行 SQL
    @Sql(scripts = "/sql/clean-orders.sql",
         executionPhase = Sql.ExecutionPhase.AFTER_TEST_METHOD)  // 測試後清理
    void findByUserId_ShouldReturnOrders() {
        List<Order> orders = orderRepository.findByUserId(1L);
        assertThat(orders).hasSize(3);
    }
}
```

```sql
-- src/test/resources/sql/insert-test-orders.sql
INSERT INTO orders (id, user_id, status, amount, created_at)
VALUES (1, 1, 'PAID',    500.00, '2024-01-01 10:00:00'),
       (2, 1, 'PENDING', 300.00, '2024-01-02 10:00:00'),
       (3, 1, 'PAID',    200.00, '2024-01-03 10:00:00'),
       (4, 2, 'PAID',    150.00, '2024-01-04 10:00:00');
```

!!! example "我的實作：CI 中的真實環境測試"

    holidayDessert 在 GitHub Actions 中以 `services` 啟動 MySQL 8 與 Redis 7 容器執行測試，與 Testcontainers 的目的相同：用真實的資料庫行為驗證程式。

    👉 [實戰：我的 CI/CD 與 K8s 部署](../cicd/my-pipelines.md)
