# Java 9 ~ 16 重要特性

!!! abstract "本章重點"

    Java 9 到 16 之間累積了許多實用的小改進。本章整理最常用的幾項：`var` 區域型別推斷、Text Block 多行字串、Switch 表達式與 `List.of` 等集合工廠方法。

## var - 局部類型推斷（Java 10）

```java
// ❌ 之前
HashMap<String, List<Order>> orderMap = new HashMap<String, List<Order>>();

// ✅ 使用 var（編譯期推斷，不是動態類型！）
var orderMap = new HashMap<String, List<Order>>();

// ✅ 在 for 循環中最好用
for (var entry : orderMap.entrySet()) {
    var key   = entry.getKey();     // String
    var value = entry.getValue();   // List<Order>
}

// ⚠️ 不能用的場景：
var x;                    // ❌ 無法推斷
var x = null;             // ❌ 無法推斷
var x = () -> {};         // ❌ Lambda 不能用 var
private var name = "xxx"; // ❌ 只能用於局部變數
```

## Text Block - 文字塊（Java 15 正式）

```java
// ❌ 之前寫 JSON / SQL / HTML 非常痛苦
String json = "{\n" +
              "  \"name\": \"John\",\n" +
              "  \"age\": 30\n" +
              "}";

// ✅ Text Block（三個雙引號）
String json = """
        {
          "name": "John",
          "age": 30
        }
        """;

// ✅ 寫 SQL 超方便！
String sql = """
        SELECT u.id, u.name, o.amount
        FROM users u
        JOIN orders o ON u.id = o.user_id
        WHERE u.status = 'ACTIVE'
          AND o.created_at > ?
        ORDER BY o.amount DESC
        LIMIT 10
        """;

// ✅ 支援 formatted()
String html = """
        <html>
            <body>
                <h1>%s</h1>
                <p>%s</p>
            </body>
        </html>
        """.formatted("標題", "內容");

// ⚠️ 縮排規則：結尾的 """ 位置決定縮排基準
String s1 = """
        Hello
        """;    // "Hello\n"（去掉 8 格縮排）

String s2 = """
        Hello
    """;        // "    Hello\n"（保留 4 格縮排）
```

## Switch 表達式（Java 14 正式）

```java
// ❌ 舊式 Switch（容易 fall-through 忘記 break）
String result;
switch (day) {
    case MONDAY:
    case TUESDAY:
        result = "工作日";
        break;
    case SATURDAY:
    case SUNDAY:
        result = "假日";
        break;
    default:
        result = "其他";
}

// ✅ 新式 Switch 表達式（Arrow Switch）
String result = switch (day) {
    case MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY -> "工作日";
    case SATURDAY, SUNDAY -> "假日";
};

// ✅ 需要多行邏輯時用 yield 返回值
int price = switch (productType) {
    case "FOOD" -> 100;
    case "ELECTRONICS" -> {
        int base = 500;
        int tax  = base / 10;
        yield base + tax;  // ← 用 yield 返回（不是 return！）
    }
    default -> throw new IllegalArgumentException("Unknown type: " + productType);
};
```

## 集合工廠方法（Java 9）

```java
// ✅ 快速建立不可變集合
List<String> list = List.of("A", "B", "C");
Set<String>  set  = Set.of("X", "Y", "Z");
Map<String, Integer> map = Map.of(
    "one",   1,
    "two",   2,
    "three", 3
);

// ⚠️ List.of() 是不可變的
list.add("D"); // ❌ UnsupportedOperationException

// ✅ 要可變的話
List<String> mutable = new ArrayList<>(List.of("A", "B", "C"));
```
