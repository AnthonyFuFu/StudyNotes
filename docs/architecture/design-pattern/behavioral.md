# 行為型模式

## 觀察者模式（Observer）⭐ 事件驅動核心

**目的**：定義一對多依賴，一個對象改變時，所有依賴者都自動收到通知

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

## 策略模式（Strategy）⭐ 消滅 if-else

**目的**：定義一系列算法，封裝起來，使它們可以互相替換

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

## 模板方法模式（Template Method）

**目的**：定義算法骨架，將某些步驟延遲到子類實作

```java
// 場景：不同的數據導出（Excel / CSV / PDF），流程相同但格式不同

// 抽象類（模板）
public abstract class DataExporter<T> {

    // 模板方法（定義算法骨架，final 防止子類覆蓋）
    public final void export(List<T> data, String filePath) {
        // 固定流程
        log.info("開始導出，數據量：{}", data.size());

        validateData(data);              // 1. 驗證（通用）
        List<T> processed = processData(data);  // 2. 處理（通用）
        String  content   = format(processed);  // 3. 格式化（子類實作）
        writeToFile(content, filePath);  // 4. 寫文件（通用）
        notifyComplete(filePath);        // 5. 通知（通用）

        log.info("導出完成：{}", filePath);
    }

    // 通用步驟（在抽象類中實作）
    private void validateData(List<T> data) {
        if (data == null || data.isEmpty()) {
            throw new IllegalArgumentException("導出數據不能為空");
        }
    }

    private List<T> processData(List<T> data) {
        return data.stream()
            .filter(this::filter)  // 過濾（子類可選覆蓋）
            .collect(Collectors.toList());
    }

    private void writeToFile(String content, String filePath) {
        try (FileWriter writer = new FileWriter(filePath)) {
            writer.write(content);
        } catch (IOException e) {
            throw new RuntimeException("寫文件失敗：" + filePath, e);
        }
    }

    private void notifyComplete(String filePath) {
        log.info("文件已生成：{}", filePath);
    }

    // 抽象方法（子類必須實作）
    protected abstract String format(List<T> data);

    // 鉤子方法（子類可選覆蓋，有預設實作）
    protected boolean filter(T item) {
        return true;  // 預設不過濾
    }
}

// 子類：CSV 導出
public class CsvExporter<T> extends DataExporter<T> {
    @Override
    protected String format(List<T> data) {
        StringBuilder sb = new StringBuilder();
        // CSV 格式化邏輯
        for (T item : data) {
            sb.append(item.toString()).append("\n");
        }
        return sb.toString();
    }
}

// 子類：Excel 導出
public class ExcelExporter<T> extends DataExporter<T> {
    @Override
    protected String format(List<T> data) {
        // Excel 格式化邏輯（使用 POI 等庫）
        return "Excel content...";
    }

    // 覆蓋鉤子：只導出金額大於 0 的訂單
    @Override
    protected boolean filter(T item) {
        if (item instanceof Order) {
            return ((Order) item).getAmount().compareTo(BigDecimal.ZERO) > 0;
        }
        return true;
    }
}

// Spring 中模板方法的體現：
// JdbcTemplate.query()  → 模板（連接、執行、關閉連接）
//                          你只需要提供 SQL 和 ResultSetExtractor
// RestTemplate.exchange() → 模板（建立連接、發送請求、處理響應）
// AbstractApplicationContext.refresh() → 模板（整個容器初始化流程）
```

## 責任鏈模式（Chain of Responsibility）

**目的**：請求沿著處理鏈傳遞，每個節點決定是否處理或傳遞給下一個

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

## 狀態模式（State）

**目的**：讓對象在不同狀態下有不同的行為，消滅複雜的狀態判斷

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

## 命令模式（Command）

**目的**：將請求封裝成對象，支援撤銷、重做、隊列、日誌等操作

