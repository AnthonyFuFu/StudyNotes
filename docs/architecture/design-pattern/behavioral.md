# 行為型模式

!!! abstract "本章重點"

    行為型模式關注「物件之間如何分工與溝通」。本章的 11 種模式都附上 UML 類別圖與 AnthonyFu-Learning 的範例程式，其中觀察者、策略、責任鏈、狀態是業務系統最常用的四種，另外並列了 Spring 實戰版本。

## 觀察者模式（Observer）⭐ 事件驅動核心

**目的**：定義一對多依賴，一個對象改變時，所有依賴者都自動收到通知

**結構**

``` mermaid
classDiagram
    direction LR
    class Subject {
        <<interface>>
        +registerObserver(o)
        +removeObserver(o)
        +notifyObservers()
    }
    class Observer {
        <<interface>>
        +update(message)
    }
    Subject <|.. NewsAgency
    Observer <|.. NewsChannel
    NewsAgency o-- Observer : observers
```

**範例**

=== "AnthonyFu-Learning 範例"

    ``` java
    // ── Observer.java ──
    //觀察者接口
    interface Observer {
        void update(String message);
    }

    // ── Subject.java ──
    //被觀察者接口
    interface Subject {
        void registerObserver(Observer observer);
        void removeObserver(Observer observer);
        void notifyObservers();
    }

    // ── NewsAgency.java ──
    //具體被觀察者
    class NewsAgency implements Subject {
        private List<Observer> observers = new ArrayList<>();
        private String news;

        @Override
        public void registerObserver(Observer observer) {
            if (!observers.contains(observer)) {
                observers.add(observer);
            }
        }

        @Override
        public void removeObserver(Observer observer) {
            observers.remove(observer);
        }

        @Override
        public void notifyObservers() {
            for (Observer observer : observers) {
                observer.update(news);
            }
        }

        // 設置新聞，並通知所有觀察者
        public void setNews(String news) {
            this.news = news;
            notifyObservers();
        }
    }

    // ── ObserverPattern.java ──
    public class ObserverPattern {
        public static void main(String[] args) {
            // 創建被觀察者和觀察者
            NewsAgency agency = new NewsAgency();

            NewsChannel channel1 = new NewsChannel("Channel 1");
            NewsChannel channel2 = new NewsChannel("Channel 2");
            NewsChannel channel3 = new NewsChannel("Channel 3");

            // 註冊觀察者
            agency.registerObserver(channel1);
            agency.registerObserver(channel2);
            agency.registerObserver(channel3);

            // 發布新聞，觀察者會收到通知
            agency.setNews("Breaking news: New design pattern article released!");

            // 移除一個觀察者
            agency.removeObserver(channel2);

            // 再次發布新聞
            agency.setNews("Update: The article is trending now!");
        }
    }
    ```

    ??? example "其餘實作類別"

        ``` java
        // ── NewsChannel.java ──
        //具體觀察者 - 新聞頻道
        class NewsChannel implements Observer {
            private String channelName;

            public NewsChannel(String name) {
                this.channelName = name;
            }

            @Override
            public void update(String news) {
                System.out.println(channelName + " received news: " + news);
            }
        }
        ```

=== "原筆記：Spring ApplicationEvent"

    ```java
    // 場景：訂單建立後，需要通知多個系統（庫存、積分、郵件、推薦）

    // ── 方式一：手動實作觀察者 ──

    // 1. 事件（被觀察的對象）
    @Data
    @AllArgsConstructor
    public class OrderCreatedEvent {
        private Long      orderId;
        private Long      userId;
        private BigDecimal amount;
        private LocalDateTime createdAt;
    }

    // 2. 觀察者介面
    public interface OrderEventListener {
        void onOrderCreated(OrderCreatedEvent event);
        int getOrder();  // 執行優先順序
    }

    // 3. 具體觀察者
    @Component
    public class InventoryListener implements OrderEventListener {
        @Override
        public void onOrderCreated(OrderCreatedEvent event) {
            log.info("庫存服務：扣減庫存，orderId={}", event.getOrderId());
        }
        @Override public int getOrder() { return 1; }  // 優先執行
    }

    @Component
    public class PointsListener implements OrderEventListener {
        @Override
        public void onOrderCreated(OrderCreatedEvent event) {
            log.info("積分服務：增加積分，userId={}", event.getUserId());
        }
        @Override public int getOrder() { return 2; }
    }

    @Component
    public class EmailListener implements OrderEventListener {
        @Override
        public void onOrderCreated(OrderCreatedEvent event) {
            log.info("郵件服務：發送確認郵件，userId={}", event.getUserId());
        }
        @Override public int getOrder() { return 3; }
    }

    // 4. 事件發布者（被觀察者）
    @Component
    public class OrderEventPublisher {

        private final List<OrderEventListener> listeners;

        // Spring 自動注入所有 OrderEventListener 實作
        public OrderEventPublisher(List<OrderEventListener> listeners) {
            // 按 order 排序
            this.listeners = listeners.stream()
                .sorted(Comparator.comparingInt(OrderEventListener::getOrder))
                .collect(Collectors.toList());
        }

        public void publishOrderCreated(OrderCreatedEvent event) {
            listeners.forEach(listener -> {
                try {
                    listener.onOrderCreated(event);
                } catch (Exception e) {
                    // 一個觀察者失敗，不影響其他觀察者！
                    log.error("觀察者 {} 執行失敗", listener.getClass().getSimpleName(), e);
                }
            });
        }
    }
    ```

    ```java
    // ── 方式二：Spring 事件機制（推薦！）──

    // 1. 定義事件（繼承 ApplicationEvent）
    public class OrderCreatedEvent extends ApplicationEvent {
        private final Long      orderId;
        private final Long      userId;
        private final BigDecimal amount;

        public OrderCreatedEvent(Object source, Long orderId,
                                 Long userId, BigDecimal amount) {
            super(source);
            this.orderId = orderId;
            this.userId  = userId;
            this.amount  = amount;
        }
        // getter...
    }

    // 2. 發布事件
    @Service
    @RequiredArgsConstructor
    public class OrderService {

        private final ApplicationEventPublisher eventPublisher;

        @Transactional
        public Order createOrder(OrderRequest request) {
            Order order = saveOrder(request);

            // 發布事件（在事務提交後執行）
            eventPublisher.publishEvent(
                new OrderCreatedEvent(this, order.getId(),
                    request.getUserId(), order.getAmount())
            );

            return order;
        }
    }

    // 3. 監聽事件
    @Component
    @Slf4j
    public class OrderEventHandler {

        // ✅ @EventListener：同步執行（在同一個事務中）
        @EventListener
        public void handleInventory(OrderCreatedEvent event) {
            log.info("扣減庫存，orderId={}", event.getOrderId());
        }

        // ✅ @TransactionalEventListener：事務提交後才執行！
        // 避免事務回滾後還在扣庫存的問題
        @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
        public void handlePoints(OrderCreatedEvent event) {
            log.info("增加積分，userId={}", event.getUserId());
        }

        // ✅ @Async + @EventListener：非同步執行（不阻塞主流程）
        @Async
        @EventListener
        public void handleEmail(OrderCreatedEvent event) {
            log.info("發送確認郵件，userId={}", event.getUserId());
            // 即使這裡很慢，也不會影響下單的響應時間
        }
    }
    ```

