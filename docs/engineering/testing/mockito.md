# Mockito 深入

## Mock / Stub / Spy 的區別

**Mock（模擬）**

- 完全虛假的對象，所有方法都返回預設值（null / 0 / false）
- 用來隔離測試對象的依賴
- Mockito.mock(OrderRepository.class)

**Stub（存根）**

- 為 Mock 對象的方法設定返回值
- when(mock.method()).thenReturn(value)

**Spy（間諜）**

- 包裝真實對象，默認調用真實方法
- 可以選擇性 Stub 部分方法
- Mockito.spy(new OrderService())
- 用途：測試遺留代碼，只 Mock 部分方法

**Fake（偽造）**

- 一個有真實邏輯但簡化的實作
- 如：H2 記憶體資料庫（代替真實 MySQL）

## Mockito 完整 API

```java
@ExtendWith(MockitoExtension.class)  // JUnit 5 整合 Mockito
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private InventoryService inventoryService;

    @Mock
    private NotificationService notificationService;

    @InjectMocks  // 自動注入上面的 Mock 到被測對象
    private OrderService orderService;

    // ─── Stubbing（設定返回值）───

    @Test
    void stubbingExamples() {
        Order mockOrder = Order.builder()
            .id(1L)
            .status(OrderStatus.PENDING)
            .amount(new BigDecimal("500"))
            .build();

        // 基本 stubbing
        when(orderRepository.findById(1L))
            .thenReturn(Optional.of(mockOrder));

        // 連續返回不同值
        when(orderRepository.findById(2L))
            .thenReturn(Optional.empty())           // 第一次
            .thenReturn(Optional.of(mockOrder));    // 第二次以後

        // 拋出例外
        when(orderRepository.findById(-1L))
            .thenThrow(new IllegalArgumentException("ID 不能為負數"));

        // 根據參數動態返回值
        when(orderRepository.findById(anyLong()))
            .thenAnswer(invocation -> {
                Long id = invocation.getArgument(0);
                if (id > 0) {
                    return Optional.of(Order.builder().id(id).build());
                }
                return Optional.empty();
            });

        // void 方法
        doNothing().when(notificationService).send(any());          // 不做任何事
        doThrow(new RuntimeException("發送失敗"))
            .when(notificationService).send(any());                  // 拋出例外
        doAnswer(invocation -> {
            log.info("通知已發送（Mock）");
            return null;
        }).when(notificationService).send(any());                    // 自定義行為
    }

    // ─── 參數匹配器（Argument Matchers）───

    @Test
    void argumentMatchersExamples() {
        // any()：匹配任意值
        when(orderRepository.findByUserId(anyLong()))
            .thenReturn(List.of());

        // 精確值匹配（不能混用 any() 和精確值！）
        // ❌ 錯誤：when(repo.save(order, anyString()))
        // ✅ 正確：用 eq() 包裝精確值
        when(orderRepository.findByUserIdAndStatus(eq(1L), eq("PAID")))
            .thenReturn(List.of());

        // 自定義匹配器
        when(orderRepository.save(argThat(order ->
            order.getAmount().compareTo(BigDecimal.ZERO) > 0
        ))).thenReturn(new Order());

        // 常用匹配器
        anyString()           // 任意非 null 字串
        anyInt()              // 任意 int
        anyLong()             // 任意 long
        any(Order.class)      // 任意 Order 類型（包含 null）
        notNull()             // 非 null
        isNull()              // 為 null
        startsWith("ORDER-")  // 以 ORDER- 開頭的字串
    }

    // ─── 驗證行為（Verify）───

    @Test
    @DisplayName("建立訂單後應該發送通知")
    void createOrder_ShouldSendNotification() {
        // Arrange
        CreateOrderRequest request = CreateOrderRequest.builder()
            .userId(1L)
            .items(List.of(new OrderItem(1L, 2)))
            .build();

        when(inventoryService.checkAndReserve(anyLong(), anyInt()))
            .thenReturn(true);
        when(orderRepository.save(any()))
            .thenReturn(Order.builder().id(1L).build());

        // Act
        orderService.create(request);

        // Assert - 驗證方法被調用了
        verify(orderRepository, times(1)).save(any(Order.class));
        verify(notificationService, times(1)).send(any());
        verify(inventoryService, times(1))
            .checkAndReserve(eq(1L), eq(2));

        // 驗證不應該被調用
        verify(notificationService, never()).sendUrgent(any());

        // 驗證調用順序
        InOrder inOrder = inOrder(inventoryService, orderRepository, notificationService);
        inOrder.verify(inventoryService).checkAndReserve(anyLong(), anyInt());
        inOrder.verify(orderRepository).save(any());
        inOrder.verify(notificationService).send(any());

        // 驗證沒有其他未被驗證的互動
        verifyNoMoreInteractions(notificationService);

        // 驗證零互動
        verifyNoInteractions(notificationService);
    }
}
```

