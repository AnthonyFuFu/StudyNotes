# Web MVC 請求處理流程

!!! abstract "本章重點"

    一個 HTTP 請求進到 Spring MVC 後，會依序經過 Filter、DispatcherServlet、HandlerMapping、Interceptor 與 HandlerAdapter。本章說明每個元件的角色、Filter / Interceptor / AOP 的分工，以及 Thread-per-Request 模型的極限。

Spring MVC 建立在 **Servlet API** 上，採用 **Thread-per-Request** 模型：每個 HTTP 請求從 Tomcat 執行緒池拿一條執行緒，從頭跑到尾。

## 一個請求經過哪些元件

``` mermaid
flowchart TB
    subgraph S1 ["① 進入應用程式"]
        direction LR
        TC["Tomcat 執行緒"] --> FC["Filter Chain"] --> DS["DispatcherServlet"]
    end
    subgraph S2 ["② 找到並執行 Controller"]
        direction LR
        HM["HandlerMapping"] --> IC["Interceptor"] --> HA["HandlerAdapter"]
    end
    subgraph S3 ["③ 產生回應"]
        direction LR
        JSON["MessageConverter<br>轉 JSON"] ~~~ VR["ViewResolver<br>渲染 Thymeleaf"]
    end
    S1 --> S2 --> S3
```

| 元件 | 角色 | 設計模式 |
|------|------|---------|
| `DispatcherServlet` | 所有請求的統一入口 | 前端控制器（Front Controller） |
| `HandlerMapping` | URL → Controller 方法的對照 | 策略模式 |
| `HandlerAdapter` | 用統一方式呼叫各種 Handler | 適配器模式 |
| `HandlerMethodArgumentResolver` | 解析 `@RequestParam`、`@RequestBody` 等參數 | 策略模式 |
| `HttpMessageConverter` | Java 物件與 JSON / XML 互轉 | 策略模式 |
| `ViewResolver` | 邏輯視圖名稱 → 實際模板 | 策略模式 |

## Filter、Interceptor、AOP 的差別

三者都能「在請求前後做事」，差別在**作用的層級**：

| | Filter | Interceptor | AOP |
|---|--------|-------------|-----|
| 規範 | Servlet 規範 | Spring MVC | Spring AOP |
| 作用範圍 | 所有請求（含靜態資源） | 只有進到 DispatcherServlet 的請求 | 任意 Spring Bean 的方法 |
| 拿得到什麼 | `ServletRequest` / `Response` | Request + **Handler（Controller 方法）** | 方法參數、回傳值 |
| 典型用途 | 編碼、CORS、**JWT 驗證**、Spring Security | 登入檢查、權限、操作紀錄 | 交易、快取、方法執行時間 |

!!! example "我的實作：holidayDessert"

    - `filter/`：**JWT 驗證 Filter**、OAuth2 登入來源紀錄 Filter（在 Spring Security 之前就要處理 Token）
    - `interceptors/`：後台頁面的登入檢查
    - `@Async`、`@Transactional`：由 AOP 代理處理

## Thread-per-Request 模型

``` mermaid
flowchart LR
    R1["請求 1"] --> T1["執行緒 1"] --> DB1[("等待 DB 回應<br>執行緒被佔住")]
    R2["請求 2"] --> T2["執行緒 2"] --> API["等待外部 API<br>執行緒被佔住"]
    R3["請求 201"] --> Q["排隊等待<br>執行緒池已滿"]
```

- Tomcat 預設最多 **200 條**執行緒（`server.tomcat.threads.max`）
- 執行緒在等待 I/O（資料庫、外部 API）時**什麼都不做，但也不能服務別人**
- 大部分 CRUD 系統 I/O 等待時間短，這個模型**簡單、好除錯**，足夠應付

!!! tip "Java 21 之後的選擇"

    開啟虛擬執行緒 `spring.threads.virtual.enabled=true`，等待 I/O 時會自動讓出底層的 OS 執行緒，用同步寫法就能撐住大量並發。在多數場景下，這比改寫成 WebFlux 更划算（見 [Java 21 LTS 重點](../../java/new-features/java21.md)）。

## 全域例外處理

``` java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusiness(BusinessException e) {
        return ResponseEntity.badRequest().body(ApiResponse.fail(e.getCode(), e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)   // @Valid 驗證失敗
    public ResponseEntity<ApiResponse<Void>> handleValidation(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + "：" + f.getDefaultMessage())
                .collect(Collectors.joining("，"));
        return ResponseEntity.badRequest().body(ApiResponse.fail("VALIDATION_ERROR", msg));
    }
}
```

## API 文件：springdoc-openapi

加入 `springdoc-openapi-starter-webmvc-ui` 後，自動掃描 Controller 產生 OpenAPI 3 規格與 Swagger UI（`/swagger-ui.html`），前後端分離時可以直接拿來對接。

## 優點與缺點

=== "優點"

    - **同步寫法最直覺**：程式由上往下執行，堆疊追蹤完整，最好除錯
    - **生態相容性最好**：JDBC、JPA、MyBatis、各種 SDK 都是阻塞式 API，直接可用
    - **伺服器端模板**：可同時輸出 JSON API 與 Thymeleaf 頁面

=== "缺點"

    - **執行緒數 = 並發上限**：大量慢速 I/O（長輪詢、串流、呼叫很慢的外部 API）時執行緒會被耗盡
    - **每條執行緒約 1MB 堆疊**：靠加執行緒撐並發，記憶體成本高（虛擬執行緒可解）
