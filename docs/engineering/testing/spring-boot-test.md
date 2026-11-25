# Spring Boot Test

## 測試切片（Test Slices）

```
Spring Boot 提供多種測試切片，只加載相關的 Bean：

@SpringBootTest    → 加載完整應用上下文（最慢，適合整合測試）
@WebMvcTest        → 只加載 Web 層（Controller、Filter、Interceptor）
@DataJpaTest       → 只加載 JPA 相關（Repository、DataSource）
@JsonTest          → 只加載 JSON 序列化相關
@RestClientTest    → 只加載 RestTemplate 相關

選擇原則：
  Controller 層測試 → @WebMvcTest
  Repository 層測試 → @DataJpaTest
  Service 層測試    → 不用 Spring，直接 JUnit + Mockito（最快！）
  整合測試          → @SpringBootTest + Testcontainers
```

## @WebMvcTest（Controller 層測試）

```java
@WebMvcTest(OrderController.class)  // 只加載 OrderController
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;  // 模擬 HTTP 請求，不啟動真實服務器

    @MockBean  // 替換 Spring Context 中的 Bean
    private OrderService orderService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    @DisplayName("GET /api/v1/orders/{id} - 查詢訂單成功")
    void getOrder_ShouldReturn200_WhenOrderExists() throws Exception {
        // Arrange
        OrderDTO orderDTO = OrderDTO.builder()
            .id(1L)
            .status("PAID")
            .amount(new BigDecimal("500"))
            .build();

        when(orderService.findById(1L)).thenReturn(orderDTO);

        // Act & Assert
        mockMvc.perform(get("/api/v1/orders/1")
                .header("Authorization", "Bearer " + validJwtToken)
                .contentType(MediaType.APPLICATION_JSON))
            .andDo(print())  // 打印請求/響應詳情（調試用）
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.success").value(true))
            .andExpect(jsonPath("$.data.id").value(1))
            .andExpect(jsonPath("$.data.status").value("PAID"))
            .andExpect(jsonPath("$.data.amount").value(500));
    }

    @Test
    @DisplayName("GET /api/v1/orders/{id} - 訂單不存在返回 404")
    void getOrder_ShouldReturn404_WhenOrderNotFound() throws Exception {
        when(orderService.findById(999L))
            .thenThrow(new ResourceNotFoundException("訂單不存在：999"));

        mockMvc.perform(get("/api/v1/orders/999")
                .header("Authorization", "Bearer " + validJwtToken))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.code").value("RESOURCE_001"));
    }

    @Test
    @DisplayName("POST /api/v1/orders - 建立訂單成功，返回 201")
    void createOrder_ShouldReturn201_WhenRequestValid() throws Exception {
        // Arrange
        CreateOrderRequest request = CreateOrderRequest.builder()
            .userId(1L)
            .address("台北市信義區")
            .items(List.of(new OrderItemRequest(1L, 2)))
            .build();

        OrderDTO createdOrder = OrderDTO.builder()
            .id(100L)
            .status("PENDING")
            .amount(new BigDecimal("200"))
            .build();

        when(orderService.create(any())).thenReturn(createdOrder);

        // Act & Assert
        mockMvc.perform(post("/api/v1/orders")
                .header("Authorization", "Bearer " + validJwtToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())  // 201
            .andExpect(header().exists("Location"))  // Location 頭
            .andExpect(jsonPath("$.data.id").value(100))
            .andExpect(jsonPath("$.data.status").value("PENDING"));
    }

    @Test
    @DisplayName("POST /api/v1/orders - 請求體驗證失敗，返回 400")
    void createOrder_ShouldReturn400_WhenRequestInvalid() throws Exception {
        // 缺少必填欄位
        String invalidRequest = "{\"userId\": null}";

        mockMvc.perform(post("/api/v1/orders")
                .header("Authorization", "Bearer " + validJwtToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidRequest))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.success").value(false))
            .andExpect(jsonPath("$.data.userId").exists());  // 欄位錯誤資訊
    }

    @Test
    @DisplayName("未帶 Token 訪問受保護接口，返回 401")
    void protectedEndpoint_ShouldReturn401_WhenNoToken() throws Exception {
        mockMvc.perform(get("/api/v1/orders/1"))
            .andExpect(status().isUnauthorized());
    }
}
```

## @DataJpaTest（Repository 層測試）