## ArgumentCaptor（捕獲參數）

```java
@Test
@DisplayName("建立訂單時，保存的訂單應包含正確資訊")
void createOrder_ShouldSaveOrderWithCorrectData() {
    // Arrange
    ArgumentCaptor<Order> orderCaptor =
        ArgumentCaptor.forClass(Order.class);

    CreateOrderRequest request = CreateOrderRequest.builder()
        .userId(1L)
        .address("台北市信義區")
        .items(List.of(
            new OrderItemRequest(1L, 2, new BigDecimal("100"))
        ))
        .build();

    when(orderRepository.save(any()))
        .thenAnswer(i -> i.getArgument(0));

    // Act
    orderService.create(request);

    // Assert - 捕獲 save() 的參數，驗證內容
    verify(orderRepository).save(orderCaptor.capture());
    Order savedOrder = orderCaptor.getValue();

    assertThat(savedOrder.getUserId()).isEqualTo(1L);
    assertThat(savedOrder.getAddress()).isEqualTo("台北市信義區");
    assertThat(savedOrder.getStatus()).isEqualTo(OrderStatus.PENDING);
    assertThat(savedOrder.getAmount()).isEqualByComparingTo(new BigDecimal("200"));

    // 捕獲多次調用的參數
    ArgumentCaptor<String> emailCaptor =
        ArgumentCaptor.forClass(String.class);
    verify(notificationService, times(2)).sendEmail(emailCaptor.capture());
    List<String> allEmails = emailCaptor.getAllValues();
    assertThat(allEmails).containsExactly("order@example.com", "user@example.com");
}
```

## Spy（間諜）使用

```java
@Test
@DisplayName("Spy 使用範例")
void spyExample() {
    // Spy 包裝真實對象
    List<String> realList = new ArrayList<>();
    List<String> spyList  = Mockito.spy(realList);

    // 大部分方法調用真實實作
    spyList.add("Apple");
    spyList.add("Banana");

    assertThat(spyList).hasSize(2);  // 真實的 size()

    // 只 Stub 特定方法
    doReturn(100).when(spyList).size();

    assertThat(spyList.size()).isEqualTo(100);   // Stub 的返回值
    assertThat(spyList.get(0)).isEqualTo("Apple"); // 真實的 get()

    // 驗證也適用於 Spy
    verify(spyList, times(2)).add(anyString());
}

// 實際業務場景：測試含有複雜邏輯的類
@Test
void realWorldSpyExample() {
    OrderService spyService = Mockito.spy(orderService);

    // 只 Stub 複雜的內部方法（如：呼叫外部 API）
    doReturn(new BigDecimal("0.1"))
        .when(spyService)
        .calculateTaxRate(anyString());

    // 測試真實的業務邏輯（稅率計算被 Stub）
    Order order = spyService.create(request);
    assertThat(order.getTax()).isEqualByComparingTo(new BigDecimal("10.0"));
}
```