**在 Spring 與實務中**：`ApplicationEventPublisher` + `@EventListener`（可搭配 `@Async`、`@TransactionalEventListener`）；跨服務時就是訊息佇列的發布 / 訂閱。

## 策略模式（Strategy）⭐ 消滅 if-else

**目的**：定義一系列算法，封裝起來，使它們可以互相替換

**結構**

``` mermaid
classDiagram
    direction LR
    class PaymentStrategy {
        <<interface>>
        +pay(amount)
    }
    PaymentStrategy <|.. CreditCardPayment
    PaymentStrategy <|.. PayPalPayment
    ShoppingCart o-- PaymentStrategy : 執行期可替換
```

**範例**

=== "AnthonyFu-Learning 範例"

    ``` java
    // ── PaymentStrategy.java ──
    interface PaymentStrategy {
        void pay(double amount);
    }

    // ── CreditCardPayment.java ──
    class CreditCardPayment implements PaymentStrategy {
        private String cardNumber;
        private String cvv;
        private String expiryDate;

        public CreditCardPayment(String cardNumber, String cvv, String expiryDate) {
            this.cardNumber = cardNumber;
            this.cvv = cvv;
            this.expiryDate = expiryDate;
        }

        @Override
        public void pay(double amount) {
            System.out.println(amount + " paid using Credit Card (Number: " + cardNumber + ", cvv:" + cvv + ", expiryDate:" + expiryDate + ")");
        }
    }

    // ── PayPalPayment.java ──
    class PayPalPayment implements PaymentStrategy {
        private String email;
        private String password;

        public PayPalPayment(String email, String password) {
            this.email = email;
            this.password = password;
        }

        @Override
        public void pay(double amount) {
            System.out.println(amount + " paid using PayPal (Email: " + email + ", password:" + password + ")");
        }
    }

    // ── ShoppingCart.java ──
    class ShoppingCart {
        private PaymentStrategy paymentStrategy;

        public void setPaymentStrategy(PaymentStrategy paymentStrategy) {
            this.paymentStrategy = paymentStrategy;
        }

        public void checkout(double amount) {
            paymentStrategy.pay(amount);
        }
    }

    // ── StrategyPattern.java ──
    public class StrategyPattern {
        public static void main(String[] args) {
            ShoppingCart cart = new ShoppingCart();

            // 使用信用卡支付
            cart.setPaymentStrategy(new CreditCardPayment("1234-5678-9012-3456", "123", "12/25"));
            cart.checkout(100.50);

            // 切換到PayPal支付
            cart.setPaymentStrategy(new PayPalPayment("user@example.com", "password"));
            cart.checkout(200.75);
        }
    }
    ```

=== "計算策略"

    ``` java
    // ── Strategy.java ──
    public interface Strategy {
        public int execute(int a, int b);
    }

    // ── AddStrategy.java ──
    public class AddStrategy implements Strategy {
        @Override
        public int execute(int a, int b) {
            return a + b;
        }
    }

    // ── SubstractStrategy.java ──
    public class SubstractStrategy implements Strategy {
        @Override
        public int execute(int a, int b) {
            return a - b;
        }
    }

    // ── MultiplyStrategy.java ──
    public class MultiplyStrategy implements Strategy {
        @Override
        public int execute(int a, int b) {
            return a * b;
        }
    }

    // ── Context.java ──
    public class Context {
        private Strategy strategy;

        public Context(Strategy strategy) {
            this.strategy = strategy;
        }

        public void setStrategy(Strategy strategy) {
            this.strategy = strategy;
        }

        public int executeStrategy(int a, int b) {
            return strategy.execute(a, b);
        }
    }

    // ── StrategyPattern.java ──
    public class StrategyPattern {
        public static void main(String[] args) {

            Context context = new Context(new AddStrategy());
            int result = context.executeStrategy(10, 5);
            System.out.println(result); // output: 15

            context.setStrategy(new SubstractStrategy());
            result = context.executeStrategy(10, 5);
            System.out.println(result); // output: 5

            context.setStrategy(new MultiplyStrategy());
            result = context.executeStrategy(10, 5);
            System.out.println(result); // output: 50
        }

    }
    ```

