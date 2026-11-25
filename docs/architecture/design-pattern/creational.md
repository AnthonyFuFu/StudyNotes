# 創建型模式

## 單例模式（Singleton）

**目的**：確保一個類只有一個實例，並提供全局訪問點

```java
// ❌ 懶漢式（線程不安全）
public class Singleton {
    private static Singleton instance;

    public static Singleton getInstance() {
        if (instance == null) {
            instance = new Singleton(); // 多線程可能同時進入！
        }
        return instance;
    }
}
```

```java
// ✅ 方式一：餓漢式（線程安全，推薦）
// 類加載時就初始化，不存在並發問題
public class Singleton {
    // JVM 保證類加載是線程安全的
    private static final Singleton INSTANCE = new Singleton();

    private Singleton() {}  // 私有構造器，防止外部 new

    public static Singleton getInstance() {
        return INSTANCE;
    }
}
```

```java
// ✅ 方式二：雙重檢查鎖定（DCL）
// 懶加載 + 線程安全
public class Singleton {
    // ⚠️ 必須加 volatile！防止指令重排序！
    private static volatile Singleton instance;

    private Singleton() {}

    public static Singleton getInstance() {
        if (instance == null) {               // 第一次檢查（不加鎖，性能高）
            synchronized (Singleton.class) {
                if (instance == null) {       // 第二次檢查（加鎖後再確認）
                    instance = new Singleton();
                    // new 分三步：① 分配記憶體 ② 初始化對象 ③ 指向記憶體地址
                    // volatile 防止 ①③② 的指令重排序
                }
            }
        }
        return instance;
    }
}
```

```java
// ✅ 方式三：靜態內部類（推薦！最優雅）
// 懶加載 + 線程安全 + 無鎖
public class Singleton {
    private Singleton() {}

    // 內部類：只有在第一次調用 getInstance() 時才加載
    private static class SingletonHolder {
        // JVM 保證類加載的線程安全
        private static final Singleton INSTANCE = new Singleton();
    }

    public static Singleton getInstance() {
        return SingletonHolder.INSTANCE;
    }
}
```

```java
// ✅ 方式四：枚舉（最安全）
// 防止反射攻擊、序列化問題
public enum Singleton {
    INSTANCE;

    public void doSomething() {
        System.out.println("業務方法");
    }
}

// 使用
Singleton.INSTANCE.doSomething();
```

```java
// Spring 中的單例
// Spring Bean 預設就是單例（Singleton Scope）
@Service  // = @Component，預設 Singleton
public class OrderService { ... }

// 注意：Spring 單例 ≠ JVM 單例
// Spring 單例：一個 ApplicationContext 中只有一個實例
// JVM 單例：整個 JVM 進程只有一個實例

// ⚠️ 單例中不能有可變的成員變數（線程不安全！）
@Service
public class OrderService {
    // ❌ 不安全！多個請求共用同一個 OrderService 實例
    private Order currentOrder;

    // ✅ 使用局部變數（每次調用都是新的）
    public void process() {
        Order currentOrder = new Order(); // 局部變數，線程安全
    }
}
```

## 工廠方法模式（Factory Method）

**目的**：定義創建對象的介面，讓子類決定實例化哪個類

```java
// 場景：不同的支付方式，有不同的支付實作

// 1. 產品介面
public interface PaymentHandler {
    void pay(BigDecimal amount);
    String getType();
}

// 2. 具體產品
@Component
public class AlipayHandler implements PaymentHandler {
    @Override
    public void pay(BigDecimal amount) {
        System.out.println("支付寶支付：" + amount);
    }
    @Override
    public String getType() { return "ALIPAY"; }
}

@Component
public class WechatPayHandler implements PaymentHandler {
    @Override
    public void pay(BigDecimal amount) {
        System.out.println("微信支付：" + amount);
    }
    @Override
    public String getType() { return "WECHAT"; }
}

@Component
public class CreditCardHandler implements PaymentHandler {
    @Override
    public void pay(BigDecimal amount) {
        System.out.println("信用卡支付：" + amount);
    }
    @Override
    public String getType() { return "CREDIT_CARD"; }
}

// 3. 工廠（Spring 自動注入所有實作）
@Component
public class PaymentHandlerFactory {

    private final Map<String, PaymentHandler> handlerMap;

    // Spring 自動注入所有 PaymentHandler 的實作
    public PaymentHandlerFactory(List<PaymentHandler> handlers) {
        this.handlerMap = handlers.stream()
            .collect(Collectors.toMap(
                PaymentHandler::getType,
                handler -> handler
            ));
    }

    public PaymentHandler getHandler(String paymentType) {
        PaymentHandler handler = handlerMap.get(paymentType);
        if (handler == null) {
            throw new IllegalArgumentException(
                "不支援的支付方式：" + paymentType);
        }
        return handler;
    }
}

// 4. 使用
@Service
@RequiredArgsConstructor
public class OrderService {

    private final PaymentHandlerFactory paymentHandlerFactory;

    public void pay(Long orderId, String paymentType, BigDecimal amount) {
        // ✅ 不需要 if-else！新增支付方式只需新增 Handler 類
        PaymentHandler handler = paymentHandlerFactory.getHandler(paymentType);
        handler.pay(amount);
    }
}

// ❌ 沒有工廠模式的寫法（違反開放封閉原則）
public void pay(String paymentType, BigDecimal amount) {
    if ("ALIPAY".equals(paymentType)) {
        // 支付寶邏輯
    } else if ("WECHAT".equals(paymentType)) {
        // 微信邏輯
    } else if ("CREDIT_CARD".equals(paymentType)) {
        // 信用卡邏輯
    }
    // 每次新增支付方式，都要修改這個 if-else！❌
}
```

