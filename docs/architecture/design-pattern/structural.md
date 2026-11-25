# 結構型模式

## 代理模式（Proxy）⭐ AOP 底層原理

**目的**：在不修改原始類的情況下，為其添加額外功能（日誌、事務、權限等）

```java
// 代理模式三種實作方式：
// 靜態代理、JDK 動態代理、CGLIB 動態代理

// ── 方式一：靜態代理 ──
// 目標介面
public interface OrderService {
    Order createOrder(OrderRequest request);
}

// 真實實作
public class OrderServiceImpl implements OrderService {
    @Override
    public Order createOrder(OrderRequest request) {
        // 業務邏輯
        return new Order();
    }
}

// 靜態代理（手動寫）
public class OrderServiceProxy implements OrderService {
    private final OrderService target;  // 被代理的真實對象

    public OrderServiceProxy(OrderService target) {
        this.target = target;
    }

    @Override
    public Order createOrder(OrderRequest request) {
        // 前置處理（如：記錄日誌）
        long start = System.currentTimeMillis();
        log.info("開始創建訂單，userId={}", request.getUserId());

        try {
            Order order = target.createOrder(request); // 調用真實方法

            // 後置處理（如：發送通知）
            log.info("訂單創建成功，orderId={}", order.getId());
            return order;

        } catch (Exception e) {
            log.error("訂單創建失敗", e);
            throw e;
        } finally {
            log.info("耗時：{} ms", System.currentTimeMillis() - start);
        }
    }
}

// 缺點：每個介面都要寫一個代理類，工程量大
```

```java
// ── 方式二：JDK 動態代理 ──
// 只能代理有介面的類（基於介面）

public class JdkProxyFactory {

    public static <T> T createProxy(T target) {
        return (T) Proxy.newProxyInstance(
            target.getClass().getClassLoader(),   // 類加載器
            target.getClass().getInterfaces(),    // 代理哪些介面
            new LoggingInvocationHandler(target)  // InvocationHandler
        );
    }
}

public class LoggingInvocationHandler implements InvocationHandler {
    private final Object target;

    public LoggingInvocationHandler(Object target) {
        this.target = target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args)
            throws Throwable {
        // 所有方法調用都會經過這裡！
        log.info("調用方法：{}，參數：{}", method.getName(), Arrays.toString(args));
        long start = System.currentTimeMillis();

        try {
            Object result = method.invoke(target, args);  // 反射調用真實方法
            log.info("方法 {} 執行成功，耗時：{} ms",
                method.getName(), System.currentTimeMillis() - start);
            return result;

        } catch (InvocationTargetException e) {
            log.error("方法 {} 執行失敗", method.getName(), e.getCause());
            throw e.getCause();
        }
    }
}

// 使用
OrderService realService = new OrderServiceImpl();
OrderService proxy       = JdkProxyFactory.createProxy(realService);
proxy.createOrder(request);  // 自動觸發 InvocationHandler.invoke()
```

```java
// ── 方式三：CGLIB 動態代理 ──
// 可以代理沒有介面的類（基於繼承，生成子類）

// 目標類（沒有介面）
public class UserService {
    public User getUser(Long id) {
        return userRepository.findById(id).orElseThrow();
    }
}

// CGLIB 代理
public class CglibProxyFactory implements MethodInterceptor {

    public Object createProxy(Class<?> targetClass) {
        Enhancer enhancer = new Enhancer();
        enhancer.setSuperclass(targetClass);    // 設定父類（繼承目標類）
        enhancer.setCallback(this);             // 設定攔截器
        return enhancer.create();               // 創建代理對象（子類）
    }

    @Override
    public Object intercept(Object obj, Method method,
                            Object[] args, MethodProxy proxy)
            throws Throwable {
        log.info("CGLIB 代理攔截：{}", method.getName());
        Object result = proxy.invokeSuper(obj, args);  // 調用父類（真實）方法
        log.info("CGLIB 代理完成：{}", method.getName());
        return result;
    }
}

// ⚠️ CGLIB 注意事項：
// final 類不能被代理（無法繼承）
// final 方法不能被攔截
// 需要無參構造器（或顯式指定構造器參數）
```

