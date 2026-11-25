# Java 21 LTS 重點

## Virtual Threads - 虛擬線程（最革命性！）

### 先理解問題：傳統線程的瓶頸

**傳統平台線程（Platform Thread）**

``` mermaid
flowchart LR
    JT["Java Thread"] <-- "1:1 映射" --> OT["OS Thread<br>~1MB / 線程<br>切換成本高"]
```

!!! warning "問題"

    Spring Boot 預設線程池大小 200 → 最多同時處理 200 個請求。請求在等待 DB / IO 時，線程被白白佔用。

**虛擬線程（Virtual Thread）**

``` mermaid
flowchart LR
    subgraph VTS ["Virtual Threads（可建立百萬個）"]
        direction TB
        V1["VT 1"]
        V2["VT 2"]
        V3["VT 3"]
        V4["… VT N"]
    end
    subgraph CTS ["Carrier Threads（＝ CPU 核心數）"]
        direction TB
        C1["OS Thread 1"]
        C2["OS Thread 2"]
    end
    VTS <-- "M:N 映射" --> CTS
```

- Virtual Thread 等待 IO 時，自動讓出 Carrier Thread
- IO 完成時，Virtual Thread 重新掛載繼續執行
- **10,000 個請求同時進行，佔用極少資源**

### 實際使用

```java
// ✅ 方式一：直接建立虛擬線程
Thread vThread = Thread.ofVirtual()
    .name("my-virtual-thread")
    .start(() -> {
        System.out.println("虛擬線程執行：" + Thread.currentThread());
    });

// ✅ 方式二：虛擬線程 ExecutorService
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    for (int i = 0; i < 100_000; i++) {
        executor.submit(() -> {
            Thread.sleep(Duration.ofMillis(100));
            return processRequest();
        });
    }
} // try-with-resources 自動 shutdown

// ✅ 方式三：Spring Boot 3.2+ 設定（一行開啟！）
# application.yml
spring:
  threads:
    virtual:
      enabled: true

// ✅ 方式四：自定義虛擬線程池 Bean
@Configuration
public class ThreadConfig {

    @Bean
    public Executor taskExecutor() {
        return Executors.newVirtualThreadPerTaskExecutor();
    }
}
```

### 虛擬線程注意事項

```java
// ⚠️ 1. 避免 synchronized（會 pin 住 Carrier Thread！）
// ❌ 不好
public synchronized void badMethod() {
    someBlockingIO(); // Carrier Thread 無法讓出！
}

// ✅ 改用 ReentrantLock
private final ReentrantLock lock = new ReentrantLock();
public void goodMethod() {
    lock.lock();
    try {
        someBlockingIO(); // 虛擬線程可以自由調度
    } finally {
        lock.unlock();
    }
}

// ⚠️ 2. 不要池化虛擬線程
// ❌ 錯誤做法
var pool = Executors.newFixedThreadPool(100);
// ✅ 直接 newVirtualThreadPerTaskExecutor()，每個任務一個虛擬線程

// ⚠️ 3. 虛擬線程不適合 CPU 密集型任務
// CPU 密集型：計算量大，不等待 IO → 虛擬線程無優勢
// IO  密集型：等待 DB、網路、文件 → 虛擬線程大幅提升
```

## Pattern Matching for Switch（Java 21 正式）

```java
// 結合 Sealed Class + Record + Pattern Matching
sealed interface Shape permits Circle, Rectangle, Triangle {}
record Circle   (double radius)              implements Shape {}
record Rectangle(double width, double height) implements Shape {}
record Triangle (double base,  double height) implements Shape {}

// ✅ Pattern Matching for Switch
public String describeShape(Shape shape) {
    return switch (shape) {
        // 1. 類型匹配
        case Circle c -> "圓形，半徑 " + c.radius();

        // 2. 類型匹配 + 守衛條件（when）
        case Rectangle r when r.width() == r.height() ->
            "正方形，邊長 " + r.width();
        case Rectangle r ->
            "矩形，寬 " + r.width() + " 高 " + r.height();

        // 3. 類型匹配
        case Triangle t -> "三角形";

        // 因為是 sealed，不需要 default！
    };
}

// ✅ 處理 null 的新方式
public String process(Object obj) {
    return switch (obj) {
        case null           -> "null 值";   // Java 21 可以匹配 null！
        case Integer i      -> "整數: " + i;
        case String s       -> "字串: " + s;
        case int[] arr      -> "整數陣列，長度: " + arr.length;
        default             -> "其他: " + obj.getClass();
    };
}

// ✅ 實際業務場景：訂單事件處理
sealed interface OrderEvent permits
    OrderPlaced, OrderPaid, OrderShipped, OrderCancelled {}

record OrderPlaced   (Long orderId, Long userId, BigDecimal amount) implements OrderEvent {}
record OrderPaid     (Long orderId, String paymentMethod)           implements OrderEvent {}
record OrderShipped  (Long orderId, String trackingNo)              implements OrderEvent {}
record OrderCancelled(Long orderId, String reason)                  implements OrderEvent {}

@Service
public class OrderEventHandler {

    public void handle(OrderEvent event) {
        switch (event) {
            case OrderPlaced e -> {
                inventoryService.reserve(e.orderId());
                notificationService.sendConfirmation(e.userId());
                log.info("訂單建立: {}, 金額: {}", e.orderId(), e.amount());
            }
            case OrderPaid e -> {
                warehouseService.prepareShipment(e.orderId());
                log.info("訂單付款: {}, 方式: {}", e.orderId(), e.paymentMethod());
            }
            case OrderShipped e -> {
                notificationService.sendShippingNotice(e.orderId(), e.trackingNo());
                log.info("訂單出貨: {}, 追蹤號: {}", e.orderId(), e.trackingNo());
            }
            case OrderCancelled e when e.reason().contains("payment") -> {
                paymentService.refund(e.orderId());
                log.info("付款失敗取消: {}", e.orderId());
            }
            case OrderCancelled e -> {
                inventoryService.release(e.orderId());
                log.info("訂單取消: {}, 原因: {}", e.orderId(), e.reason());
            }
        }
    }
}
```