```java
@DataJpaTest  // 只加載 JPA 相關，使用 H2 記憶體資料庫
@DisplayName("訂單 Repository 測試")
class OrderRepositoryTest {

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private TestEntityManager entityManager;  // 專為測試設計的 EntityManager

    private Order savedOrder;

    @BeforeEach
    void setUp() {
        // 準備測試數據
        Order order = Order.builder()
            .userId(1L)
            .status(OrderStatus.PAID)
            .amount(new BigDecimal("500"))
            .address("台北市")
            .createdAt(LocalDateTime.now())
            .build();

        savedOrder = entityManager.persistAndFlush(order);
    }

    @Test
    @DisplayName("根據 ID 查詢訂單")
    void findById_ShouldReturnOrder_WhenExists() {
        Optional<Order> found = orderRepository.findById(savedOrder.getId());

        assertThat(found).isPresent()
                         .get()
                         .extracting(Order::getUserId, Order::getStatus)
                         .containsExactly(1L, OrderStatus.PAID);
    }

    @Test
    @DisplayName("根據用戶 ID 查詢訂單列表")
    void findByUserId_ShouldReturnOrders() {
        // 再建立一個同用戶的訂單
        Order order2 = Order.builder()
            .userId(1L)
            .status(OrderStatus.PENDING)
            .amount(new BigDecimal("200"))
            .build();
        entityManager.persistAndFlush(order2);

        List<Order> orders = orderRepository.findByUserId(1L);

        assertThat(orders).hasSize(2)
                          .extracting(Order::getUserId)
                          .containsOnly(1L);
    }

    @Test
    @DisplayName("根據狀態和金額範圍查詢")
    void findByStatusAndAmountBetween() {
        List<Order> orders = orderRepository
            .findByStatusAndAmountBetween(
                OrderStatus.PAID,
                new BigDecimal("100"),
                new BigDecimal("1000")
            );

        assertThat(orders).isNotEmpty()
                          .allMatch(o -> o.getStatus() == OrderStatus.PAID)
                          .allMatch(o ->
                              o.getAmount().compareTo(new BigDecimal("100")) >= 0 &&
                              o.getAmount().compareTo(new BigDecimal("1000")) <= 0
                          );
    }

    @Test
    @DisplayName("保存訂單 - 驗證自動填充欄位")
    void save_ShouldAutoFillAuditFields() {
        Order newOrder = Order.builder()
            .userId(2L)
            .status(OrderStatus.PENDING)
            .amount(new BigDecimal("300"))
            .build();

        Order saved = orderRepository.save(newOrder);
        entityManager.flush();
        entityManager.clear();  // 清除一級緩存，確保從 DB 讀取

        Order fromDb = orderRepository.findById(saved.getId()).orElseThrow();
        assertThat(fromDb.getCreatedAt()).isNotNull();
        assertThat(fromDb.getUpdatedAt()).isNotNull();
    }

    @Test
    @DisplayName("分頁查詢")
    void findAll_WithPagination() {
        // 建立更多測試數據
        for (int i = 0; i < 15; i++) {
            entityManager.persist(Order.builder()
                .userId(1L)
                .status(OrderStatus.PAID)
                .amount(new BigDecimal(100 + i))
                .build());
        }
        entityManager.flush();

        Page<Order> page = orderRepository.findByUserId(
            1L, PageRequest.of(0, 10, Sort.by("amount").descending())
        );

        assertThat(page.getContent()).hasSize(10);
        assertThat(page.getTotalElements()).isGreaterThanOrEqualTo(16);
        // 驗證排序（金額由大到小）
        assertThat(page.getContent())
            .extracting(Order::getAmount)
            .isSortedAccordingTo(Comparator.reverseOrder());
    }
}
```

## @SpringBootTest（整合測試）

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class OrderIntegrationTest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;  // 真實 HTTP 客戶端

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    private String authToken;

    @BeforeEach
    void setUp() {
        orderRepository.deleteAll();
        authToken = "Bearer " + generateTestToken();
    }

    @Test
    @DisplayName("完整訂單建立流程")
    void createOrderFullFlow() {
        // 1. 建立訂單
        CreateOrderRequest request = CreateOrderRequest.builder()
            .userId(1L)
            .address("台北市信義區")
            .items(List.of(new OrderItemRequest(1L, 2)))
            .build();

        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", authToken);
        headers.setContentType(MediaType.APPLICATION_JSON);

        ResponseEntity<ApiResponse> createResponse = restTemplate.exchange(
            "http://localhost:" + port + "/api/v1/orders",
            HttpMethod.POST,
            new HttpEntity<>(request, headers),
            ApiResponse.class
        );

        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(createResponse.getHeaders().getLocation()).isNotNull();

        // 2. 查詢剛建立的訂單
        Long orderId = extractOrderId(createResponse.getHeaders().getLocation());
        ResponseEntity<ApiResponse> getResponse = restTemplate.exchange(
            "http://localhost:" + port + "/api/v1/orders/" + orderId,
            HttpMethod.GET,
            new HttpEntity<>(headers),
            ApiResponse.class
        );

        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);

        // 3. 驗證資料庫中的數據
        Optional<Order> savedOrder = orderRepository.findById(orderId);
        assertThat(savedOrder).isPresent()
                              .get()
                              .extracting(Order::getStatus)
                              .isEqualTo(OrderStatus.PENDING);
    }
}
```