```
JDK 動態代理 vs CGLIB：

┌─────────────────┬─────────────────────┬──────────────────────┐
│                 │   JDK 動態代理       │   CGLIB              │
├─────────────────┼─────────────────────┼──────────────────────┤
│ 代理方式         │ 基於介面             │ 基於繼承（子類）       │
│ 目標要求         │ 必須實作介面         │ 可以是普通類           │
│ 效能（創建）     │ 慢（反射）           │ 稍慢（位元組碼生成）    │
│ 效能（調用）     │ 慢（反射 invoke）    │ 快（直接調用子類方法）  │
│ final 類         │ 不支援               │ 不支援               │
│ Spring 使用      │ 有介面時預設使用     │ 無介面時使用           │
└─────────────────┴─────────────────────┴──────────────────────┘

Spring AOP 底層：
  @Transactional → Spring 用代理模式攔截方法，開啟/提交/回滾事務
  @Cacheable     → 代理攔截，查詢前先查緩存
  @PreAuthorize  → 代理攔截，執行前檢查權限
```

```java
// Spring AOP 完整範例
@Aspect
@Component
@Slf4j
public class PerformanceAspect {

    // 切點：所有 Service 類的所有方法
    @Pointcut("execution(* com.example.service.*.*(..))")
    public void serviceMethod() {}

    // 環繞通知
    @Around("serviceMethod()")
    public Object aroundServiceMethod(ProceedingJoinPoint joinPoint)
            throws Throwable {

        String className  = joinPoint.getTarget().getClass().getSimpleName();
        String methodName = joinPoint.getSignature().getName();
        Object[] args     = joinPoint.getArgs();

        log.info("[{}] {}, 參數: {}",
            className, methodName, Arrays.toString(args));

        long start = System.currentTimeMillis();

        try {
            Object result = joinPoint.proceed();  // 執行真實方法

            long duration = System.currentTimeMillis() - start;
            log.info("[{}] {} 執行成功，耗時: {} ms", className, methodName, duration);

            // 慢方法告警
            if (duration > 1000) {
                log.warn("[慢方法告警] [{}] {} 耗時 {} ms！",
                    className, methodName, duration);
            }

            return result;

        } catch (Exception e) {
            log.error("[{}] {} 執行失敗: {}", className, methodName, e.getMessage());
            throw e;
        }
    }

    // 前置通知
    @Before("@annotation(preAuthorize)")
    public void checkPermission(JoinPoint joinPoint, PreAuthorize preAuthorize) {
        // 方法執行前檢查權限
    }

    // 後置通知（成功才執行）
    @AfterReturning(pointcut = "serviceMethod()", returning = "result")
    public void afterReturning(Object result) {
        // 方法成功返回後執行
    }

    // 異常通知
    @AfterThrowing(pointcut = "serviceMethod()", throwing = "exception")
    public void afterThrowing(Exception exception) {
        log.error("方法拋出異常：{}", exception.getMessage());
    }
}
```

## 裝飾者模式（Decorator）

**目的**：動態地為對象添加功能，比繼承更靈活