=== "原筆記：折扣策略 + Spring Map 路由"

    ```java
    // 場景：不同的促銷活動有不同的折扣計算方式

    // 1. 策略介面
    public interface DiscountStrategy {
        BigDecimal calculateDiscount(BigDecimal originalPrice, Object... params);
        String getStrategyCode();
    }

    // 2. 具體策略
    @Component
    public class NoDiscountStrategy implements DiscountStrategy {
        @Override
        public BigDecimal calculateDiscount(BigDecimal price, Object... params) {
            return BigDecimal.ZERO;  // 無折扣
        }
        @Override public String getStrategyCode() { return "NONE"; }
    }

    @Component
    public class PercentageDiscountStrategy implements DiscountStrategy {
        @Override
        public BigDecimal calculateDiscount(BigDecimal price, Object... params) {
            // params[0] = 折扣比例（如 0.8 = 八折）
            BigDecimal discountRate = (BigDecimal) params[0];
            return price.multiply(BigDecimal.ONE.subtract(discountRate));
        }
        @Override public String getStrategyCode() { return "PERCENTAGE"; }
    }

    @Component
    public class FixedAmountDiscountStrategy implements DiscountStrategy {
        @Override
        public BigDecimal calculateDiscount(BigDecimal price, Object... params) {
            // params[0] = 折扣金額（如 50 = 減 50 元）
            BigDecimal discountAmount = (BigDecimal) params[0];
            return discountAmount.min(price);  // 折扣不能超過原價
        }
        @Override public String getStrategyCode() { return "FIXED_AMOUNT"; }
    }

    @Component
    public class BuyXGetYFreeStrategy implements DiscountStrategy {
        @Override
        public BigDecimal calculateDiscount(BigDecimal price, Object... params) {
            // 買 X 送 Y，params[0] = 購買數量, params[1] = 單價
            int quantity   = (int) params[0];
            BigDecimal unitPrice = (BigDecimal) params[1];
            int freeItems  = quantity / 3;  // 買三送一
            return unitPrice.multiply(new BigDecimal(freeItems));
        }
        @Override public String getStrategyCode() { return "BUY_X_GET_Y_FREE"; }
    }

    // 3. 策略上下文（Context）
    @Component
    public class DiscountContext {

        private final Map<String, DiscountStrategy> strategyMap;

        public DiscountContext(List<DiscountStrategy> strategies) {
            this.strategyMap = strategies.stream()
                .collect(Collectors.toMap(
                    DiscountStrategy::getStrategyCode,
                    s -> s
                ));
        }

        public BigDecimal applyDiscount(String strategyCode,
                                        BigDecimal originalPrice,
                                        Object... params) {
            DiscountStrategy strategy = strategyMap.getOrDefault(
                strategyCode,
                strategyMap.get("NONE")  // 預設無折扣
            );
            return strategy.calculateDiscount(originalPrice, params);
        }
    }

    // 4. 使用（完全沒有 if-else！）
    @Service
    @RequiredArgsConstructor
    public class OrderService {

        private final DiscountContext discountContext;

        public BigDecimal calculateFinalPrice(Order order, Promotion promotion) {
            // 根據促銷活動類型，自動選擇策略
            BigDecimal discount = discountContext.applyDiscount(
                promotion.getStrategyCode(),
                order.getOriginalAmount(),
                promotion.getDiscountValue()
            );
            return order.getOriginalAmount().subtract(discount);
        }
    }
    ```

**在 Spring 與實務中**：把所有策略注入成 `Map<String, DiscountStrategy>`，依類型取出執行，新增策略不用改既有程式碼（開放封閉原則）。

## 模板方法模式（Template Method）

**目的**：定義算法骨架，將某些步驟延遲到子類實作

**結構**

``` mermaid
classDiagram
    direction LR
    class Game {
        <<abstract>>
        +play() final
        #initialize()*
        #startPlay()*
        #endPlay()*
    }
    Game <|-- Football
    Game <|-- Basketball
```

`play()` 宣告為 `final`，**流程固定**；子類別只能改寫各個步驟。業務上的例子：匯出 CSV / Excel 的流程（查資料 → 轉換 → 寫檔）相同，只有寫檔格式不同。

**範例**

``` java
// ── Game.java ──
abstract class Game {
    // 模板方法 - 定義了算法的骨架
    public final void play() {
        initialize();
        startPlay();
        endPlay();
    }

    // 以下是需要子類實現的步驟
    protected abstract void initialize();
    protected abstract void startPlay();
    protected abstract void endPlay();
}

// ── Football.java ──
//具體實現類 - 足球遊戲
class Football extends Game {
    @Override
    protected void initialize() {
        System.out.println("Football Game Initialized! Start playing.");
    }

    @Override
    protected void startPlay() {
        System.out.println("Football Game Started. Enjoy the game!");
    }

    @Override
    protected void endPlay() {
        System.out.println("Football Game Finished!");
    }
}

// ── Basketball.java ──
//具體實現類 - 籃球遊戲
class Basketball extends Game {
    @Override
    protected void initialize() {
        System.out.println("Basketball Game Initialized! Start playing.");
    }

    @Override
    protected void startPlay() {
        System.out.println("Basketball Game Started. Enjoy the game!");
    }

    @Override
    protected void endPlay() {
        System.out.println("Basketball Game Finished!");
    }
}

// ── TemplateMethodPattern.java ──
public class TemplateMethodPattern {
    public static void main(String[] args) {
        Game game = new Football();
        game.play();

        System.out.println();

        game = new Basketball();
        game.play();
    }
}
```

