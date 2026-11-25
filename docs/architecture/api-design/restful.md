# RESTful API 設計最佳實踐

!!! abstract "本章重點"

    好的 API 讓前端、App、第三方都能直覺地使用。本章整理 REST 的設計原則、URI 命名、HTTP 方法與冪等性、狀態碼、統一回應格式與版本管理，最後附上一份可以直接拿來檢查的設計清單。

## REST 設計六大原則

REST（Representational State Transfer）架構風格：

- ① 統一介面（Uniform Interface）
    - 資源用名詞表示，不用動詞
    - ✅ GET /orders/123
    - ❌ GET /getOrder?id=123

- ② 無狀態（Stateless）
    - 每個請求都包含完整資訊，服務器不儲存 Session
    - ✅ 每次請求帶上 JWT Token
    - ❌ 依賴服務器端 Session

- ③ 可快取（Cacheable）
    - GET 請求應該支援快取
    - 使用 Cache-Control、ETag、Last-Modified 頭

- ④ 客戶端/服務器分離（Client-Server）
    - 前後端分離，各自獨立演化

- ⑤ 分層系統（Layered System）
    - 客戶端不需要知道是直接連服務器，
    - 還是通過 Load Balancer / API Gateway

- ⑥ 按需程式碼（Code on Demand，可選）
    - 服務器可以返回可執行的程式碼（如 JavaScript）

## URI 設計規範

**資源命名規則**

| 規則 | ✅ 建議 | ❌ 避免 |
|------|--------|--------|
| 使用名詞（複數） | `/users`、`/users/123`、`/orders/456` | `/getUsers`、`/createOrder` |
| 用 HTTP 方法表達動作 | `GET /users`、`POST /orders`、`DELETE /users/123` | `/deleteUser`、`/updateOrder` |
| 層次關係用路徑表示 | `/users/123/orders`、`/users/123/orders/456` | `/orders?userId=123` 表示從屬關係 |
| 過濾、排序、分頁用查詢參數 | `GET /orders?status=PAID&sort=created_at&page=1&size=20` | `/orders/paid/page/1` |
| 小寫加連字號 | `/user-orders` | `/UserOrders`、`/user_orders` |

**特殊操作（非 CRUD）**：無法對應到 CRUD 的動作，用「資源 + 動作」的子路徑搭配 `POST`。

| 請求 | 意義 |
|------|------|
| `POST /orders/456/cancel` | 取消訂單 |
| `POST /orders/456/pay` | 付款 |
| `POST /users/123/activate` | 啟用帳號 |
| `GET /products/search?keyword=iPhone` | 搜尋 |

## HTTP 方法與冪等性

| HTTP 方法 | 語義 | 安全性 | 冪等性 |
|-----------|------|:------:|:------:|
| `GET` | 查詢 | ✅ | ✅ |
| `HEAD` | 查詢（只要 Header） | ✅ | ✅ |
| `OPTIONS` | 查詢支援的方法 | ✅ | ✅ |
| `POST` | 新增 / 提交 | ❌ | ❌ |
| `PUT` | 完整更新 | ❌ | ✅ |
| `PATCH` | 部分更新 | ❌ | ❌ |
| `DELETE` | 刪除 | ❌ | ✅ |

| 特性 | 意義 |
|------|------|
| 安全性（Safe） | 不修改服務器狀態 |
| 冪等性（Idempotent） | 多次執行結果相同 |

**重點**

| 請求 | 行為 |
|------|------|
| GET /orders/123 | 每次都返回相同訂單（安全 + 冪等） |
| POST /orders | 每次呼叫可能建立新訂單（非冪等！） |
| PUT /orders/123 | 多次更新結果相同（冪等） |
| DELETE /orders/123 | 第一次刪除，之後呼叫返回 404（冪等） |

**POST 的冪等性設計（防重複提交）**

客戶端生成唯一的 Idempotency-Key

服務器用此 Key 判斷是否重複請求

POST /payments

Idempotency-Key: uuid-abc-123

→ 第一次：建立支付，存 Redis key=uuid-abc-123, value=result