```java
// 場景：咖啡飲品，可以加各種配料（牛奶、糖、奶泡...）

// 1. 基礎介面
public interface Coffee {
    String getDescription();
    BigDecimal getCost();
}

// 2. 基礎實作
public class SimpleCoffee implements Coffee {
    @Override
    public String getDescription() { return "黑咖啡"; }
    @Override
    public BigDecimal getCost() { return new BigDecimal("30"); }
}

// 3. 抽象裝飾者（關鍵！包含被裝飾的對象）
public abstract class CoffeeDecorator implements Coffee {
    protected final Coffee decoratedCoffee;  // 被裝飾的對象

    public CoffeeDecorator(Coffee coffee) {
        this.decoratedCoffee = coffee;
    }

    @Override
    public String getDescription() { return decoratedCoffee.getDescription(); }
    @Override
    public BigDecimal getCost() { return decoratedCoffee.getCost(); }
}

// 4. 具體裝飾者
public class MilkDecorator extends CoffeeDecorator {
    public MilkDecorator(Coffee coffee) { super(coffee); }

    @Override
    public String getDescription() {
        return decoratedCoffee.getDescription() + " + 牛奶";
    }
    @Override
    public BigDecimal getCost() {
        return decoratedCoffee.getCost().add(new BigDecimal("10"));
    }
}

public class SugarDecorator extends CoffeeDecorator {
    public SugarDecorator(Coffee coffee) { super(coffee); }

    @Override
    public String getDescription() {
        return decoratedCoffee.getDescription() + " + 糖";
    }
    @Override
    public BigDecimal getCost() {
        return decoratedCoffee.getCost().add(new BigDecimal("5"));
    }
}

public class FoamDecorator extends CoffeeDecorator {
    public FoamDecorator(Coffee coffee) { super(coffee); }

    @Override
    public String getDescription() {
        return decoratedCoffee.getDescription() + " + 奶泡";
    }
    @Override
    public BigDecimal getCost() {
        return decoratedCoffee.getCost().add(new BigDecimal("15"));
    }
}

// 5. 使用（動態組合！）
Coffee coffee = new SimpleCoffee();
coffee = new MilkDecorator(coffee);   // 加牛奶
coffee = new SugarDecorator(coffee);  // 加糖
coffee = new FoamDecorator(coffee);   // 加奶泡

System.out.println(coffee.getDescription()); // 黑咖啡 + 牛奶 + 糖 + 奶泡
System.out.println(coffee.getCost());        // 60

// Java 中的裝飾者模式：
// InputStream → FileInputStream
//            → BufferedInputStream（緩衝裝飾）
//            → DataInputStream（數據裝飾）

// new BufferedInputStream(new FileInputStream("file.txt"))
// BufferedInputStream 裝飾了 FileInputStream，加上緩衝功能
```

## 適配器模式（Adapter）

**目的**：讓介面不兼容的類可以一起工作

```java
// 場景：第三方支付 SDK 的介面和我們系統的介面不兼容

// 1. 我們系統的支付介面（目標介面）
public interface PaymentGateway {
    boolean pay(String orderId, BigDecimal amount, String currency);
}

// 2. 第三方 SDK（被適配者，介面不同，無法修改）
public class AlipaySDK {
    public String createPayment(String merchantOrderId, double amount) {
        // 支付寶 SDK 的邏輯
        return "SUCCESS";
    }
}

public class StripeSDK {
    public StripeResponse charge(StripeRequest request) {
        // Stripe SDK 的邏輯
        return new StripeResponse("succeeded");
    }
}

// 3. 適配器（讓不兼容的介面協同工作）
@Component
public class AlipayAdapter implements PaymentGateway {

    private final AlipaySDK alipaySDK = new AlipaySDK();

    @Override
    public boolean pay(String orderId, BigDecimal amount, String currency) {
        // 適配：將我們的介面轉換為 SDK 的介面
        String result = alipaySDK.createPayment(
            orderId,
            amount.doubleValue()  // BigDecimal → double
        );
        return "SUCCESS".equals(result);
    }
}

@Component
public class StripeAdapter implements PaymentGateway {

    private final StripeSDK stripeSDK = new StripeSDK();

    @Override
    public boolean pay(String orderId, BigDecimal amount, String currency) {
        StripeRequest request = new StripeRequest();
        request.setAmount(amount.multiply(new BigDecimal("100")).longValue()); // 元 → 分
        request.setCurrency(currency.toLowerCase());
        request.setMetadata(Map.of("orderId", orderId));

        StripeResponse response = stripeSDK.charge(request);
        return "succeeded".equals(response.getStatus());
    }
}

// 4. 使用（客戶端只依賴 PaymentGateway 介面）
@Service
public class OrderService {
    // 不關心具體是哪個支付方式
    @Autowired
    @Qualifier("alipayAdapter")
    private PaymentGateway paymentGateway;

    public void pay(Order order) {
        boolean success = paymentGateway.pay(
            order.getId().toString(),
            order.getAmount(),
            "CNY"
        );
    }
}
```