**在 Spring 與實務中**：`JdbcTemplate`、`RestTemplate`、`AbstractApplicationContext.refresh()`；`HttpServlet.service()` 依方法分派到 `doGet` / `doPost`。

## 責任鏈模式（Chain of Responsibility）

**目的**：請求沿著處理鏈傳遞，每個節點決定是否處理或傳遞給下一個

**結構**

``` mermaid
classDiagram
    direction LR
    class OrderApprover {
        <<abstract>>
        #OrderApprover next
        +setNext(next) OrderApprover
        #canApprove(order)* boolean
        #approve(order)* ApprovalResult
    }
    OrderApprover <|-- TeamLeaderApprover
    OrderApprover <|-- ManagerApprover
    OrderApprover <|-- DirectorApprover
    OrderApprover o-- OrderApprover : next
    ApprovalChainConfig ..> OrderApprover : 組裝鏈
```

**範例**

```java
// 場景：訂單審核流程（金額不同，需不同級別的審核）

// 1. 抽象處理者
public abstract class OrderApprover {
    protected OrderApprover nextApprover;  // 下一個審核者

    public OrderApprover setNext(OrderApprover next) {
        this.nextApprover = next;
        return next;  // 返回 next，支援鏈式設定
    }

    // 模板方法
    public final ApprovalResult process(Order order) {
        if (canApprove(order)) {
            return approve(order);
        } else if (nextApprover != null) {
            return nextApprover.process(order);  // 傳遞給下一個
        } else {
            return ApprovalResult.rejected("超出所有審核權限");
        }
    }

    protected abstract boolean canApprove(Order order);
    protected abstract ApprovalResult approve(Order order);
}

// 2. 具體處理者
@Component
public class TeamLeaderApprover extends OrderApprover {
    @Override
    protected boolean canApprove(Order order) {
        return order.getAmount().compareTo(new BigDecimal("1000")) <= 0;
    }
    @Override
    protected ApprovalResult approve(Order order) {
        log.info("組長審核通過，orderId={}", order.getId());
        return ApprovalResult.approved("組長");
    }
}

@Component
public class ManagerApprover extends OrderApprover {
    @Override
    protected boolean canApprove(Order order) {
        return order.getAmount().compareTo(new BigDecimal("10000")) <= 0;
    }
    @Override
    protected ApprovalResult approve(Order order) {
        log.info("主管審核通過，orderId={}", order.getId());
        return ApprovalResult.approved("主管");
    }
}

@Component
public class DirectorApprover extends OrderApprover {
    @Override
    protected boolean canApprove(Order order) {
        return order.getAmount().compareTo(new BigDecimal("100000")) <= 0;
    }
    @Override
    protected ApprovalResult approve(Order order) {
        log.info("總監審核通過，orderId={}", order.getId());
        return ApprovalResult.approved("總監");
    }
}

// 3. 組裝責任鏈
@Configuration
@RequiredArgsConstructor
public class ApprovalChainConfig {

    private final TeamLeaderApprover teamLeaderApprover;
    private final ManagerApprover    managerApprover;
    private final DirectorApprover   directorApprover;

    @Bean
    public OrderApprover approvalChain() {
        // 組長 → 主管 → 總監
        teamLeaderApprover
            .setNext(managerApprover)
            .setNext(directorApprover);
        return teamLeaderApprover;  // 返回鏈頭
    }
}

// 4. 使用
@Service
@RequiredArgsConstructor
public class OrderService {

    @Qualifier("approvalChain")
    private final OrderApprover approvalChain;

    public ApprovalResult approveOrder(Order order) {
        return approvalChain.process(order);
        // 金額 ≤ 1000    → 組長審核
        // 1000 < 金額 ≤ 10000  → 主管審核
        // 10000 < 金額 ≤ 100000 → 總監審核
        // 金額 > 100000  → 拒絕
    }
}

// Spring 中責任鏈的體現：
// Filter Chain（過濾器鏈）
// Interceptor Chain（攔截器鏈）
// Spring Security Filter Chain
```

**在 Spring 與實務中**：Servlet `FilterChain`、Spring Security 的 Filter Chain、`HandlerInterceptor` 鏈、Netty `ChannelPipeline`。

## 狀態模式（State）

**目的**：讓對象在不同狀態下有不同的行為，消滅複雜的狀態判斷

**結構**

``` mermaid
classDiagram
    direction LR
    class OrderState {
        <<interface>>
        +pay(order)
        +ship(order)
        +deliver(order)
        +cancel(order)
        +getStatus() OrderStatus
    }
    OrderState <|.. PendingState
    OrderState <|.. PaidState
    OrderStateManager o-- OrderState : 依目前狀態分派
```

每個狀態類別只處理自己允許的操作（例如待付款可以付款或取消、不能出貨），非法的狀態轉換直接拋出例外。狀態模式與策略模式結構相同；差別是策略由**呼叫端**選擇，狀態則是**物件自己**依情況切換，而且狀態之間有轉換規則。

