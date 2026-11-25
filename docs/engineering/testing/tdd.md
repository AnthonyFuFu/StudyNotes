# TDD（測試驅動開發）

## Red-Green-Refactor 循環

**TDD 三步驟**

- 1\. 🔴 Red（寫一個失敗的測試）
    - 先寫測試，此時生產代碼還不存在 → 測試必然失敗

- 2\. 🟢 Green（寫最少的代碼讓測試通過）
    - 不追求完美，只求讓測試通過（可以先 hardcode！）

- 3\. 🔵 Refactor（重構）
    - 在測試的保護下，改善代碼品質
    - 重構後重新執行測試，確保仍然通過

**好處**

- ✅ 強迫思考 API 設計（先想使用方式）
- ✅ 測試覆蓋率自然很高
- ✅ 重構有安全網（測試保護）
- ✅ 設計更簡潔（只實作需要的功能）

## TDD 完整實戰

需求：實作一個購物車服務

- 可以加入商品
- 可以移除商品
- 可以計算總金額
- 商品數量不能為負數
- 同一商品加入多次應該累加數量

```java
// ═══════════════════════════════════════
// 第一輪：加入商品功能
// ═══════════════════════════════════════

// Step 1 🔴 Red - 寫失敗的測試
class ShoppingCartTest {

    @Test
    @DisplayName("加入商品後，購物車應有一個商品")
    void addItem_ShouldHaveOneItem() {
        ShoppingCart cart = new ShoppingCart();
        cart.addItem("P001", "iPhone", new BigDecimal("30000"), 1);

        assertThat(cart.getItemCount()).isEqualTo(1);
    }
}
// ❌ 此時 ShoppingCart 類不存在 → 編譯失敗（Red）

// Step 2 🟢 Green - 寫最少代碼
public class ShoppingCart {
    private List<CartItem> items = new ArrayList<>();

    public void addItem(String productId, String name,
                        BigDecimal price, int quantity) {
        items.add(new CartItem(productId, name, price, quantity));
    }

    public int getItemCount() {
        return items.size();
    }
}
// ✅ 測試通過（Green）

// Step 3 🔵 Refactor - 改善代碼
// 暫時沒有需要重構的地方

// ═══════════════════════════════════════
// 第二輪：計算總金額
// ═══════════════════════════════════════

// Step 1 🔴 Red
@Test
@DisplayName("計算購物車總金額")
void calculateTotal_ShouldReturnCorrectAmount() {
    ShoppingCart cart = new ShoppingCart();
    cart.addItem("P001", "iPhone",  new BigDecimal("30000"), 1);
    cart.addItem("P002", "AirPods", new BigDecimal("6000"),  2);

    assertThat(cart.getTotal())
        .isEqualByComparingTo(new BigDecimal("42000")); // 30000 + 6000*2
}
// ❌ getTotal() 方法不存在（Red）

// Step 2 🟢 Green
public BigDecimal getTotal() {
    return items.stream()
        .map(item -> item.getPrice()
            .multiply(new BigDecimal(item.getQuantity())))
        .reduce(BigDecimal.ZERO, BigDecimal::add);
}
// ✅ 測試通過（Green）

// ═══════════════════════════════════════
// 第三輪：數量不能為負數
// ═══════════════════════════════════════

// Step 1 🔴 Red
@Test
@DisplayName("加入商品數量為負數時，應拋出例外")
void addItem_ShouldThrowException_WhenQuantityNegative() {
    ShoppingCart cart = new ShoppingCart();

    assertThatThrownBy(() ->
        cart.addItem("P001", "iPhone", new BigDecimal("30000"), -1))
        .isInstanceOf(IllegalArgumentException.class)
        .hasMessage("商品數量不能小於 1");
}
// ❌ 目前不會拋出例外（Red）

// Step 2 🟢 Green
public void addItem(String productId, String name,
                    BigDecimal price, int quantity) {
    if (quantity < 1) {
        throw new IllegalArgumentException("商品數量不能小於 1");
    }
    items.add(new CartItem(productId, name, price, quantity));
}
// ✅ 測試通過（Green）

// ═══════════════════════════════════════
// 第四輪：同一商品累加數量
// ═══════════════════════════════════════

// Step 1 🔴 Red
@Test
@DisplayName("加入相同商品時，應累加數量而非新增")
void addItem_ShouldAccumulateQuantity_WhenSameProduct() {
    ShoppingCart cart = new ShoppingCart();
    cart.addItem("P001", "iPhone", new BigDecimal("30000"), 1);
    cart.addItem("P001", "iPhone", new BigDecimal("30000"), 2);

    assertThat(cart.getItemCount()).isEqualTo(1);  // 仍然是 1 種商品
    assertThat(cart.getTotal())
        .isEqualByComparingTo(new BigDecimal("90000"));  // 30000 * 3
}
// ❌ 目前會加入兩個商品（Red）

// Step 2 🟢 Green
public void addItem(String productId, String name,
                    BigDecimal price, int quantity) {
    if (quantity < 1) {
        throw new IllegalArgumentException("商品數量不能小於 1");
    }

    // 查找是否已有此商品
    Optional<CartItem> existing = items.stream()
        .filter(item -> item.getProductId().equals(productId))
        .findFirst();

    if (existing.isPresent()) {
        existing.get().addQuantity(quantity); // 累加數量
    } else {
        items.add(new CartItem(productId, name, price, quantity));
    }
}
// ✅ 測試通過（Green）

// Step 3 🔵 Refactor
// 可以將查找邏輯提取為私有方法
private Optional<CartItem> findItem(String productId) {
    return items.stream()
        .filter(item -> item.getProductId().equals(productId))
        .findFirst();
}

// ═══════════════════════════════════════
// 最終完整的測試類
// ═══════════════════════════════════════

class ShoppingCartTest {

    private ShoppingCart cart;

    @BeforeEach
    void setUp() {
        cart = new ShoppingCart();
    }

    @Test
    @DisplayName("加入商品後，購物車應有一個商品")
    void addItem_ShouldHaveOneItem() {
        cart.addItem("P001", "iPhone", new BigDecimal("30000"), 1);
        assertThat(cart.getItemCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("計算購物車總金額")
    void calculateTotal_ShouldReturnCorrectAmount() {
        cart.addItem("P001", "iPhone",  new BigDecimal("30000"), 1);
        cart.addItem("P002", "AirPods", new BigDecimal("6000"),  2);
        assertThat(cart.getTotal())
            .isEqualByComparingTo(new BigDecimal("42000"));
    }

    @Test
    @DisplayName("加入商品數量為負數時，應拋出例外")
    void addItem_ShouldThrowException_WhenQuantityNegative() {
        assertThatThrownBy(() ->
            cart.addItem("P001", "iPhone", new BigDecimal("30000"), -1))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessage("商品數量不能小於 1");
    }

    @Test
    @DisplayName("加入相同商品時，應累加數量而非新增")
    void addItem_ShouldAccumulateQuantity_WhenSameProduct() {
        cart.addItem("P001", "iPhone", new BigDecimal("30000"), 1);
        cart.addItem("P001", "iPhone", new BigDecimal("30000"), 2);
        assertThat(cart.getItemCount()).isEqualTo(1);
        assertThat(cart.getTotal())
            .isEqualByComparingTo(new BigDecimal("90000"));
    }

    @Test
    @DisplayName("移除商品後，購物車應為空")
    void removeItem_ShouldEmptyCart() {
        cart.addItem("P001", "iPhone", new BigDecimal("30000"), 1);
        cart.removeItem("P001");
        assertThat(cart.getItemCount()).isEqualTo(0);
        assertThat(cart.getTotal()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    @DisplayName("清空購物車")
    void clear_ShouldRemoveAllItems() {
        cart.addItem("P001", "iPhone",  new BigDecimal("30000"), 1);
        cart.addItem("P002", "AirPods", new BigDecimal("6000"),  1);
        cart.clear();
        assertThat(cart.getItemCount()).isEqualTo(0);
    }
}
```

