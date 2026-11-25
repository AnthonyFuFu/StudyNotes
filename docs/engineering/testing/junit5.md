# JUnit 5 深入

!!! abstract "本章重點"

    JUnit 5 是 Java 測試的基礎框架。本章介紹核心註解、生命週期、AssertJ 流暢斷言、參數化測試，以及用巢狀測試讓測試結構更好讀。

## 依賴設定

```xml
<!-- pom.xml -->
<dependencies>
    <!-- Spring Boot 測試（已包含 JUnit 5 + Mockito + AssertJ）-->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-test</artifactId>
        <scope>test</scope>
    </dependency>

    <!-- Testcontainers -->
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.testcontainers</groupId>
        <artifactId>mysql</artifactId>
        <scope>test</scope>
    </dependency>
</dependencies>
```

## JUnit 5 核心注解

```java
// 基礎測試結構
@DisplayName("訂單服務測試")   // 測試類的顯示名稱
class OrderServiceTest {

    private OrderService  orderService;
    private OrderRepository orderRepository;

    // ─── 生命週期 ───

    @BeforeAll  // 所有測試前執行一次（必須是 static）
    static void setUpAll() {
        System.out.println("初始化測試環境（整個類只執行一次）");
    }

    @AfterAll   // 所有測試後執行一次（必須是 static）
    static void tearDownAll() {
        System.out.println("清理測試環境");
    }

    @BeforeEach // 每個測試前執行
    void setUp() {
        orderRepository = Mockito.mock(OrderRepository.class);
        orderService    = new OrderService(orderRepository);
    }

    @AfterEach  // 每個測試後執行
    void tearDown() {
        Mockito.reset(orderRepository);
    }

    // ─── 測試方法 ───

    @Test
    @DisplayName("建立訂單 - 正常情況")
    void createOrder_ShouldSuccess_WhenValidRequest() {
        // 測試內容...
    }

    @Test
    @DisplayName("建立訂單 - 庫存不足時拋出例外")
    void createOrder_ShouldThrowException_WhenInsufficientStock() {
        // 測試內容...
    }

    @Disabled("暫時停用：等待 API 確認")  // 跳過此測試
    @Test
    void temporarilyDisabledTest() { }
}
```

## AssertJ 斷言（推薦，比 JUnit 原生斷言更強）

```java
import static org.assertj.core.api.Assertions.*;

@Test
@DisplayName("斷言範例")
void assertionExamples() {

    // ─── 基本斷言 ───
    assertThat(1 + 1).isEqualTo(2);
    assertThat("Hello").isNotNull()
                       .startsWith("H")
                       .endsWith("o")
                       .hasSize(5)
                       .isEqualToIgnoringCase("hello");

    // ─── 數字斷言 ───
    assertThat(3.14).isGreaterThan(3.0)
                    .isLessThan(4.0)
                    .isBetween(3.0, 4.0);

    // ─── 集合斷言 ───
    List<String> list = List.of("Apple", "Banana", "Cherry");
    assertThat(list).isNotEmpty()
                    .hasSize(3)
                    .contains("Apple", "Banana")
                    .doesNotContain("Durian")
                    .containsExactlyInAnyOrder("Cherry", "Apple", "Banana");

    // ─── 例外斷言 ───
    assertThatThrownBy(() -> orderService.findById(-1L))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessage("ID 不能為負數")
        .hasMessageContaining("負數");

    assertThatExceptionOfType(ResourceNotFoundException.class)
        .isThrownBy(() -> orderService.findById(999L))
        .withMessage("訂單不存在：999");

    // 確保不拋出例外
    assertThatNoException().isThrownBy(() -> orderService.findById(1L));

    // ─── 對象斷言 ───
    Order order = orderService.findById(1L);
    assertThat(order).isNotNull()
                     .extracting(Order::getId, Order::getStatus)
                     .containsExactly(1L, OrderStatus.PAID);

    // ─── 多個斷言（軟斷言，全部執行後再報告所有失敗）───
    SoftAssertions softly = new SoftAssertions();
    softly.assertThat(order.getId()).isEqualTo(1L);
    softly.assertThat(order.getStatus()).isEqualTo(OrderStatus.PAID);
    softly.assertThat(order.getAmount()).isGreaterThan(BigDecimal.ZERO);
    softly.assertAll();  // 收集所有失敗，一次性報告
}
```

