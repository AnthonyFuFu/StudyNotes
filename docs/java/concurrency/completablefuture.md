# CompletableFuture 異步編排

## 核心 API

```java
// CompletableFuture 是 Future 的增強版
// 支援異步編排、鏈式調用、組合多個異步任務

// ─── 建立異步任務 ───

// 有返回值
CompletableFuture<User> userFuture = CompletableFuture.supplyAsync(
    () -> userService.findById(1L),
    executor  // 指定線程池（不指定用 ForkJoinPool.commonPool）
);

// 無返回值
CompletableFuture<Void> voidFuture = CompletableFuture.runAsync(
    () -> notificationService.send("通知"),
    executor
);

// ─── 鏈式調用 ───

CompletableFuture<OrderDTO> result = CompletableFuture
    // 1. 查詢用戶
    .supplyAsync(() -> userService.findById(userId), executor)

    // 2. 用用戶資訊查詢訂單（上一步的結果作為輸入）
    .thenApply(user -> orderService.findByUser(user))

    // 3. 轉換為 DTO
    .thenApply(order -> OrderDTO.from(order))

    // 4. 異常處理
    .exceptionally(ex -> {
        log.error("查詢失敗", ex);
        return OrderDTO.empty();
    });

// ─── 組合多個異步任務 ───

// 兩個任務都完成才繼續（AND 關係）
CompletableFuture<User>    userFuture2  = userService.asyncFindById(userId);
CompletableFuture<List<Order>> orderFuture = orderService.asyncFindByUser(userId);

CompletableFuture<UserOrderVO> combined = userFuture2
    .thenCombine(orderFuture, (user, orders) -> {
        return new UserOrderVO(user, orders);
    });

// 任意一個完成就繼續（OR 關係）
CompletableFuture<String> result2 = primaryFuture.applyToEither(
    fallbackFuture,
    response -> response
);

// 等待所有任務完成
CompletableFuture<Void> allDone = CompletableFuture.allOf(
    future1, future2, future3
);
allDone.join(); // 阻塞等待所有完成

// 等待任意一個完成
CompletableFuture<Object> anyDone = CompletableFuture.anyOf(
    future1, future2, future3
);
```

```java
// 實戰：並行查詢多個服務（串行 vs 並行）

// ❌ 串行（總耗時 = 各服務耗時之和）
public OrderDetailVO getOrderDetail(Long orderId) {
    Order    order   = orderService.findById(orderId);     // 100ms
    User     user    = userService.findById(order.getUserId()); // 50ms
    Product  product = productService.findById(order.getProductId()); // 80ms
    // 總計：230ms
    return new OrderDetailVO(order, user, product);
}

// ✅ 並行（總耗時 = 最慢服務的耗時）
public OrderDetailVO getOrderDetailParallel(Long orderId) {
    Order order = orderService.findById(orderId); // 必須先查

    // 並行查詢 user 和 product
    CompletableFuture<User> userFuture3 = CompletableFuture
        .supplyAsync(() -> userService.findById(order.getUserId()), executor);

    CompletableFuture<Product> productFuture = CompletableFuture
        .supplyAsync(() -> productService.findById(order.getProductId()), executor);

    // 等待兩個都完成
    CompletableFuture.allOf(userFuture3, productFuture).join();

    // 獲取結果（已完成，get() 不會阻塞）
    User    user    = userFuture3.get();
    Product product = productFuture.get();
    // 總計：max(50ms, 80ms) = 80ms（節省 150ms！）

    return new OrderDetailVO(order, user, product);
}

// 帶超時的異步任務（JDK 9+）
CompletableFuture<String> withTimeout = future
    .orTimeout(3, TimeUnit.SECONDS)          // 超時拋出 TimeoutException
    .exceptionally(ex -> "預設返回值");

// 或
CompletableFuture<String> withTimeout2 = future
    .completeOnTimeout("預設值", 3, TimeUnit.SECONDS); // 超時返回預設值
```