## 測試覆蓋率

```xml
<!-- JaCoCo 測試覆蓋率（Maven 配置）-->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <goals>
                <goal>prepare-agent</goal>
            </goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>test</phase>
            <goals>
                <goal>report</goal>
            </goals>
        </execution>
        <!-- 設定覆蓋率門檻（未達到則建置失敗）-->
        <execution>
            <id>check</id>
            <goals>
                <goal>check</goal>
            </goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.80</minimum>  <!-- 80% 行覆蓋率 -->
                            </limit>
                            <limit>
                                <counter>BRANCH</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.70</minimum>  <!-- 70% 分支覆蓋率 -->
                            </limit>
                        </limits>
                    </rule>
                </rules>
                <!-- 排除不需要測試的類 -->
                <excludes>
                    <exclude>**/config/**</exclude>
                    <exclude>**/dto/**</exclude>
                    <exclude>**/*Application.class</exclude>
                    <exclude>**/exception/**</exclude>
                </excludes>
            </configuration>
        </execution>
    </executions>
</plugin>
```

**覆蓋率指標**

**行覆蓋率（Line Coverage）**

- 每一行程式碼是否被執行過

**分支覆蓋率（Branch Coverage）**

- if/else 的每個分支是否都被測試過
- 更嚴格，更能找到邊界條件的問題