## 參數化測試（Parameterized Test）

```java
// 用同一個測試邏輯測試多組數據

@ParameterizedTest
@DisplayName("不同金額的折扣計算")
@CsvSource({
    "100.0,  0.9,  90.0",    // 100 元九折 = 90
    "200.0,  0.8,  160.0",   // 200 元八折 = 160
    "500.0,  0.7,  350.0",   // 500 元七折 = 350
    "1000.0, 0.5,  500.0"    // 1000 元五折 = 500
})
void calculateDiscount_ShouldReturnCorrectAmount(
        double originalPrice,
        double discountRate,
        double expectedPrice) {

    BigDecimal result = discountService.calculate(
        new BigDecimal(originalPrice),
        new BigDecimal(discountRate)
    );

    assertThat(result).isEqualByComparingTo(new BigDecimal(expectedPrice));
}

// ValueSource（單一參數）
@ParameterizedTest
@ValueSource(strings = {"", " ", "  ", "\t", "\n"})
@DisplayName("空白用戶名應該驗證失敗")
void validate_ShouldFail_WhenUsernameIsBlank(String username) {
    assertThatThrownBy(() -> userService.create(username, "password"))
        .isInstanceOf(IllegalArgumentException.class);
}

// EnumSource（枚舉參數）
@ParameterizedTest
@EnumSource(value = OrderStatus.class,
            names  = {"SHIPPED", "DELIVERED"},
            mode   = EnumSource.Mode.INCLUDE)
@DisplayName("已出貨/已送達的訂單不能取消")
void cancelOrder_ShouldFail_WhenOrderShippedOrDelivered(
        OrderStatus status) {

    Order order = Order.builder().id(1L).status(status).build();
    when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

    assertThatThrownBy(() -> orderService.cancel(1L, "不想要了"))
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("無法取消");
}

// MethodSource（複雜參數，從方法取得）
@ParameterizedTest
@MethodSource("invalidOrderRequests")
@DisplayName("非法訂單請求應該驗證失敗")
void createOrder_ShouldFail_WhenRequestInvalid(
        CreateOrderRequest request,
        String expectedError) {

    assertThatThrownBy(() -> orderService.create(request))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessageContaining(expectedError);
}

static Stream<Arguments> invalidOrderRequests() {
    return Stream.of(
        Arguments.of(
            CreateOrderRequest.builder().userId(null).build(),
            "用戶ID不能為空"
        ),
        Arguments.of(
            CreateOrderRequest.builder().userId(1L).items(List.of()).build(),
            "訂單項目不能為空"
        ),
        Arguments.of(
            CreateOrderRequest.builder().userId(-1L).build(),
            "用戶ID不合法"
        )
    );
}
```

## 條件測試與巢狀測試

```java
@DisplayName("訂單服務測試")
class OrderServiceTest {

    // 巢狀測試（按業務場景分組）
    @Nested
    @DisplayName("建立訂單")
    class CreateOrderTests {

        @Test
        @DisplayName("正常建立訂單成功")
        void shouldCreateOrderSuccessfully() { ... }

        @Test
        @DisplayName("庫存不足時失敗")
        void shouldFailWhenInsufficientStock() { ... }

        @Nested
        @DisplayName("金額驗證")
        class AmountValidationTests {

            @Test
            @DisplayName("金額為零時應該失敗")
            void shouldFailWhenAmountIsZero() { ... }

            @Test
            @DisplayName("金額為負數時應該失敗")
            void shouldFailWhenAmountIsNegative() { ... }
        }
    }

    @Nested
    @DisplayName("取消訂單")
    class CancelOrderTests {

        @Test
        @DisplayName("待付款訂單可以取消")
        void shouldCancelPendingOrder() { ... }
    }

    // 條件測試（根據條件決定是否執行）
    @Test
    @EnabledOnOs(OS.LINUX)              // 只在 Linux 上執行
    void shouldRunOnLinuxOnly() { ... }

    @Test
    @EnabledIfEnvironmentVariable(
        named  = "TEST_ENV",
        matches = "staging"
    )
    void shouldRunInStagingOnly() { ... }

    @Test
    @EnabledIfSystemProperty(
        named  = "java.version",
        matches = "17.*"
    )
    void shouldRunOnJava17() { ... }
}
```