**範例**

```java
// 場景：訂單狀態機

// 訂單狀態枚舉
public enum OrderStatus {
    PENDING,     // 待付款
    PAID,        // 已付款
    SHIPPED,     // 已出貨
    DELIVERED,   // 已送達
    CANCELLED    // 已取消
}

// 1. 狀態介面
public interface OrderState {
    void pay(Order order);
    void ship(Order order);
    void deliver(Order order);
    void cancel(Order order);
    OrderStatus getStatus();
}

// 2. 具體狀態

// 待付款狀態
@Component
public class PendingState implements OrderState {
    @Override
    public void pay(Order order) {
        order.setStatus(OrderStatus.PAID);
        log.info("訂單 {} 支付成功", order.getId());
    }
    @Override
    public void ship(Order order) {
        throw new IllegalStateException("待付款訂單不能出貨");
    }
    @Override
    public void deliver(Order order) {
        throw new IllegalStateException("待付款訂單不能確認送達");
    }
    @Override
    public void cancel(Order order) {
        order.setStatus(OrderStatus.CANCELLED);
        log.info("訂單 {} 已取消", order.getId());
    }
    @Override
    public OrderStatus getStatus() { return OrderStatus.PENDING; }
}

// 已付款狀態
@Component
public class PaidState implements OrderState {
    @Override
    public void pay(Order order) {
        throw new IllegalStateException("訂單已支付，不能重複支付");
    }
    @Override
    public void ship(Order order) {
        order.setStatus(OrderStatus.SHIPPED);
        log.info("訂單 {} 已出貨", order.getId());
    }
    @Override
    public void deliver(Order order) {
        throw new IllegalStateException("尚未出貨，不能確認送達");
    }
    @Override
    public void cancel(Order order) {
        order.setStatus(OrderStatus.CANCELLED);
        // 已付款取消，需要退款
        log.info("訂單 {} 取消，觸發退款流程", order.getId());
    }
    @Override
    public OrderStatus getStatus() { return OrderStatus.PAID; }
}

// 3. 狀態管理器（Context）
@Component
@RequiredArgsConstructor
public class OrderStateManager {

    private final Map<OrderStatus, OrderState> stateMap;

    public OrderStateManager(List<OrderState> states) {
        this.stateMap = states.stream()
            .collect(Collectors.toMap(OrderState::getStatus, s -> s));
    }

    public void handleAction(Order order, String action) {
        OrderState currentState = stateMap.get(order.getStatus());

        switch (action) {
            case "PAY"     -> currentState.pay(order);
            case "SHIP"    -> currentState.ship(order);
            case "DELIVER" -> currentState.deliver(order);
            case "CANCEL"  -> currentState.cancel(order);
            default        -> throw new IllegalArgumentException("未知操作：" + action);
        }
    }
}
```

**在 Spring 與實務中**：訂單（待付款 → 已付款 → 已出貨 → 已完成）、工作流程；Spring Statemachine 提供完整的狀態機框架。

## 命令模式（Command）

**目的**：將請求封裝成對象，支援撤銷、重做、隊列、日誌等操作

**結構**

``` mermaid
classDiagram
    direction LR
    class Command {
        <<interface>>
        +execute()
        +undo()
    }
    Command <|.. LightOnCommand
    Command <|.. LightOffCommand
    Command <|.. NoCommand
    RemoteControl o-- Command : 插槽
    LightOnCommand --> Light : 接收者
```

把「請求」封裝成物件後，就能排隊、記錄、**撤銷（undo）**。`NoCommand` 是**空物件模式**，讓未設定的按鈕不需要判斷 null。

**範例**

``` java
// ── Command.java ──
//命令接口
interface Command {
    void execute();
    void undo();
}

// ── Light.java ──
//接收者 - 燈
class Light {
    private String location;

    public Light(String location) {
        this.location = location;
    }

    public void turnOn() {
        System.out.println(location + " light is ON");
    }

    public void turnOff() {
        System.out.println(location + " light is OFF");
    }
}

// ── CommandPattern.java ──
public class CommandPattern {
    public static void main(String[] args) {
        // 創建接收者
        Light livingRoomLight = new Light("Living Room");
        Light kitchenLight = new Light("Kitchen");

        // 創建命令
        Command livingRoomLightOn = new LightOnCommand(livingRoomLight);
        Command livingRoomLightOff = new LightOffCommand(livingRoomLight);
        Command kitchenLightOn = new LightOnCommand(kitchenLight);
        Command kitchenLightOff = new LightOffCommand(kitchenLight);

        // 創建調用者
        RemoteControl remote = new RemoteControl();

        // 設置命令
        remote.setCommand(0, livingRoomLightOn, livingRoomLightOff);
        remote.setCommand(1, kitchenLightOn, kitchenLightOff);

        // 使用遙控器按鈕
        remote.onButtonPressed(0);  // 開啟客廳燈
        remote.offButtonPressed(0); // 關閉客廳燈
        remote.undoButtonPressed(); // 撤銷 - 再次開啟客廳燈

        remote.onButtonPressed(1);  // 開啟廚房燈
        remote.offButtonPressed(1); // 關閉廚房燈
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── LightOnCommand.java ──
    //具體命令 - 開燈
    class LightOnCommand implements Command {
        private Light light;

        public LightOnCommand(Light light) {
            this.light = light;
        }

        @Override
        public void execute() {
            light.turnOn();
        }

        @Override
        public void undo() {
            light.turnOff();
        }
    }

    // ── LightOffCommand.java ──
    //具體命令 - 關燈
    class LightOffCommand implements Command {
        private Light light;

        public LightOffCommand(Light light) {
            this.light = light;
        }

        @Override
        public void execute() {
            light.turnOff();
        }

        @Override
        public void undo() {
            light.turnOn();
        }
    }

    // ── NoCommand.java ──
    //無操作的命令 (空對象模式)
    class NoCommand implements Command {
        @Override
        public void execute() {}

        @Override
        public void undo() {}
    }

    // ── RemoteControl.java ──
    //調用者 - 遙控器
    class RemoteControl {
        private Command[] onCommands;
        private Command[] offCommands;
        private Command undoCommand;

        public RemoteControl() {
            onCommands = new Command[5];
            offCommands = new Command[5];

            Command noCommand = new NoCommand();
            for (int i = 0; i < 5; i++) {
                onCommands[i] = noCommand;
                offCommands[i] = noCommand;
            }
            undoCommand = noCommand;
        }

        public void setCommand(int slot, Command onCommand, Command offCommand) {
            onCommands[slot] = onCommand;
            offCommands[slot] = offCommand;
        }

        public void onButtonPressed(int slot) {
            onCommands[slot].execute();
            undoCommand = onCommands[slot];
        }

        public void offButtonPressed(int slot) {
            offCommands[slot].execute();
            undoCommand = offCommands[slot];
        }

        public void undoButtonPressed() {
            undoCommand.undo();
        }
    }
    ```