```java
// 場景：文字編輯器的撤銷/重做功能

// 1. 命令介面
public interface Command {
    void execute();   // 執行
    void undo();      // 撤銷
    String describe();
}

// 2. 接收者（真正執行操作的對象）
@Data
public class TextEditor {
    private StringBuilder content = new StringBuilder();

    public void insertText(int position, String text) {
        content.insert(position, text);
    }

    public void deleteText(int position, int length) {
        content.delete(position, position + length);
    }

    public String getContent() { return content.toString(); }
}

// 3. 具體命令
public class InsertCommand implements Command {
    private final TextEditor editor;
    private final int        position;
    private final String     text;

    public InsertCommand(TextEditor editor, int position, String text) {
        this.editor   = editor;
        this.position = position;
        this.text     = text;
    }

    @Override
    public void execute() {
        editor.insertText(position, text);
    }

    @Override
    public void undo() {
        editor.deleteText(position, text.length()); // 撤銷：刪除剛插入的文字
    }

    @Override
    public String describe() {
        return "插入「" + text + "」at " + position;
    }
}

public class DeleteCommand implements Command {
    private final TextEditor editor;
    private final int        position;
    private final int        length;
    private String           deletedText;  // 備份，用於撤銷

    public DeleteCommand(TextEditor editor, int position, int length) {
        this.editor   = editor;
        this.position = position;
        this.length   = length;
    }

    @Override
    public void execute() {
        // 先備份要刪除的文字
        deletedText = editor.getContent().substring(position, position + length);
        editor.deleteText(position, length);
    }

    @Override
    public void undo() {
        editor.insertText(position, deletedText); // 撤銷：把文字插回去
    }

    @Override
    public String describe() { return "刪除 " + length + " 個字元 at " + position; }
}

// 4. 命令管理器（Invoker）- 支援撤銷/重做
public class CommandManager {
    private final Deque<Command> undoStack = new ArrayDeque<>();
    private final Deque<Command> redoStack = new ArrayDeque<>();

    public void execute(Command command) {
        command.execute();
        undoStack.push(command);
        redoStack.clear();  // 執行新命令後，清除重做棧
        log.info("執行：{}", command.describe());
    }

    public void undo() {
        if (undoStack.isEmpty()) { log.info("沒有可撤銷的操作"); return; }
        Command command = undoStack.pop();
        command.undo();
        redoStack.push(command);
        log.info("撤銷：{}", command.describe());
    }

    public void redo() {
        if (redoStack.isEmpty()) { log.info("沒有可重做的操作"); return; }
        Command command = redoStack.pop();
        command.execute();
        undoStack.push(command);
        log.info("重做：{}", command.describe());
    }
}

// 5. 使用
TextEditor    editor  = new TextEditor();
CommandManager manager = new CommandManager();

manager.execute(new InsertCommand(editor, 0, "Hello"));
manager.execute(new InsertCommand(editor, 5, " World"));
System.out.println(editor.getContent()); // Hello World

manager.undo();
System.out.println(editor.getContent()); // Hello

manager.redo();
System.out.println(editor.getContent()); // Hello World

// Spring 中命令模式的應用：
// @Async 方法 → 任務封裝成 Runnable（命令）放入線程池
// Spring Batch → Job / Step 都是命令的封裝
// JdbcTemplate → SQL 操作封裝成 PreparedStatementCallback
```

## 迭代器模式（Iterator）

**目的**：提供統一的方式遍歷不同類型的集合，而不暴露其內部結構

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

## 中介者模式（Mediator）

**目的**：用一個中介對象封裝多個對象之間的交互，降低耦合