→ 重複請求：直接返回 Redis 中的結果

## HTTP Status Code 完整規範

| 狀態碼 | 意義 | 使用時機 |
|--------|------|---------|
| `100 Continue` | 繼續 | 客戶端可以繼續送出請求體 |
| `200 OK` | 成功 | 查詢成功（GET / PUT / PATCH） |
| `201 Created` | 已建立 | 建立成功（POST），回應帶 `Location` Header |
| `202 Accepted` | 已接受 | 非同步處理，例如提交背景任務 |
| `204 No Content` | 無內容 | 成功但不回傳內容（DELETE） |
| `301 Moved Permanently` | 永久重定向 | 網址永久變更 |
| `302 Found` | 臨時重定向 | 暫時導向其他網址 |
| `304 Not Modified` | 未修改 | 快取仍有效，使用本地快取 |
| `400 Bad Request` | 請求錯誤 | 格式錯誤、參數非法 |
| `401 Unauthorized` | 未認證 | 沒有 Token 或 Token 無效 |
| `403 Forbidden` | 無權限 | 已認證，但角色沒有權限 |
| `404 Not Found` | 找不到 | 資源不存在 |
| `405 Method Not Allowed` | 方法不支援 | 例如對唯讀資源送 DELETE |
| `409 Conflict` | 衝突 | 資源已存在（例如用戶名重複） |
| `410 Gone` | 已刪除 | 資源已永久刪除（與 404 不同：確定曾經存在） |
| `422 Unprocessable Entity` | 無法處理 | 格式正確，但業務驗證失敗 |
| `429 Too Many Requests` | 請求過多 | 超過限流閾值，搭配 `Retry-After` |
| `500 Internal Server Error` | 伺服器錯誤 | 未預期的例外 |
| `502 Bad Gateway` | 閘道錯誤 | 上游服務回傳無效回應 |
| `503 Service Unavailable` | 服務不可用 | 維護中或過載 |
| `504 Gateway Timeout` | 閘道逾時 | 上游服務逾時 |

```java
// Spring Boot 正確使用 Status Code
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    // 查詢 → 200 OK
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<OrderDTO>> getOrder(
            @PathVariable Long id) {
        OrderDTO order = orderService.findById(id);
        return ResponseEntity.ok(ApiResponse.success(order));
    }

    // 建立 → 201 Created（含 Location 頭）
    @PostMapping
    public ResponseEntity<ApiResponse<OrderDTO>> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderDTO order = orderService.create(request);

        URI location = ServletUriComponentsBuilder
            .fromCurrentRequest()
            .path("/{id}")
            .buildAndExpand(order.getId())
            .toUri();

        return ResponseEntity
            .created(location)  // 201 Created
            .body(ApiResponse.success(order));
    }

    // 更新 → 200 OK（返回更新後的資源）
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<OrderDTO>> updateOrder(
            @PathVariable Long id,
            @Valid @RequestBody UpdateOrderRequest request) {
        OrderDTO order = orderService.update(id, request);
        return ResponseEntity.ok(ApiResponse.success(order));
    }

    // 刪除 → 204 No Content
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteOrder(@PathVariable Long id) {
        orderService.delete(id);
        return ResponseEntity.noContent().build();  // 204
    }

    // 取消（非 CRUD 動作）→ 200 OK
    @PostMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<OrderDTO>> cancelOrder(
            @PathVariable Long id,
            @RequestBody CancelOrderRequest request) {
        OrderDTO order = orderService.cancel(id, request.getReason());
        return ResponseEntity.ok(ApiResponse.success(order));
    }

    // 非同步操作 → 202 Accepted
    @PostMapping("/export")
    public ResponseEntity<ApiResponse<String>> exportOrders(
            @RequestBody ExportRequest request) {
        String taskId = orderService.asyncExport(request);
        return ResponseEntity
            .accepted()  // 202
            .body(ApiResponse.success(taskId));
    }
}
```

## 統一響應格式