## 外觀模式（Facade）

**目的**：為複雜的子系統提供一個簡單的介面

```java
// 場景：下單流程涉及多個子系統

// 多個子系統
@Service public class InventoryService  { public boolean check(Long productId, int qty) { ... } }
@Service public class PriceService      { public BigDecimal calculate(Long productId, int qty) { ... } }
@Service public class PaymentService    { public boolean pay(BigDecimal amount) { ... } }
@Service public class ShippingService   { public String createShipping(Long orderId) { ... } }
@Service public class NotificationService { public void notify(Long userId, String msg) { ... } }

// ❌ 沒有 Facade：客戶端需要了解並協調所有子系統（複雜！）
public void order(OrderRequest request) {
    boolean inStock = inventoryService.check(request.getProductId(), request.getQuantity());
    if (!inStock) throw new RuntimeException("庫存不足");

    BigDecimal amount = priceService.calculate(request.getProductId(), request.getQuantity());

    boolean paid = paymentService.pay(amount);
    if (!paid) throw new RuntimeException("支付失敗");

    String trackingNo = shippingService.createShipping(orderId);

    notificationService.notify(request.getUserId(), "訂單已建立：" + orderId);
}

// ✅ 外觀模式：提供一個簡單的下單介面
@Service
@RequiredArgsConstructor
public class OrderFacade {

    private final InventoryService    inventoryService;
    private final PriceService        priceService;
    private final PaymentService      paymentService;
    private final ShippingService     shippingService;
    private final NotificationService notificationService;

    // 一個簡單的方法，封裝所有複雜邏輯
    public OrderResult placeOrder(OrderRequest request) {
        // 1. 檢查庫存
        if (!inventoryService.check(request.getProductId(), request.getQuantity())) {
            throw new InsufficientStockException("庫存不足");
        }

        // 2. 計算價格
        BigDecimal amount = priceService.calculate(
            request.getProductId(), request.getQuantity());

        // 3. 支付
        if (!paymentService.pay(amount)) {
            throw new PaymentFailedException("支付失敗");
        }

        // 4. 創建物流
        String trackingNo = shippingService.createShipping(request.getOrderId());

        // 5. 通知用戶
        notificationService.notify(request.getUserId(),
            "您的訂單已建立！追蹤號：" + trackingNo);

        return OrderResult.success(request.getOrderId(), trackingNo, amount);
    }
}

// 客戶端（Controller）只需要調用 Facade
@RestController
@RequiredArgsConstructor
public class OrderController {
    private final OrderFacade orderFacade;  // 只依賴 Facade！

    @PostMapping("/orders")
    public ResponseEntity<OrderResult> placeOrder(@RequestBody OrderRequest request) {
        OrderResult result = orderFacade.placeOrder(request);
        return ResponseEntity.ok(result);
    }
}
```

## 橋接模式（Bridge）

**目的**：將抽象與實作分離，兩者可以獨立變化（避免繼承爆炸）

