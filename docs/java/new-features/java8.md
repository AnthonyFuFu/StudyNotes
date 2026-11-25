# Java 8 核心回顧

!!! abstract "本章重點"

    Java 8 引入的 Lambda、Stream 與 Optional 至今仍是日常開發的基礎。本章回顧函數式介面、Stream 的進階用法（分組、收集、平行流），以及 Optional 的正確與錯誤用法。

## 函數式接口（Functional Interface）

Java 8 內建四大函數式接口：

```java
// 1. Supplier<T> - 無參數，有返回值（生產者）
Supplier<String> supplier = () -> "Hello World";
String result = supplier.get(); // "Hello World"

// 2. Consumer<T> - 有參數，無返回值（消費者）
Consumer<String> consumer = s -> System.out.println(s);
consumer.accept("Hello"); // 印出 Hello

// 3. Function<T, R> - 有參數，有返回值（轉換）
Function<String, Integer> function = s -> s.length();
Integer length = function.apply("Hello"); // 5

// 4. Predicate<T> - 有參數，返回 boolean（判斷）
Predicate<String> predicate = s -> s.length() > 3;
boolean result = predicate.test("Hello"); // true
```

## Stream API 進階用法

```java
List<Order> orders = getOrders();

// 範例：統計每個用戶的訂單總金額，取前 3 名
Map<String, Double> top3UserAmount = orders.stream()
    .filter(o -> o.getStatus() == OrderStatus.PAID)
    .collect(Collectors.groupingBy(
        Order::getUserId,
        Collectors.summingDouble(Order::getAmount)
    ))
    .entrySet().stream()
    .sorted(Map.Entry.<String, Double>comparingByValue().reversed())
    .limit(3)
    .collect(Collectors.toLinkedHashMap(
        Map.Entry::getKey,
        Map.Entry::getValue
    ));

// ⭐ flatMap - 扁平化（常考！）
List<List<Integer>> nested = List.of(
    List.of(1, 2, 3),
    List.of(4, 5, 6)
);
List<Integer> flat = nested.stream()
    .flatMap(Collection::stream)  // [[1,2,3],[4,5,6]] → [1,2,3,4,5,6]
    .collect(Collectors.toList());

// ⭐ reduce - 聚合
int sum = IntStream.rangeClosed(1, 100)
    .reduce(0, Integer::sum); // 5050

// ⭐ 並行流（注意線程安全！）
long count = orders.parallelStream()
    .filter(o -> o.getAmount() > 1000)
    .count();
```

## Optional（正確使用方式）

```java
// ❌ 錯誤用法（跟 null 判斷一樣沒意義）
Optional<User> optional = userRepository.findById(id);
if (optional.isPresent()) {
    return optional.get();
}

// ✅ 正確用法

// 1. orElse - 提供預設值
User user = userRepository.findById(id)
    .orElse(new User("default"));

// 2. orElseThrow - 拋出例外
User user = userRepository.findById(id)
    .orElseThrow(() -> new UserNotFoundException("User not found: " + id));

// 3. map + filter 鏈式操作
String city = userRepository.findById(id)
    .map(User::getAddress)
    .map(Address::getCity)
    .filter(c -> !c.isEmpty())
    .orElse("Unknown");

// 4. ifPresent - 有值才執行
userRepository.findById(id)
    .ifPresent(user -> sendWelcomeEmail(user));

// 5. ifPresentOrElse (Java 9+)
userRepository.findById(id)
    .ifPresentOrElse(
        user -> log.info("找到用戶: {}", user.getName()),
        () -> log.warn("用戶不存在")
    );
```