=== "統一 API 響應格式"

    ``` java
    // 統一 API 響應格式
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public class ApiResponse<T> {

        private boolean success;
        private String  code;       // 業務狀態碼
        private String  message;
        private T       data;
        private String  traceId;    // 請求追蹤 ID（方便排查）
        private Long    timestamp;

        // 成功
        public static <T> ApiResponse<T> success(T data) {
            return ApiResponse.<T>builder()
                .success(true)
                .code("SUCCESS")
                .message("操作成功")
                .data(data)
                .traceId(MDC.get("traceId"))
                .timestamp(System.currentTimeMillis())
                .build();
        }

        // 失敗
        public static <T> ApiResponse<T> fail(String code, String message) {
            return ApiResponse.<T>builder()
                .success(false)
                .code(code)
                .message(message)
                .traceId(MDC.get("traceId"))
                .timestamp(System.currentTimeMillis())
                .build();
        }
    }
    ```

=== "業務錯誤碼枚舉"

    ``` java
    // 業務錯誤碼枚舉
    public enum ErrorCode {
        // 通用錯誤
        PARAM_INVALID        ("PARAM_001", "請求參數不合法"),
        RESOURCE_NOT_FOUND   ("RESOURCE_001", "資源不存在"),
        RESOURCE_CONFLICT    ("RESOURCE_002", "資源已存在"),
        UNAUTHORIZED         ("AUTH_001", "請先登入"),
        FORBIDDEN            ("AUTH_002", "無操作權限"),
        RATE_LIMIT_EXCEEDED  ("RATE_001", "請求太頻繁，請稍後再試"),

        // 訂單錯誤
        ORDER_NOT_FOUND      ("ORDER_001", "訂單不存在"),
        ORDER_ALREADY_PAID   ("ORDER_002", "訂單已支付"),
        ORDER_CANCELLED      ("ORDER_003", "訂單已取消"),

        // 庫存錯誤
        INSUFFICIENT_STOCK   ("STOCK_001", "庫存不足"),

        // 系統錯誤
        SYSTEM_ERROR         ("SYS_001", "系統異常，請稍後再試");

        private final String code;
        private final String message;

        ErrorCode(String code, String message) {
            this.code    = code;
            this.message = message;
        }
    }
    ```

=== "全局異常處理器"

    ``` java
    // 全局異常處理器
    @RestControllerAdvice
    @Slf4j
    public class GlobalExceptionHandler {

        // 業務異常
        @ExceptionHandler(BusinessException.class)
        public ResponseEntity<ApiResponse<Void>> handleBusinessException(
                BusinessException e, HttpServletRequest request) {
            log.warn("業務異常：{}, path={}", e.getMessage(), request.getRequestURI());
            return ResponseEntity
                .status(e.getHttpStatus())
                .body(ApiResponse.fail(e.getCode(), e.getMessage()));
        }

        // 參數驗證失敗（@Valid）
        @ExceptionHandler(MethodArgumentNotValidException.class)
        public ResponseEntity<ApiResponse<Map<String, String>>> handleValidException(
                MethodArgumentNotValidException e) {

            Map<String, String> errors = e.getBindingResult()
                .getFieldErrors()
                .stream()
                .collect(Collectors.toMap(
                    FieldError::getField,
                    FieldError::getDefaultMessage,
                    (a, b) -> a
                ));

            return ResponseEntity
                .badRequest()
                .body(ApiResponse.<Map<String, String>>builder()
                    .success(false)
                    .code(ErrorCode.PARAM_INVALID.getCode())
                    .message("請求參數驗證失敗")
                    .data(errors)
                    .traceId(MDC.get("traceId"))
                    .timestamp(System.currentTimeMillis())
                    .build());
        }

        // 資源不存在
        @ExceptionHandler(ResourceNotFoundException.class)
        public ResponseEntity<ApiResponse<Void>> handleNotFoundException(
                ResourceNotFoundException e) {
            return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.fail(
                    ErrorCode.RESOURCE_NOT_FOUND.getCode(),
                    e.getMessage()
                ));
        }

        // 限流異常
        @ExceptionHandler(RateLimitException.class)
        public ResponseEntity<ApiResponse<Void>> handleRateLimitException(
                RateLimitException e) {
            return ResponseEntity
                .status(HttpStatus.TOO_MANY_REQUESTS)
                .header("Retry-After", "60")
                .body(ApiResponse.fail(
                    ErrorCode.RATE_LIMIT_EXCEEDED.getCode(),
                    ErrorCode.RATE_LIMIT_EXCEEDED.getMessage()
                ));
        }

        // 其他系統異常
        @ExceptionHandler(Exception.class)
        public ResponseEntity<ApiResponse<Void>> handleException(
                Exception e, HttpServletRequest request) {
            log.error("系統異常：path={}", request.getRequestURI(), e);
            return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.fail(
                    ErrorCode.SYSTEM_ERROR.getCode(),
                    ErrorCode.SYSTEM_ERROR.getMessage()
                    // ⚠️ 不要把 e.getMessage() 返回給客戶端！
                    // 可能洩漏系統內部資訊
                ));
        }
    }
    ```