## 抽象工廠模式（Abstract Factory）

**目的**：創建一系列相關的對象，而不指定具體類

```java
// 場景：不同的資料庫（MySQL / PostgreSQL），有不同的連接、查詢實作

// 1. 抽象產品
public interface Connection { void connect(); }
public interface QueryBuilder { String build(String table); }

// 2. 具體產品 - MySQL
public class MySQLConnection implements Connection {
    @Override public void connect() { System.out.println("MySQL 連接"); }
}
public class MySQLQueryBuilder implements QueryBuilder {
    @Override public String build(String table) {
        return "SELECT * FROM `" + table + "`";  // MySQL 語法
    }
}

// 3. 具體產品 - PostgreSQL
public class PostgreSQLConnection implements Connection {
    @Override public void connect() { System.out.println("PostgreSQL 連接"); }
}
public class PostgreSQLQueryBuilder implements QueryBuilder {
    @Override public String build(String table) {
        return "SELECT * FROM \"" + table + "\"";  // PostgreSQL 語法
    }
}

// 4. 抽象工廠
public interface DatabaseFactory {
    Connection createConnection();
    QueryBuilder createQueryBuilder();
}

// 5. 具體工廠
public class MySQLFactory implements DatabaseFactory {
    @Override public Connection createConnection()   { return new MySQLConnection(); }
    @Override public QueryBuilder createQueryBuilder() { return new MySQLQueryBuilder(); }
}

public class PostgreSQLFactory implements DatabaseFactory {
    @Override public Connection createConnection()   { return new PostgreSQLConnection(); }
    @Override public QueryBuilder createQueryBuilder() { return new PostgreSQLQueryBuilder(); }
}

// 6. 使用（只依賴抽象工廠，不知道具體是哪個資料庫）
public class DatabaseClient {
    private final Connection     connection;
    private final QueryBuilder   queryBuilder;

    public DatabaseClient(DatabaseFactory factory) {
        this.connection   = factory.createConnection();
        this.queryBuilder = factory.createQueryBuilder();
    }

    public void query(String table) {
        connection.connect();
        String sql = queryBuilder.build(table);
        System.out.println("執行：" + sql);
    }
}
```

## 建造者模式（Builder）

**目的**：分步驟創建複雜對象，避免大量構造器參數

```java
// ❌ 沒有 Builder：構造器參數爆炸（Telescoping Constructor）
public class Order {
    public Order(Long id, Long userId, String status, BigDecimal amount,
                 String address, String phone, LocalDateTime createdAt,
                 String remark, String couponCode) { ... }
}

// 使用時完全不知道每個參數是什麼意思！
new Order(1L, 2L, "PAID", new BigDecimal("100"), "台北市", "0912345678",
          LocalDateTime.now(), "無備註", "COUPON123");
```

```java
// ✅ Builder 模式（Lombok @Builder 自動生成）
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class Order {
    private Long          id;
    private Long          userId;
    private String        status;
    private BigDecimal    amount;
    private String        address;
    private String        phone;
    private LocalDateTime createdAt;
    private String        remark;
    private String        couponCode;
}

// 使用：清晰、可讀、可選
Order order = Order.builder()
    .userId(2L)
    .status("PAID")
    .amount(new BigDecimal("100"))
    .address("台北市信義區")
    .phone("0912345678")
    .createdAt(LocalDateTime.now())
    .build();
```