**在 Spring 與實務中**：`Runnable` / `Callable` 交給執行緒池、`TransactionTemplate.execute(callback)`、訊息佇列中的任務訊息。

## 迭代器模式（Iterator）

**目的**：提供統一的方式遍歷不同類型的集合，而不暴露其內部結構

**結構**

``` mermaid
classDiagram
    direction LR
    class Iterator {
        <<interface>>
        +hasNext() boolean
        +next() T
    }
    class PageIterator {
        -fetchNextBatch()
        +hasNext() boolean
        +next() T
    }
    Iterator <|.. PageIterator
    OrderExportService ..> PageIterator : 逐頁讀取匯出
```

**範例**

```java
// Java 已內建 Iterator 介面，這裡展示自定義迭代器

// 場景：分頁迭代器（每次從 DB 查一頁，對外像遍歷一個大集合）

public class PageIterator<T> implements Iterator<T> {

    private final Function<PageRequest, Page<T>> fetchPage;
    private int                currentPage = 0;
    private final int          pageSize;
    private List<T>            currentBatch = new ArrayList<>();
    private int                batchIndex   = 0;
    private boolean            hasMore      = true;

    public PageIterator(Function<PageRequest, Page<T>> fetchPage, int pageSize) {
        this.fetchPage = fetchPage;
        this.pageSize  = pageSize;
        fetchNextBatch();
    }

    private void fetchNextBatch() {
        PageRequest pageRequest = PageRequest.of(currentPage++, pageSize);
        Page<T>     page        = fetchPage.apply(pageRequest);
        currentBatch = page.getContent();
        batchIndex   = 0;
        hasMore      = page.hasNext();
    }

    @Override
    public boolean hasNext() {
        if (batchIndex < currentBatch.size()) return true;
        if (hasMore) {
            fetchNextBatch();
            return !currentBatch.isEmpty();
        }
        return false;
    }

    @Override
    public T next() {
        if (!hasNext()) throw new NoSuchElementException();
        return currentBatch.get(batchIndex++);
    }
}

// 使用：對外像在遍歷一個巨大集合，實際上每次只查一頁
@Service
public class OrderExportService {

    private final OrderRepository orderRepository;

    public void exportAllOrders() {
        Iterator<Order> iterator = new PageIterator<>(
            pageRequest -> orderRepository.findAll(pageRequest),
            1000  // 每頁 1000 筆
        );

        // 像遍歷普通集合一樣使用！不用關心分頁邏輯
        while (iterator.hasNext()) {
            Order order = iterator.next();
            exportOrder(order);
        }
    }
}

// Java 中迭代器無處不在：
// for-each 循環底層就是 Iterator
// Stream API 底層也是 Spliterator
// ResultSet（JDBC）遍歷查詢結果
```

**在 Spring 與實務中**：`Iterable` / `Iterator`、Stream API；Spring Data 的 `Slice` / `Page` 分頁查詢；上面的分頁迭代器把「一頁一頁查」包成迭代器，呼叫端不必關心分頁細節，也不會一次載入全部資料。

## 中介者模式（Mediator）

**目的**：用一個中介對象封裝多個對象之間的交互，降低耦合

**結構**

``` mermaid
classDiagram
    direction LR
    class ChatMediator {
        <<interface>>
        +sendMessage(msg, user)
        +addUser(user)
    }
    ChatMediator <|.. ChatRoom
    User <|-- ChatUser
    ChatRoom o-- User : users
    User --> ChatMediator : 透過中介者發言
```

使用者之間不直接互相參照，全部透過聊天室轉發；N 個物件之間的網狀關係變成 N 條到中介者的星狀關係。

**範例**

