# 實戰整合範例

```java
// 把所有新特性整合到一個真實業務場景中！

// 1. Sealed Interface + Record 定義領域模型
public sealed interface PaymentCommand
    permits PaymentCommand.Pay, PaymentCommand.Refund, PaymentCommand.Query {}

public record Pay   (Long orderId, BigDecimal amount, String method) implements PaymentCommand {}
public record Refund(Long orderId, String reason)                     implements PaymentCommand {}
public record Query (Long orderId)                                    implements PaymentCommand {}

// 2. Virtual Threads 處理高並發
@RestController
@RequestMapping("/payment")
public class PaymentController {

    @PostMapping("/process")
    public ApiResponse<String> process(@RequestBody PaymentCommand command) {
        // Spring Boot 3.2 + virtual.enabled=true，這個請求就在虛擬線程上！

        // 3. Pattern Matching Switch 處理命令
        String result = switch (command) {
            case Pay p when p.amount().compareTo(BigDecimal.ZERO) <= 0 ->
                throw new IllegalArgumentException("金額必須大於 0");
            case Pay    p -> paymentService.pay(p.orderId(), p.amount(), p.method());
            case Refund r -> paymentService.refund(r.orderId(), r.reason());
            case Query  q -> paymentService.queryStatus(q.orderId());
        };

        return ApiResponse.ok(result);
    }

    // 4. Structured Concurrency 並行查詢
    @GetMapping("/dashboard/{userId}")
    public ApiResponse<DashboardData> getDashboard(@PathVariable Long userId)
            throws Exception {

        try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
            var totalTask   = scope.fork(() -> paymentService.getTotalAmount(userId));
            var historyTask = scope.fork(() -> paymentService.getHistory(userId));
            var pendingTask = scope.fork(() -> paymentService.getPending(userId));

            scope.join().throwIfFailed();

            // 5. Record 封裝結果
            var dashboard = new DashboardData(
                totalTask.get(),
                historyTask.get(),
                pendingTask.get()
            );

            return ApiResponse.ok(dashboard);
        }
    }
}

// 6. Record 作為 DTO
public record DashboardData(
    BigDecimal           totalAmount,
    List<PaymentHistory> history,
    List<PendingPayment> pending
) {}
```