```java
// ✅ 手動實作 Builder（理解原理）
public class HttpRequest {
    private final String  url;
    private final String  method;
    private final Map<String, String> headers;
    private final String  body;
    private final int     timeout;

    private HttpRequest(Builder builder) {
        this.url     = builder.url;
        this.method  = builder.method;
        this.headers = Collections.unmodifiableMap(builder.headers);
        this.body    = builder.body;
        this.timeout = builder.timeout;
    }

    // 靜態內部 Builder 類
    public static class Builder {
        // 必填參數
        private final String url;
        // 選填參數（有預設值）
        private String              method  = "GET";
        private Map<String, String> headers = new HashMap<>();
        private String              body;
        private int                 timeout = 30;

        public Builder(String url) {  // 必填參數在構造器
            this.url = url;
        }

        public Builder method(String method) {
            this.method = method;
            return this;  // 返回 this 支援鏈式調用
        }

        public Builder header(String key, String value) {
            this.headers.put(key, value);
            return this;
        }

        public Builder body(String body) {
            this.body = body;
            return this;
        }

        public Builder timeout(int timeout) {
            this.timeout = timeout;
            return this;
        }

        public HttpRequest build() {
            // 可以在這裡做驗證
            if (url == null || url.isEmpty()) {
                throw new IllegalStateException("URL 不能為空");
            }
            return new HttpRequest(this);
        }
    }
}

// 使用
HttpRequest request = new HttpRequest.Builder("https://api.example.com/orders")
    .method("POST")
    .header("Content-Type", "application/json")
    .header("Authorization", "Bearer " + token)
    .body("{\"orderId\": 123}")
    .timeout(10)
    .build();
```

## 原型模式（Prototype）

**目的**：通過複製（克隆）現有對象來創建新對象，避免重複的初始化開銷

```java
// 場景：每次建立報表配置，大部分設定相同，只有少數欄位不同
// 與其每次重新設定，直接複製已有的配置再微調

// 1. 實作 Cloneable 介面
@Data
public class ReportConfig implements Cloneable {
    private String       title;
    private List<String> columns;        // ⚠️ 注意：淺拷貝 vs 深拷貝
    private String       dateRange;
    private String       exportFormat;
    private Map<String, Object> filters;

    // 淺拷貝（Shallow Copy）
    // 基本型別和 String 是複製值
    // 但 List / Map 等引用型別仍指向同一個對象！
    @Override
    public ReportConfig clone() {
        try {
            return (ReportConfig) super.clone();
        } catch (CloneNotSupportedException e) {
            throw new RuntimeException(e);
        }
    }

    // ✅ 深拷貝（Deep Copy）- 推薦
    public ReportConfig deepClone() {
        try {
            ReportConfig cloned = (ReportConfig) super.clone();
            // 手動深拷貝引用型別
            cloned.columns = new ArrayList<>(this.columns);
            cloned.filters = new HashMap<>(this.filters);
            return cloned;
        } catch (CloneNotSupportedException e) {
            throw new RuntimeException(e);
        }
    }
}

// 2. 原型管理器（Prototype Registry）
@Component
public class ReportConfigRegistry {

    private final Map<String, ReportConfig> prototypes = new HashMap<>();

    @PostConstruct
    public void init() {
        // 預先建立幾個模板
        ReportConfig orderReport = new ReportConfig();
        orderReport.setTitle("訂單報表");
        orderReport.setColumns(List.of("訂單ID", "用戶", "金額", "狀態"));
        orderReport.setExportFormat("EXCEL");
        orderReport.setFilters(new HashMap<>());
        prototypes.put("ORDER_REPORT", orderReport);

        ReportConfig userReport = new ReportConfig();
        userReport.setTitle("用戶報表");
        userReport.setColumns(List.of("用戶ID", "姓名", "Email", "註冊時間"));
        userReport.setExportFormat("CSV");
        userReport.setFilters(new HashMap<>());
        prototypes.put("USER_REPORT", userReport);
    }

    // 取得原型的深拷貝，再自訂修改
    public ReportConfig getPrototype(String name) {
        ReportConfig prototype = prototypes.get(name);
        if (prototype == null) {
            throw new IllegalArgumentException("找不到報表模板：" + name);
        }
        return prototype.deepClone();  // 返回深拷貝，不影響原型
    }
}

// 3. 使用
@Service
@RequiredArgsConstructor
public class ReportService {

    private final ReportConfigRegistry registry;

    public void generateMonthlyOrderReport(String month) {
        // 從原型複製，再微調
        ReportConfig config = registry.getPrototype("ORDER_REPORT");
        config.setTitle("訂單月報 - " + month);       // 只改標題
        config.setDateRange(month);                    // 只改日期範圍
        config.getFilters().put("status", "PAID");     // 只加一個過濾條件

        // 不需要重新設定 columns、exportFormat 等
        generateReport(config);
    }
}

// Java 中的原型模式：
// Object.clone()
// BeanUtils.copyProperties()（Spring 工具類）
// 序列化/反序列化 實現深拷貝：
public static <T> T deepCopyBySerialization(T obj) throws Exception {
    ByteArrayOutputStream bos = new ByteArrayOutputStream();
    new ObjectOutputStream(bos).writeObject(obj);
    ByteArrayInputStream bis = new ByteArrayInputStream(bos.toByteArray());
    return (T) new ObjectInputStream(bis).readObject();
}
```