```java
// 場景：訊息系統，有多種訊息類型 × 多種發送管道
// 訊息類型：普通訊息、加急訊息、系統訊息
// 發送管道：Email、SMS、Push 通知
// 如果用繼承：3 × 3 = 9 個子類！
// 用橋接：3 + 3 = 6 個類，任意組合

// 1. 實作介面（Implementor）- 發送管道
public interface MessageSender {
    void send(String to, String title, String content);
    String getChannel();
}

// 具體實作 - 各種發送管道
@Component
public class EmailSender implements MessageSender {
    @Override
    public void send(String to, String title, String content) {
        log.info("Email → {}: [{}] {}", to, title, content);
        // 呼叫 Email 服務
    }
    @Override public String getChannel() { return "EMAIL"; }
}

@Component
public class SmsSender implements MessageSender {
    @Override
    public void send(String to, String title, String content) {
        log.info("SMS → {}: {}", to, content);
        // 呼叫 SMS 服務（內容簡短）
    }
    @Override public String getChannel() { return "SMS"; }
}

@Component
public class PushSender implements MessageSender {
    @Override
    public void send(String to, String title, String content) {
        log.info("Push → {}: [{}] {}", to, title, content);
        // 呼叫推播服務
    }
    @Override public String getChannel() { return "PUSH"; }
}

// 2. 抽象類（Abstraction）- 訊息類型
// ⭐ 橋接的關鍵：持有實作介面的引用
public abstract class Message {
    protected final MessageSender sender;  // 橋接！

    protected Message(MessageSender sender) {
        this.sender = sender;
    }

    public abstract void send(String to, String content);
}

// 具體抽象 - 各種訊息類型
public class NormalMessage extends Message {
    public NormalMessage(MessageSender sender) { super(sender); }

    @Override
    public void send(String to, String content) {
        sender.send(to, "一般通知", content);
    }
}

public class UrgentMessage extends Message {
    public UrgentMessage(MessageSender sender) { super(sender); }

    @Override
    public void send(String to, String content) {
        // 加急訊息：加上前綴，標題強調
        sender.send(to, "【緊急】", "⚠️ 緊急通知：" + content);
    }
}

public class SystemMessage extends Message {
    public SystemMessage(MessageSender sender) { super(sender); }

    @Override
    public void send(String to, String content) {
        sender.send(to, "系統通知", "[System] " + content);
    }
}

// 3. 使用（自由組合，不需要 9 個子類！）
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final EmailSender emailSender;
    private final SmsSender   smsSender;

    public void notifyUser(String userId, String event) {
        // 組合一：普通訊息 + Email
        Message emailMsg = new NormalMessage(emailSender);
        emailMsg.send(userId, "您有一筆新訂單：" + event);

        // 組合二：加急訊息 + SMS
        Message smsMsg = new UrgentMessage(smsSender);
        smsMsg.send(userId, "支付逾時提醒：" + event);

        // 新增渠道或訊息類型，互不影響！
    }
}
```

## 組合模式（Composite）

**目的**：將對象組合成樹形結構，讓客戶端對單個對象和組合對象統一處理

```java
// 場景：公司組織架構（部門可以包含子部門和員工）

// 1. 統一介面（Component）
public interface OrganizationComponent {
    String getName();
    void print(String indent);
    int headcount();  // 人數
    BigDecimal totalSalary();  // 總薪資
}

// 2. 葉節點（Leaf）- 員工
@Data
@AllArgsConstructor
public class Employee implements OrganizationComponent {
    private String     name;
    private String     position;
    private BigDecimal salary;

    @Override
    public void print(String indent) {
        System.out.println(indent + "👤 " + name + "（" + position + "）");
    }

    @Override public int headcount()         { return 1; }
    @Override public BigDecimal totalSalary() { return salary; }
}

// 3. 組合節點（Composite）- 部門
public class Department implements OrganizationComponent {
    private final String name;
    private final List<OrganizationComponent> children = new ArrayList<>();

    public Department(String name) { this.name = name; }

    // 管理子節點
    public void add(OrganizationComponent component) {
        children.add(component);
    }
    public void remove(OrganizationComponent component) {
        children.remove(component);
    }

    @Override
    public String getName() { return name; }

    @Override
    public void print(String indent) {
        System.out.println(indent + "🏢 " + name);
        // 遞迴打印所有子節點
        children.forEach(child -> child.print(indent + "  "));
    }

    // 遞迴計算：無論層級多深，調用方式完全相同！
    @Override
    public int headcount() {
        return children.stream().mapToInt(OrganizationComponent::headcount).sum();
    }

    @Override
    public BigDecimal totalSalary() {
        return children.stream()
            .map(OrganizationComponent::totalSalary)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}

// 4. 使用
public class Main {
    public static void main(String[] args) {
        // 建立組織架構
        Department company = new Department("科技公司");

        Department engineering = new Department("工程部");
        engineering.add(new Employee("Alice", "後端工程師", new BigDecimal("80000")));
        engineering.add(new Employee("Bob",   "前端工程師", new BigDecimal("75000")));

        Department backend = new Department("後端組");
        backend.add(new Employee("Charlie", "資深工程師", new BigDecimal("100000")));
        backend.add(new Employee("Dave",    "工程師",     new BigDecimal("70000")));
        engineering.add(backend);  // 部門嵌套部門

        Department hr = new Department("人資部");
        hr.add(new Employee("Eve", "HR 主管", new BigDecimal("60000")));

        company.add(engineering);
        company.add(hr);

        // 客戶端調用方式完全相同，不管是部門還是員工！
        company.print("");
        System.out.println("總人數：" + company.headcount());
        System.out.println("總薪資：" + company.totalSalary());
    }
}
// 輸出：
// 🏢 科技公司
//   🏢 工程部
//     👤 Alice（後端工程師）
//     👤 Bob（前端工程師）
//     🏢 後端組
//       👤 Charlie（資深工程師）
//       👤 Dave（工程師）
//   🏢 人資部
//     👤 Eve（HR 主管）
// 總人數：5
```

