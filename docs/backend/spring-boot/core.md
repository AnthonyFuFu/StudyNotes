# 核心原理：IoC、自動配置與 AOP

!!! abstract "本章重點"

    Spring Boot = Spring Framework + 自動配置 + 內嵌伺服器 + Starter。本章說明 IoC 與依賴注入、Bean 的生命週期與作用域、自動配置如何依條件生效，以及 AOP 代理是怎麼產生的。

Spring Boot 本身不是新框架，而是 **Spring Framework + 自動配置 + 內嵌伺服器 + Starter 依賴管理**。要理解它，先理解 Spring 的三個核心：IoC 容器、自動配置、AOP 代理。

## IoC 與依賴注入

**控制反轉（Inversion of Control）**：物件不自己 `new` 依賴，而是由容器建立好再「注入」進來。

=== "沒有 IoC"

    ``` java
    public class OrderService {
        // 自己決定用哪個實作，換實作就要改程式碼
        private final OrderDao orderDao = new JdbcOrderDao();
    }
    ```

=== "有 IoC（建構子注入）"

    ``` java
    @Service
    @RequiredArgsConstructor          // Lombok 產生建構子
    public class OrderService {
        private final OrderDao orderDao;   // 由容器注入，測試時可換成 Mock
    }
    ```

| 注入方式 | 寫法 | 建議 |
|---------|------|------|
| **建構子注入** | `final` 欄位 + 建構子 | ✅ 推薦：依賴不可變、必填、方便單元測試 |
| Setter 注入 | `@Autowired` 在 setter | 選填依賴才用 |
| 欄位注入 | `@Autowired` 在欄位 | ❌ 不推薦：無法設為 `final`，測試時必須靠反射 |

## Bean 生命週期

``` mermaid
flowchart LR
    A["實例化<br>呼叫建構子"] --> B["屬性填充<br>依賴注入"] --> C["Aware 回呼<br>BeanNameAware 等"] --> D["BeanPostProcessor<br>before"] --> E["初始化<br>@PostConstruct"]
```

``` mermaid
flowchart LR
    F["BeanPostProcessor<br>after（產生 AOP 代理）"] --> G["放入容器<br>可被使用"] --> H["容器關閉<br>@PreDestroy"]
```

!!! info "AOP 代理是在哪一步產生的？"

    在 `BeanPostProcessor#postProcessAfterInitialization`。所以容器裡拿到的 `OrderService` 其實是**代理物件**，這也是 `@Transactional` 自我呼叫失效的根本原因（見[資料存取與交易](data-access.md)）。

**Bean 作用域**

| Scope | 說明 | 使用情境 |
|-------|------|---------|
| `singleton`（預設） | 整個容器只有一個實例 | Service、DAO、無狀態元件 |
| `prototype` | 每次取用都建立新的 | 有狀態、短生命週期的物件 |
| `request` / `session` | 每個 HTTP 請求 / Session 一個 | Web 層的使用者資料 |

!!! warning "Singleton 不是執行緒安全的"

    預設所有 Bean 都是單例，會被多個請求執行緒同時使用。Bean 裡**不要放可變的成員變數**，要放就用 `ConcurrentHashMap`、`AtomicInteger` 等執行緒安全的結構（搶票系統的本地計數器就是這樣做的）。

## 自動配置原理

`@SpringBootApplication` = `@SpringBootConfiguration` + `@EnableAutoConfiguration` + `@ComponentScan`。

``` mermaid
flowchart TB
    A["@EnableAutoConfiguration"] --> B["讀取 META-INF/spring/<br>...AutoConfiguration.imports"]
    B --> C["載入上百個 XxxAutoConfiguration"]
    C --> D{"@Conditional 條件判斷"}
    D -->|"符合"| E["註冊 Bean"]
    D -->|"不符合"| F["跳過"]
```

| 條件註解 | 判斷依據 | 例子 |
|---------|---------|------|
| `@ConditionalOnClass` | classpath 上有某個類別 | 有 `RedisTemplate` 才配置 Redis |
| `@ConditionalOnMissingBean` | 使用者沒有自己定義 | 你自訂了 `ObjectMapper`，預設的就不建立 |
| `@ConditionalOnProperty` | 設定檔有某個屬性 | `spring.kafka.enabled=true` |
| `@ConditionalOnWebApplication` | 是 Web 應用 | Servlet / Reactive 分別配置 |

!!! tip "實務技巧"

    - 啟動時加上 `--debug`，會印出 **Condition Evaluation Report**，看哪些自動配置生效、哪些被跳過。
    - 想覆蓋預設行為，**自己宣告同型別的 Bean** 即可（`@ConditionalOnMissingBean` 會讓預設的退讓）。

**Starter 的作用**：`spring-boot-starter-web` 只是一份「依賴清單」，把 Spring MVC、Jackson、內嵌 Tomcat、驗證等版本相容的套件一次帶進來；真正的設定由對應的 AutoConfiguration 完成。

## AOP 與代理

AOP（Aspect-Oriented Programming）把**橫切關注點**（交易、快取、權限、日誌）從業務邏輯中抽離。Spring 透過**動態代理**實作：

=== "JDK 動態代理"

    - 目標類別**有實作介面**時使用
    - 代理物件實作同一個介面，透過反射呼叫
    - 只能代理介面方法

=== "CGLIB 代理"

    - 目標類別**沒有介面**時使用（Spring Boot 2 之後預設優先用 CGLIB）
    - 在執行期產生**子類別**覆寫方法
    - `final` 類別、`final` / `private` 方法無法被代理

``` mermaid
sequenceDiagram
    participant C as Controller
    participant P as 代理物件
    participant T as 目標 Service
    C->>P: placeOrder()
    Note over P: 前置：開啟交易 / 檢查權限
    P->>T: placeOrder()
    T-->>P: 回傳結果
    Note over P: 後置：提交或回滾 / 記錄日誌
    P-->>C: 回傳結果
```

| 常見註解 | 背後的 Advice |
|---------|--------------|
| `@Transactional` | `TransactionInterceptor`：開啟 / 提交 / 回滾交易 |
| `@Cacheable` | `CacheInterceptor`：先查快取，沒有才執行方法 |
| `@Async` | `AsyncExecutionInterceptor`：丟到執行緒池執行 |
| `@PreAuthorize` | `AuthorizationManagerBeforeMethodInterceptor`：執行前檢查權限 |

## 優點與缺點

=== "優點"

    - **約定優於配置**：自動配置讓新專案幾分鐘就能跑起來
    - **生態系最完整**：資料庫、快取、訊息佇列、安全、雲端都有官方 Starter
    - **內嵌伺服器**：打成一個可執行 JAR，非常適合容器化
    - **社群與資料量最大**：問題幾乎都找得到解答

=== "缺點"

    - **「魔法」多**：自動配置與代理讓問題難以追蹤，需要理解原理才能除錯
    - **啟動慢、記憶體大**：大量反射與類別掃描（可用 GraalVM Native Image 改善）
    - **依賴龐大**：Starter 一次帶進很多套件，JAR 動輒上百 MB