```java
// 場景：聊天室（用戶之間不直接通訊，都通過聊天室中轉）

// 1. 中介者介面
public interface ChatRoom {
    void sendMessage(String message, ChatUser sender);
    void addUser(ChatUser user);
}

// 2. 具體中介者
@Component
public class ChatRoomImpl implements ChatRoom {

    private final List<ChatUser> users = new ArrayList<>();

    @Override
    public void addUser(ChatUser user) {
        users.add(user);
        broadcast(user.getName() + " 加入了聊天室", null);
    }

    @Override
    public void sendMessage(String message, ChatUser sender) {
        users.stream()
            .filter(user -> user != sender)  // 不發給自己
            .forEach(user -> user.receive(message, sender.getName()));
    }

    private void broadcast(String message, ChatUser exclude) {
        users.stream()
            .filter(user -> user != exclude)
            .forEach(user -> user.receive(message, "系統"));
    }
}

// 3. 同事類（Colleague）- 用戶
public class ChatUser {
    private final String   name;
    private final ChatRoom chatRoom;  // 持有中介者引用

    public ChatUser(String name, ChatRoom chatRoom) {
        this.name     = name;
        this.chatRoom = chatRoom;
        chatRoom.addUser(this);
    }

    // 發送訊息：通過中介者發送，不直接聯絡其他用戶
    public void send(String message) {
        log.info("[{}] 發送：{}", name, message);
        chatRoom.sendMessage(message, this);
    }

    // 接收訊息：從中介者接收
    public void receive(String message, String from) {
        log.info("[{}] 收到來自 [{}] 的訊息：{}", name, from, message);
    }

    public String getName() { return name; }
}

// 4. 使用
ChatRoom chatRoom = new ChatRoomImpl();
ChatUser alice    = new ChatUser("Alice", chatRoom);
ChatUser bob      = new ChatUser("Bob",   chatRoom);
ChatUser charlie  = new ChatUser("Charlie", chatRoom);

alice.send("大家好！");
// Bob 收到來自 Alice 的訊息：大家好！
// Charlie 收到來自 Alice 的訊息：大家好！

// Spring 中的中介者：
// ApplicationEventPublisher → 事件匯流排，各組件通過它通訊
// MQ（RabbitMQ/Kafka）    → 服務間的中介者
// API Gateway              → 微服務間通訊的中介者
```

## 備忘錄模式（Memento）

**目的**：捕獲對象的內部狀態，並在不破壞封裝的前提下，在之後恢復它

```java
// 場景：訂單草稿的自動保存與恢復

// 1. 備忘錄（Memento）- 存儲快照
// 只有創建它的 Originator 可以存取內部狀態
public class OrderDraftMemento {
    private final String     title;
    private final List<OrderItem> items;
    private final String     couponCode;
    private final LocalDateTime savedAt;

    // 只有同包的 OrderDraft 可以存取
    OrderDraftMemento(String title, List<OrderItem> items, String couponCode) {
        this.title      = title;
        this.items      = new ArrayList<>(items);  // 深拷貝
        this.couponCode = couponCode;
        this.savedAt    = LocalDateTime.now();
    }

    String          getTitle()      { return title; }
    List<OrderItem> getItems()      { return new ArrayList<>(items); }
    String          getCouponCode() { return couponCode; }
    LocalDateTime   getSavedAt()    { return savedAt; }
}

// 2. 發起者（Originator）- 可以創建和恢復備忘錄
public class OrderDraft {
    private String          title;
    private List<OrderItem> items      = new ArrayList<>();
    private String          couponCode;

    // 創建快照
    public OrderDraftMemento save() {
        return new OrderDraftMemento(title, items, couponCode);
    }

    // 從快照恢復
    public void restore(OrderDraftMemento memento) {
        this.title      = memento.getTitle();
        this.items      = memento.getItems();
        this.couponCode = memento.getCouponCode();
        log.info("恢復到 {} 的草稿狀態", memento.getSavedAt());
    }

    // 業務方法
    public void addItem(OrderItem item)    { items.add(item); }
    public void setTitle(String title)     { this.title = title; }
    public void setCoupon(String coupon)   { this.couponCode = coupon; }
}

// 3. 管理者（Caretaker）- 管理備忘錄，不查看其內容
@Component
public class OrderDraftHistory {

    // 每個草稿可以有多個歷史版本
    private final Map<Long, Deque<OrderDraftMemento>> history = new ConcurrentHashMap<>();
    private static final int MAX_HISTORY = 10;

    public void save(Long draftId, OrderDraftMemento memento) {
        history.computeIfAbsent(draftId, k -> new ArrayDeque<>());
        Deque<OrderDraftMemento> versions = history.get(draftId);
        versions.push(memento);
        if (versions.size() > MAX_HISTORY) {
            versions.pollLast();  // 超過上限，移除最舊的
        }
    }

    public Optional<OrderDraftMemento> undo(Long draftId) {
        Deque<OrderDraftMemento> versions = history.get(draftId);
        if (versions == null || versions.size() <= 1) {
            return Optional.empty();
        }
        versions.pop();  // 移除當前版本
        return Optional.of(versions.peek());  // 返回上一個版本
    }
}

// 4. 使用
OrderDraft        draft   = new OrderDraft();
OrderDraftHistory history = new OrderDraftHistory();

draft.setTitle("我的訂單");
history.save(1L, draft.save());  // 自動保存 v1

draft.addItem(new OrderItem("商品A", 2));
history.save(1L, draft.save());  // 自動保存 v2

draft.addItem(new OrderItem("商品B", 1));
// 用戶誤操作，想撤銷

history.undo(1L).ifPresent(draft::restore);  // 恢復到 v2
```