## 享元模式（Flyweight）

**目的**：透過共享技術，複用大量細粒度對象，節省記憶體

```java
// 場景：線上遊戲中有大量子彈，每顆子彈屬性幾乎相同
// 若每顆子彈都創建新對象 → 記憶體爆炸！
// 享元：共享「不變的部分」，只保留「變動的部分」

// 1. 享元對象（Flyweight）- 存儲共享的內部狀態（不可變）
@Getter
public class BulletType {
    private final String color;    // 顏色（共享）
    private final int    speed;    // 速度（共享）
    private final int    damage;   // 傷害（共享）
    private final String imageUrl; // 圖片（共享，最大開銷！）

    public BulletType(String color, int speed, int damage, String imageUrl) {
        this.color    = color;
        this.speed    = speed;
        this.damage   = damage;
        this.imageUrl = imageUrl;
        log.info("載入子彈類型：{}（消耗大量記憶體）", color);
    }

    // 渲染子彈（外部狀態：位置是每顆子彈獨有的）
    public void render(int x, int y) {
        log.debug("渲染 {} 子彈 at ({}, {})", color, x, y);
    }
}

// 2. 享元工廠（Flyweight Factory）
@Component
public class BulletFactory {

    // 快取池（共享對象）
    private final Map<String, BulletType> cache = new ConcurrentHashMap<>();

    public BulletType getBulletType(String color) {
        // 不存在才創建，存在直接複用
        return cache.computeIfAbsent(color, key -> {
            // 模擬載入圖片資源（耗時耗記憶體）
            return new BulletType(key, 500, 10, "/images/bullet/" + key + ".png");
        });
    }

    public int getCacheSize() { return cache.size(); }
}

// 3. 子彈（只存外部狀態：位置）
public class Bullet {
    private final BulletType type;   // 共享的內部狀態
    private int x;                   // 外部狀態（每顆子彈獨有）
    private int y;

    public Bullet(BulletType type, int x, int y) {
        this.type = type;
        this.x = x;
        this.y = y;
    }

    public void move() {
        x += type.getSpeed();
        type.render(x, y);
    }
}

// 4. 使用
@Service
@RequiredArgsConstructor
public class GameService {

    private final BulletFactory bulletFactory;
    private final List<Bullet>  bullets = new ArrayList<>();

    public void fireBullets(int count) {
        for (int i = 0; i < count; i++) {
            // 1000 顆子彈只有 3 個 BulletType 對象！
            String type = i % 3 == 0 ? "RED" : i % 3 == 1 ? "BLUE" : "GREEN";
            BulletType bulletType = bulletFactory.getBulletType(type);
            bullets.add(new Bullet(bulletType, i * 10, 0));
        }
        log.info("發射 {} 顆子彈，但只創建了 {} 個類型對象",
            count, bulletFactory.getCacheSize());
    }
}

// Java 中的享元模式：
// Integer.valueOf(-128 ~ 127)  → 整數緩存池
// String.intern()              → 字串常量池
// 資料庫連線池（HikariCP）      → 共享連線對象
// 線程池                       → 共享線程對象
```