## Sequenced Collections（Java 21）

**問題**：之前沒有統一的接口來表示「有序集合的首尾操作」

```java
// ❌ Java 21 之前：不同集合取首尾元素方式不統一！
List<String>      list  = new ArrayList<>();
Deque<String>     deque = new ArrayDeque<>();
SortedSet<String> set   = new TreeSet<>();

list.get(0);           // List
deque.getFirst();      // Deque
set.first();           // SortedSet

list.get(list.size() - 1); // List
deque.getLast();            // Deque
set.last();                 // SortedSet
```

```java
// ✅ Java 21：統一的首尾操作
List<String> list = new ArrayList<>(List.of("A", "B", "C"));

list.getFirst();   // "A"
list.getLast();    // "C"

list.addFirst("Z");    // ["Z", "A", "B", "C"]
list.addLast("X");     // ["Z", "A", "B", "C", "X"]
list.removeFirst();    // 移除並返回 "Z"
list.removeLast();     // 移除並返回 "X"

// ✅ 反轉視圖（不是複製，是視圖！）
List<String> reversed = list.reversed();
System.out.println(reversed); // [C, B, A]

// ✅ SequencedMap
LinkedHashMap<String, Integer> map = new LinkedHashMap<>();
map.put("A", 1);
map.put("B", 2);
map.put("C", 3);

map.firstEntry();     // A=1
map.lastEntry();      // C=3
map.pollFirstEntry(); // 移除並返回 A=1
map.reversed();       // 反轉的視圖
```

## Structured Concurrency - 結構化並發（Java 21 Preview）

```java
// 場景：查詢訂單詳情需要同時查 3 個服務

// ❌ 傳統方式（難以管理取消和錯誤）
ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
Future<User>      userFuture    = executor.submit(() -> userService.findById(userId));
Future<Product>   productFuture = executor.submit(() -> productService.findById(productId));
Future<Inventory> stockFuture   = executor.submit(() -> inventoryService.check(productId));

try {
    User      user    = userFuture.get();
    Product   product = productFuture.get();
    Inventory stock   = stockFuture.get();
    // 問題：如果 userFuture 失敗，其他 Future 不會自動取消！
} catch (Exception e) {
    userFuture.cancel(true);    // 需要手動取消，容易遺漏
    productFuture.cancel(true);
    stockFuture.cancel(true);
}
```

```java
// ✅ Structured Concurrency（Java 21 Preview）
public OrderDetail getOrderDetail(Long userId, Long productId)
        throws InterruptedException, ExecutionException {

    try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
        // 1. 分叉：啟動子任務
        Subtask<User>      userTask    = scope.fork(() -> userService.findById(userId));
        Subtask<Product>   productTask = scope.fork(() -> productService.findById(productId));
        Subtask<Inventory> stockTask   = scope.fork(() -> inventoryService.check(productId));

        // 2. 等待：等所有任務完成（任一失敗則取消其他）
        scope.join()
             .throwIfFailed();

        // 3. 合併：所有任務成功才會到這裡
        return new OrderDetail(
            userTask.get(),
            productTask.get(),
            stockTask.get()
        );

    } // scope 關閉時，自動取消所有未完成的子任務！
}

// ✅ ShutdownOnSuccess - 任一成功就回傳（競速模式）
public String fetchFromFastestSource(String query)
        throws InterruptedException, ExecutionException {

    try (var scope = new StructuredTaskScope.ShutdownOnSuccess<String>()) {
        scope.fork(() -> primaryDatabase.query(query));
        scope.fork(() -> replicaDatabase.query(query));
        scope.fork(() -> cacheService.get(query));

        scope.join();
        return scope.result(); // 返回最快完成的結果
    }
}
```

## ScopedValue - 作用域值（Java 21 Preview）

```java
// ❌ ThreadLocal 的問題
// 1. 記憶體洩漏（不 remove 就殘留）
// 2. 虛擬線程中繼承 ThreadLocal 耗費大量記憶體
// 3. 可以在任何地方修改，難以追蹤

// ✅ ScopedValue - 更安全的替代方案
public class RequestContext {
    static final ScopedValue<User>   CURRENT_USER = ScopedValue.newInstance();
    static final ScopedValue<String> REQUEST_ID   = ScopedValue.newInstance();
}

// 設定值（只在 run 的範圍內有效）
User user = authService.authenticate(token);
String requestId = UUID.randomUUID().toString();

ScopedValue.where(RequestContext.CURRENT_USER, user)
           .where(RequestContext.REQUEST_ID, requestId)
           .run(() -> {
               orderService.createOrder(orderRequest);
           });
// scope 結束後，值自動清除！

// 在任何地方讀取（不需要傳參數）
@Service
public class OrderService {
    public void createOrder(OrderRequest req) {
        User   user  = RequestContext.CURRENT_USER.get();
        String reqId = RequestContext.REQUEST_ID.get();
        log.info("[{}] 用戶 {} 建立訂單", reqId, user.getId());
    }
}
```