## 訪問者模式（Visitor）

**目的**：在不修改元素類的情況下，定義作用於元素的新操作

```java
// 場景：對不同類型的商品（電子品、食品、服飾）
// 執行不同操作（計算稅率、生成報表、計算折扣）
// 且不同商品 × 不同操作組合複雜

// 1. 訪問者介面（定義對每種元素的操作）
public interface ProductVisitor {
    void visit(ElectronicsProduct product);
    void visit(FoodProduct product);
    void visit(ClothingProduct product);
}

// 2. 元素介面
public interface Product {
    String getName();
    BigDecimal getPrice();
    void accept(ProductVisitor visitor);  // 接受訪問者
}

// 3. 具體元素
@Data
@AllArgsConstructor
public class ElectronicsProduct implements Product {
    private String     name;
    private BigDecimal price;
    private int        warrantyMonths;

    @Override
    public void accept(ProductVisitor visitor) {
        visitor.visit(this);  // 雙重分派
    }
}

@Data
@AllArgsConstructor
public class FoodProduct implements Product {
    private String        name;
    private BigDecimal    price;
    private LocalDate     expiryDate;
    private boolean       organic;

    @Override
    public void accept(ProductVisitor visitor) {
        visitor.visit(this);
    }
}

@Data
@AllArgsConstructor
public class ClothingProduct implements Product {
    private String     name;
    private BigDecimal price;
    private String     size;

    @Override
    public void accept(ProductVisitor visitor) {
        visitor.visit(this);
    }
}

// 4. 具體訪問者（新增操作，不修改元素類！）

// 訪問者一：計算稅率
public class TaxCalculatorVisitor implements ProductVisitor {
    private BigDecimal totalTax = BigDecimal.ZERO;

    @Override
    public void visit(ElectronicsProduct p) {
        BigDecimal tax = p.getPrice().multiply(new BigDecimal("0.05")); // 5%
        totalTax = totalTax.add(tax);
        log.info("{} 電子稅：{}", p.getName(), tax);
    }
    @Override
    public void visit(FoodProduct p) {
        BigDecimal rate = p.isOrganic() ?
            new BigDecimal("0.0") : new BigDecimal("0.02");
        BigDecimal tax  = p.getPrice().multiply(rate);
        totalTax = totalTax.add(tax);
        log.info("{} 食品稅：{}", p.getName(), tax);
    }
    @Override
    public void visit(ClothingProduct p) {
        BigDecimal tax = p.getPrice().multiply(new BigDecimal("0.03")); // 3%
        totalTax = totalTax.add(tax);
        log.info("{} 服飾稅：{}", p.getName(), tax);
    }
    public BigDecimal getTotalTax() { return totalTax; }
}

// 訪問者二：生成報表（新操作，不需要修改任何商品類！）
public class ReportVisitor implements ProductVisitor {
    private final List<String> report = new ArrayList<>();

    @Override
    public void visit(ElectronicsProduct p) {
        report.add(String.format("電子品：%s | 價格：%s | 保固：%d個月",
            p.getName(), p.getPrice(), p.getWarrantyMonths()));
    }
    @Override
    public void visit(FoodProduct p) {
        report.add(String.format("食品：%s | 價格：%s | 到期：%s",
            p.getName(), p.getPrice(), p.getExpiryDate()));
    }
    @Override
    public void visit(ClothingProduct p) {
        report.add(String.format("服飾：%s | 價格：%s | 尺寸：%s",
            p.getName(), p.getPrice(), p.getSize()));
    }
    public List<String> getReport() { return report; }
}

// 5. 使用
List<Product> products = List.of(
    new ElectronicsProduct("iPhone 15", new BigDecimal("30000"), 12),
    new FoodProduct("有機蘋果", new BigDecimal("100"), LocalDate.now().plusDays(7), true),
    new ClothingProduct("T-Shirt", new BigDecimal("500"), "M")
);

// 計算稅金
TaxCalculatorVisitor taxVisitor = new TaxCalculatorVisitor();
products.forEach(p -> p.accept(taxVisitor));
System.out.println("總稅金：" + taxVisitor.getTotalTax());

// 生成報表（不需要修改任何商品類，只需新增 Visitor！）
ReportVisitor reportVisitor = new ReportVisitor();
products.forEach(p -> p.accept(reportVisitor));
reportVisitor.getReport().forEach(System.out::println);
```