## API 版本管理

=== "UserControllerV2"

    ``` java
    // 版本管理三種方式：


    // ① URI 版本（最常用、最清晰）
    @RestController
    @RequestMapping("/api/v1/users")
    public class UserControllerV1 { ... }

    @RestController
    @RequestMapping("/api/v2/users")
    public class UserControllerV2 { ... }

    // ② Header 版本
    @GetMapping(value = "/users", headers = "X-API-Version=1")
    public ResponseEntity<?> getUsersV1() { ... }

    @GetMapping(value = "/users", headers = "X-API-Version=2")
    public ResponseEntity<?> getUsersV2() { ... }

    // ③ Accept Header 版本
    @GetMapping(value = "/users",
        produces = "application/vnd.myapp.v1+json")
    public ResponseEntity<?> getUsersV1() { ... }

    @GetMapping(value = "/users",
        produces = "application/vnd.myapp.v2+json")
    public ResponseEntity<?> getUsersV2() { ... }

    // 版本演進策略：
    // ① 新增欄位：向後兼容，不需要新版本
    // ② 修改欄位含義/刪除欄位：需要新版本
    // ③ 舊版本維護 6~12 個月後棄用
    // ④ 在響應頭加上棄用警告：
    //    Deprecation: true
    //    Sunset: Sat, 01 Jan 2025 00:00:00 GMT
    ```

=== "API 棄用攔截器"

    ``` java
    // API 棄用攔截器
    @Component
    public class DeprecationInterceptor implements HandlerInterceptor {

        @Override
        public boolean preHandle(HttpServletRequest request,
                                 HttpServletResponse response,
                                 Object handler) {
            String path = request.getRequestURI();
            if (path.startsWith("/api/v1/")) {
                response.setHeader("Deprecation", "true");
                response.setHeader("Sunset", "Sat, 01 Jul 2025 00:00:00 GMT");
                response.setHeader("Link",
                    "</api/v2/users>; rel=\"successor-version\"");
            }
            return true;
        }
    }
    ```


## API 設計最佳實踐清單

**請求設計**

- ✅ 使用 HTTPS，禁止 HTTP
- ✅ 請求體用 JSON，Content-Type: application/json
- ✅ 使用 @Valid 驗證請求參數
- ✅ 敏感資訊不放 URL（如密碼、Token）
- ✅ 分頁參數統一：page（從0開始）, size, sort, order
- ✅ 時間統一用 ISO 8601（2024-01-15T10:30:00Z）
- ✅ 金額用字串或 Long（避免浮點數精度問題）

**響應設計**

- ✅ 統一響應格式 ApiResponse&lt;T>
- ✅ 正確使用 HTTP Status Code
- ✅ 錯誤響應帶業務錯誤碼和描述
- ✅ 響應帶 traceId（方便客戶端提供排查信息）
- ✅ 敏感欄位不返回（如密碼 hash、內部 ID）

**安全設計**

- ✅ 所有接口需要認證（除了登入、公開接口）
- ✅ 使用 JWT 或 OAuth2
- ✅ 限流保護（防暴力破解、防刷接口）
- ✅ 冪等性設計（防重複提交）
- ✅ 接口日誌審計（誰、什麼時間、做了什麼）