``` java
// ── ChatMediator.java ──
//中介者接口
interface ChatMediator {
    void sendMessage(String message, User user);
    void addUser(User user);
}

// ── User.java ──
//用戶抽象類
abstract class User {
    protected ChatMediator mediator;
    protected String name;

    public User(ChatMediator mediator, String name) {
        this.mediator = mediator;
        this.name = name;
    }

    public abstract void send(String message);

    public abstract void receive(String message);
}

// ── ChatUser.java ──
//具體用戶
class ChatUser extends User {
    public ChatUser(ChatMediator mediator, String name) {
        super(mediator, name);
    }

    @Override
    public void send(String message) {
        System.out.println(name + " sends: " + message);
        mediator.sendMessage(message, this);
    }

    @Override
    public void receive(String message) {
        System.out.println(name + " receives: " + message);
    }
}

// ── MediatorPattern.java ──
public class MediatorPattern {
    public static void main(String[] args) {
        // 創建中介者 - 聊天室
        ChatMediator chatRoom = new ChatRoom();

        // 創建用戶
        User alice = new ChatUser(chatRoom, "Alice");
        User bob = new ChatUser(chatRoom, "Bob");
        User charlie = new ChatUser(chatRoom, "Charlie");

        // 將用戶添加到聊天室
        chatRoom.addUser(alice);
        chatRoom.addUser(bob);
        chatRoom.addUser(charlie);

        // 用戶發送消息
        alice.send("Hi everyone!");
        bob.send("Hey Alice!");
        charlie.send("Hello there!");
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── ChatRoom.java ──
    //具體中介者
    class ChatRoom implements ChatMediator {
        private List<User> users;

        public ChatRoom() {
            this.users = new ArrayList<>();
        }

        @Override
        public void sendMessage(String message, User user) {
            // 將消息發送給除發送者以外的所有用戶
            for (User u : users) {
                if (u != user) {
                    u.receive(message);
                }
            }
        }

        @Override
        public void addUser(User user) {
            users.add(user);
        }
    }
    ```

**在 Spring 與實務中**：`DispatcherServlet` 協調各個元件；`ApplicationEventPublisher`、訊息佇列、STOMP 的 Message Broker 都扮演中介者。

## 備忘錄模式（Memento）

**目的**：捕獲對象的內部狀態，並在不破壞封裝的前提下，在之後恢復它

**結構**

``` mermaid
classDiagram
    direction LR
    Originator ..> Memento : 建立 / 還原
    CareTaker o-- Memento : 保存歷史
```

**Originator** 負責建立與還原快照，**CareTaker** 只負責保管，不能讀取或修改快照內容，因此不會破壞封裝。

**範例**

``` java
// ── Memento.java ──
//備忘錄 - 保存狀態
class Memento {
    private String state;

    public Memento(String state) {
        this.state = state;
    }

    public String getState() {
        return state;
    }
}

// ── CareTaker.java ──
//管理者 - 保存備忘錄
class CareTaker {
    private List<Memento> mementoList = new ArrayList<>();

    public void addMemento(Memento memento) {
        mementoList.add(memento);
    }

    public Memento getMemento(int index) {
        return mementoList.get(index);
    }
}

// ── MementoPattern.java ──
public class MementoPattern {
    public static void main(String[] args) {
        Originator originator = new Originator();
        CareTaker careTaker = new CareTaker();

        // 設置狀態並保存
        originator.setState("State 1");
        careTaker.addMemento(originator.saveStateToMemento());

        // 變更狀態並再次保存
        originator.setState("State 2");
        careTaker.addMemento(originator.saveStateToMemento());

        // 再次變更狀態
        originator.setState("State 3");

        // 從備忘錄恢復到之前的狀態
        System.out.println("\nCurrent State: " + originator.getState());

        originator.restoreStateFromMemento(careTaker.getMemento(0)); // 恢復到 State 1
        System.out.println("Current State: " + originator.getState());

        originator.restoreStateFromMemento(careTaker.getMemento(1)); // 恢復到 State 2
        System.out.println("Current State: " + originator.getState());
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── Originator.java ──
    //原發器 - 需要保存狀態的對象
    class Originator {
        private String state;

        public String getState() {
            return state;
        }

        public void setState(String state) {
            this.state = state;
            System.out.println("State changed to: " + state);
        }

        // 創建備忘錄
        public Memento saveStateToMemento() {
            return new Memento(state);
        }

        // 從備忘錄恢復狀態
        public void restoreStateFromMemento(Memento memento) {
            state = memento.getState();
            System.out.println("State restored to: " + state);
        }
    }
    ```

**在 Spring 與實務中**：草稿自動儲存、編輯器的復原、遊戲存檔；交易回滾概念上也是「回到之前的快照」。

## 訪問者模式（Visitor）

**目的**：在不修改元素類的情況下，定義作用於元素的新操作

**結構**

``` mermaid
classDiagram
    direction LR
    class ItemElement {
        <<interface>>
        +accept(visitor) int
    }
    class Visitor {
        <<interface>>
        +visit(Book) int
        +visit(Fruit) int
    }
    ItemElement <|.. Book
    ItemElement <|.. Fruit
    Visitor <|.. ShoppingCartVisitor
```

**雙重分派**：`item.accept(visitor)` 依元素型別、`visitor.visit(this)` 依訪問者型別，決定最後執行哪段邏輯。想新增「計算稅額」「產生報表」等操作時，只要新增 Visitor，不用改 `Book`、`Fruit`。

**範例**