## 直譯器模式（Interpreter）

**目的**：為語言定義文法，並建立直譯器來解釋語言中的句子

```java
// 場景：解析簡單的權限表達式
// "ADMIN AND (USER OR MANAGER)"

// 1. 抽象表達式
public interface Expression {
    boolean interpret(Set<String> context);  // context = 用戶擁有的角色
}

// 2. 終端表達式（Terminal）
public class RoleExpression implements Expression {
    private final String role;

    public RoleExpression(String role) { this.role = role; }

    @Override
    public boolean interpret(Set<String> context) {
        return context.contains(role);
    }
}

// 3. 非終端表達式（Non-Terminal）
public class AndExpression implements Expression {
    private final Expression left;
    private final Expression right;

    public AndExpression(Expression left, Expression right) {
        this.left  = left;
        this.right = right;
    }

    @Override
    public boolean interpret(Set<String> context) {
        return left.interpret(context) && right.interpret(context);
    }
}

public class OrExpression implements Expression {
    private final Expression left;
    private final Expression right;

    public OrExpression(Expression left, Expression right) {
        this.left  = left;
        this.right = right;
    }

    @Override
    public boolean interpret(Set<String> context) {
        return left.interpret(context) || right.interpret(context);
    }
}

public class NotExpression implements Expression {
    private final Expression expression;

    public NotExpression(Expression expression) {
        this.expression = expression;
    }

    @Override
    public boolean interpret(Set<String> context) {
        return !expression.interpret(context);
    }
}

// 4. 使用
// 建立表達式：ADMIN AND (USER OR MANAGER)
Expression adminExpr   = new RoleExpression("ADMIN");
Expression userExpr    = new RoleExpression("USER");
Expression managerExpr = new RoleExpression("MANAGER");

Expression userOrManager = new OrExpression(userExpr, managerExpr);
Expression rule          = new AndExpression(adminExpr, userOrManager);

// 測試
Set<String> userRoles1 = Set.of("ADMIN", "USER");
Set<String> userRoles2 = Set.of("ADMIN");
Set<String> userRoles3 = Set.of("USER", "MANAGER");

System.out.println(rule.interpret(userRoles1)); // true  (ADMIN AND USER)
System.out.println(rule.interpret(userRoles2)); // false (有 ADMIN 但沒 USER 也沒 MANAGER)
System.out.println(rule.interpret(userRoles3)); // false (沒有 ADMIN)

// Java 中直譯器模式的應用：
// java.util.regex.Pattern  → 正則表達式直譯器
// javax.el.ExpressionLanguage → EL 表達式直譯器
// Spring SpEL               → @PreAuthorize("hasRole('ADMIN')")
// SQL Parser                → SQL 語句解析
```
