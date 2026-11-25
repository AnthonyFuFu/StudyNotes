# Java 17 LTS 重點

## Record Classes - 記錄類

**問題**：Java 的 POJO 類太冗長了！

```java
// ❌ 傳統 DTO，需要寫大量樣板程式碼
public class UserDTO {
    private final String name;
    private final Integer age;
    private final String email;

    public UserDTO(String name, Integer age, String email) {
        this.name  = name;
        this.age   = age;
        this.email = email;
    }

    public String  getName()  { return name;  }
    public Integer getAge()   { return age;   }
    public String  getEmail() { return email; }

    @Override public boolean equals(Object o) { /* ... */ }
    @Override public int     hashCode()       { /* ... */ }
    @Override public String  toString()       { /* ... */ }
}
```

```java
// ✅ Record（一行搞定！）
public record UserDTO(String name, Integer age, String email) {}

// 自動生成：
// - 全參構造器
// - getter（直接用 name()，不是 getName()）
// - equals() / hashCode() / toString()
// - 不可變（所有欄位 final）

// 使用方式
UserDTO user = new UserDTO("John", 30, "john@example.com");
System.out.println(user.name());  // John
System.out.println(user.age());   // 30
System.out.println(user);         // UserDTO[name=John, age=30, email=john@example.com]
```

```java
// ✅ Record 可以自定義 Compact Constructor（驗證）
public record UserDTO(String name, Integer age, String email) {

    // Compact Constructor - 不用寫參數，直接驗證
    public UserDTO {
        if (age < 0 || age > 150) {
            throw new IllegalArgumentException("年齡不合法: " + age);
        }
        if (!email.contains("@")) {
            throw new IllegalArgumentException("Email 格式錯誤: " + email);
        }
        name = name.trim(); // 可以修改值
    }

    // ✅ 可以新增靜態工廠方法
    public static UserDTO of(String name, Integer age, String email) {
        return new UserDTO(name, age, email);
    }

    // ✅ 可以新增實例方法
    public String displayName() {
        return name + " (" + age + " 歲)";
    }

    // ❌ 不能新增實例欄位（只能有靜態欄位）
    // private String extra; ← 不允許！
}
```

```java
// ✅ Record 與 Spring Boot 整合
public record ApiResponse<T>(
    boolean success,
    String  message,
    T       data
) {
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, "success", data);
    }

    public static <T> ApiResponse<T> fail(String message) {
        return new ApiResponse<>(false, message, null);
    }
}

// Controller 使用
@GetMapping("/user/{id}")
public ApiResponse<UserDTO> getUser(@PathVariable Long id) {
    UserDTO user = userService.findById(id);
    return ApiResponse.ok(user);
}
```

## Sealed Classes - 封閉類

**問題**：如何限制一個類只能被特定的子類繼承？

```java
// ✅ Sealed Class - 明確聲明允許的子類
public sealed class Shape
    permits Circle, Rectangle, Triangle {}
//  ↑ 只有這三個類可以繼承 Shape

// 子類必須選擇以下其中一個修飾符：

// 1. final - 不能再被繼承
public final class Circle extends Shape {
    private final double radius;
    public Circle(double radius) { this.radius = radius; }
    public double radius() { return radius; }
}

// 2. sealed - 可以再限制繼承
public sealed class Rectangle extends Shape
    permits Square {}

public final class Square extends Rectangle {}

// 3. non-sealed - 開放繼承（任何人都可以繼承）
public non-sealed class Triangle extends Shape {}
public class IsoscelesTriangle extends Triangle {} // ✅ 可以
```

```java
// ✅ Sealed Class 最大用途：配合 Pattern Matching（不需要 default！）
public double calculateArea(Shape shape) {
    return switch (shape) {
        case Circle    c -> Math.PI * c.radius() * c.radius();
        case Rectangle r -> r.width() * r.height();
        case Triangle  t -> t.base() * t.height() / 2;
        // ✅ 不需要 default！編譯器知道只有這三種
    };
}
```

```java
// ✅ 實際業務場景：支付結果
public sealed interface PaymentResult
    permits PaymentSuccess, PaymentFailed, PaymentPending {}

public record PaymentSuccess(String transactionId, BigDecimal amount)
    implements PaymentResult {}

public record PaymentFailed(String errorCode, String errorMessage)
    implements PaymentResult {}

public record PaymentPending(String paymentId, String redirectUrl)
    implements PaymentResult {}

// 處理支付結果（編譯器保證窮舉，不需要 default）
public ResponseEntity<?> handlePayment(PaymentResult result) {
    return switch (result) {
        case PaymentSuccess s -> ResponseEntity.ok(
            Map.of("txId", s.transactionId(), "amount", s.amount())
        );
        case PaymentFailed f -> ResponseEntity.badRequest()
            .body(Map.of("error", f.errorCode(), "msg", f.errorMessage()));
        case PaymentPending p -> ResponseEntity.status(302)
            .header("Location", p.redirectUrl())
            .build();
    };
}
```

## Pattern Matching for instanceof（Java 16 正式）

```java
// ❌ 舊式：先判斷再強轉，又臭又長
Object obj = getObject();
if (obj instanceof String) {
    String str = (String) obj;  // 多此一舉的強轉
    System.out.println(str.toUpperCase());
}

// ✅ Pattern Matching：判斷 + 轉換 + 命名 一步完成
if (obj instanceof String str) {
    System.out.println(str.toUpperCase());
}

// ✅ 可以直接在條件中使用
if (obj instanceof String str && str.length() > 5) {
    System.out.println("長字串: " + str);
}

// ✅ 複雜的類型處理
public String describe(Object obj) {
    if (obj instanceof Integer i)    return "整數：" + i;
    if (obj instanceof Long l)       return "長整數：" + l;
    if (obj instanceof String s)     return "字串，長度：" + s.length();
    if (obj instanceof List<?> list) return "列表，大小：" + list.size();
    return "未知類型：" + obj.getClass().getSimpleName();
}

// ✅ 實際業務：處理不同事件類型
public void handleEvent(Event event) {
    if (event instanceof OrderCreatedEvent e) {
        inventoryService.reserve(e.productId(), e.quantity());
        notificationService.sendOrderConfirmation(e.userId());
    } else if (event instanceof OrderCancelledEvent e) {
        inventoryService.release(e.productId(), e.quantity());
        paymentService.refund(e.orderId());
    } else if (event instanceof PaymentFailedEvent e) {
        orderService.markFailed(e.orderId(), e.reason());
    }
}
```