**覆蓋率目標**

- 核心業務邏輯：> 80%
- 工具類：     > 70%
- Controller： > 60%（通常用整合測試覆蓋）

- ⚠️ 覆蓋率不是越高越好！
    - 100% 覆蓋率但測試品質差（沒有 Assert）= 無意義
    - 重要的是測試邏輯是否正確，邊界條件是否覆蓋

**執行**

``` text
mvn test                          # 執行測試
mvn test jacoco:report            # 生成覆蓋率報告
target/site/jacoco/index.html     # 查看報告
```

## 測試最佳實踐

```java
// ✅ 1. 測試方法命名清晰（三段式）
// methodName_StateUnderTest_ExpectedBehavior
void createOrder_WhenInsufficientStock_ShouldThrowException() { }
void getUser_WhenUserExists_ShouldReturnUser() { }
void deleteOrder_WhenOrderNotFound_ShouldReturn404() { }

// ✅ 2. AAA 結構（Arrange-Act-Assert）
@Test
void someTest() {
    // Arrange（準備）
    User user = User.builder().id(1L).name("John").build();
    when(userRepository.findById(1L)).thenReturn(Optional.of(user));

    // Act（執行）
    UserDTO result = userService.findById(1L);

    // Assert（驗證）
    assertThat(result.getName()).isEqualTo("John");
}

// ✅ 3. 一個測試只測一件事
// ❌ 不好（測試多件事）
@Test
void testEverything() {
    // 測試建立
    // 測試更新
    // 測試刪除
}

// ✅ 好（每個測試一件事）
@Test void createOrder_ShouldSucceed() { }
@Test void updateOrder_ShouldSucceed() { }
@Test void deleteOrder_ShouldSucceed() { }

// ✅ 4. 使用 @DisplayName 寫人類可讀的描述
@Test
@DisplayName("當用戶餘額不足時，支付應該失敗並返回 INSUFFICIENT_BALANCE 錯誤碼")
void pay_ShouldFail_WhenInsufficientBalance() { }

// ✅ 5. 測試邊界條件
// 0、負數、null、空字串、最大值、最小值

// ✅ 6. 不要在測試中寫業務邏輯
// ❌ 不好（在測試中重複計算）
@Test
void calculateTotal() {
    BigDecimal price    = new BigDecimal("100");
    int        quantity = 3;
    BigDecimal expected = price.multiply(new BigDecimal(quantity)); // 重複業務邏輯！
    assertThat(service.calculate(price, quantity)).isEqualTo(expected);
}

// ✅ 好（直接使用預期值）
@Test
void calculateTotal() {
    assertThat(service.calculate(new BigDecimal("100"), 3))
        .isEqualByComparingTo(new BigDecimal("300")); // 直接寫預期結果
}
```