``` java
// ── ItemElement.java ──
//可被訪問的元素接口
interface ItemElement {
    void accept(Visitor visitor);
}

// ── Book.java ──
//具體元素 - 書籍
class Book implements ItemElement {
    private String name;
    private double price;

    public Book(String name, double price) {
        this.name = name;
        this.price = price;
    }

    public String getName() {
        return name;
    }

    public double getPrice() {
        return price;
    }

    @Override
    public void accept(Visitor visitor) {
        visitor.visit(this);
    }
}

// ── Visitor.java ──
//訪問者接口
interface Visitor {
    void visit(Book book);
    void visit(Fruit fruit);
}

// ── VisitorPattern.java ──
//測試訪問者模式
public class VisitorPattern {
    public static void main(String[] args) {
        // 創建元素
        List<ItemElement> items = new ArrayList<>();
        items.add(new Book("Design Patterns", 49.99));
        items.add(new Book("Clean Code", 39.99));
        items.add(new Fruit("Apple", 2.99, 2.5));
        items.add(new Fruit("Banana", 1.99, 3.0));

        // 創建訪問者並訪問元素
        Visitor visitor = new ShoppingCartVisitor();
//        double totalPrice = 0;

        for (ItemElement item : items) {
            item.accept(visitor);
        }
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── Fruit.java ──
    //具體元素 - 水果
    class Fruit implements ItemElement {
        private String name;
        private double pricePerKg;
        private double weight;

        public Fruit(String name, double pricePerKg, double weight) {
            this.name = name;
            this.pricePerKg = pricePerKg;
            this.weight = weight;
        }

        public String getName() {
            return name;
        }

        public double getPricePerKg() {
            return pricePerKg;
        }

        public double getWeight() {
            return weight;
        }

        @Override
        public void accept(Visitor visitor) {
            visitor.visit(this);
        }
    }

    // ── ShoppingCartVisitor.java ──
    //具體訪問者 - 計算總價
    class ShoppingCartVisitor implements Visitor {
        @Override
        public void visit(Book book) {
            double cost = book.getPrice();
            System.out.println("Book: " + book.getName() + " - Price: $" + cost);
        }

        @Override
        public void visit(Fruit fruit) {
            double cost = fruit.getPricePerKg() * fruit.getWeight();
            System.out.println("Fruit: " + fruit.getName() + " - Price: $" + cost);
        }
    }
    ```

**在 Spring 與實務中**：`BeanDefinitionVisitor`、編譯器的 AST 走訪、`FileVisitor`（`Files.walkFileTree`）。

## 直譯器模式（Interpreter）

**目的**：為語言定義文法，並建立直譯器來解釋語言中的句子

**結構**

``` mermaid
classDiagram
    direction LR
    class Expression {
        <<interface>>
        +interpret(context) int
    }
    Expression <|.. NumberExpression
    Expression <|.. VariableExpression
    Expression <|.. AddExpression
    Expression <|.. SubtractExpression
    AddExpression o-- Expression : left / right
```

每條文法規則對應一個類別，運算式組成一棵語法樹，`interpret()` 遞迴求值。原筆記用同樣的方式實作權限表達式（`ADMIN AND (EDITOR OR OWNER)`）。

**範例**

``` java
// ── Expression.java ──
//表達式接口
interface Expression {
    int interpret(Map<String, Integer> context);
}

// ── NumberExpression.java ──
//終端表達式 - 數字
class NumberExpression implements Expression {
    private int number;

    public NumberExpression(int number) {
        this.number = number;
    }

    @Override
    public int interpret(Map<String, Integer> context) {
        return number;
    }
}

// ── InterpreterPattern.java ──
public class InterpreterPattern {
    public static void main(String[] args) {
        // 創建表達式: a + b - c
        Expression expression = new SubtractExpression(
            new AddExpression(
                new VariableExpression("a"),
                new VariableExpression("b")
            ),
            new VariableExpression("c")
        );

        // 創建上下文
        Map<String, Integer> context = new HashMap<>();
        context.put("a", 10);
        context.put("b", 5);
        context.put("c", 3);

        // 解釋表達式
        int result = expression.interpret(context);
        System.out.println("a + b - c = " + result);  // 應輸出 12

        // 更改變量值
        context.put("a", 20);
        result = expression.interpret(context);
        System.out.println("a + b - c = " + result);  // 應輸出 22
    }
}
```

??? example "其餘實作類別"

    ``` java
    // ── VariableExpression.java ──
    //終端表達式 - 變量
    class VariableExpression implements Expression {
        private String name;

        public VariableExpression(String name) {
            this.name = name;
        }

        @Override
        public int interpret(Map<String, Integer> context) {
            if (context.containsKey(name)) {
                return context.get(name);
            }
            return 0;
        }
    }

    // ── AddExpression.java ──
    //非終端表達式 - 加法
    class AddExpression implements Expression {
        private Expression leftExpression;
        private Expression rightExpression;

        public AddExpression(Expression left, Expression right) {
            this.leftExpression = left;
            this.rightExpression = right;
        }

        @Override
        public int interpret(Map<String, Integer> context) {
            return leftExpression.interpret(context) + rightExpression.interpret(context);
        }
    }

    // ── SubtractExpression.java ──
    //非終端表達式 - 減法
    class SubtractExpression implements Expression {
        private Expression leftExpression;
        private Expression rightExpression;

        public SubtractExpression(Expression left, Expression right) {
            this.leftExpression = left;
            this.rightExpression = right;
        }

        @Override
        public int interpret(Map<String, Integer> context) {
            return leftExpression.interpret(context) - rightExpression.interpret(context);
        }
    }
    ```

**在 Spring 與實務中**：SpEL（`@Value("#{...}")`、`@PreAuthorize("hasRole('ADMIN')")`）、正規表示式、SQL 解析。
