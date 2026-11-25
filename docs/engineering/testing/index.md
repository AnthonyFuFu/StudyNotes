---
icon: lucide/flask-conical
---

# 測試

測試金字塔與各層測試工具，從 JUnit 5、Mockito 到 Spring Boot Test、Testcontainers 與 TDD 實戰。

**核心技術**：JUnit 5 / Mockito / Testcontainers / TDD

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["測試"])
    c0["01 · 測試基礎概念"]
    R --> c0
    p0("・測試金字塔<br>・測試分類<br>・好測試的標準（FIRST 原則）")
    c0 --- p0
    c1["02 · JUnit 5 深入"]
    R --> c1
    p1("・核心注解<br>・參數化測試<br>・條件測試<br>・測試生命週期")
    c1 --- p1
    c2["03 · Mockito 深入"]
    R --> c2
    p2("・Mock / Stub / Spy<br>・常用 API<br>・驗證行為<br>・ArgumentCaptor")
    c2 --- p2
    c3["04 · Spring Boot Test"]
    R --> c3
    p3("・@SpringBootTest（整合測試）<br>・@WebMvcTest（Controller 層測試）<br>・@DataJpaTest（Repository 層測試）<br>・@MockBean / @SpyBean")
    c3 --- p3
    c4["05 · Testcontainers（真實環境整合測試）"]
    R --> c4
    p4("・核心原理<br>・MySQL / Redis / Kafka 整合<br>・與 Spring Boot 整合")
    c4 --- p4
    c5["06 · TDD（測試驅動開發）"]
    R --> c5
    p5("・Red-Green-Refactor 循環<br>・TDD 實戰範例<br>・測試覆蓋率")
    c5 --- p5
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5 chapter
    class p0,p1,p2,p3,p4,p5 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 測試基礎概念](fundamentals.md)__

    ---

    測試金字塔 · FIRST 原則

-   __[02 · JUnit 5 深入](junit5.md)__

    ---

    依賴設定 · JUnit 5 核心注解 · AssertJ 斷言 · 參數化測試 · 條件測試與巢狀測試

-   __[03 · Mockito 深入](mockito.md)__

    ---

    Mock / Stub / Spy 的區別 · Mockito 完整 API · ArgumentCaptor · Spy（間諜）使用

-   __[04 · Spring Boot Test](spring-boot-test.md)__

    ---

    測試切片 · @WebMvcTest · @DataJpaTest · @SpringBootTest

-   __[05 · Testcontainers](testcontainers.md)__

    ---

    核心原理 · 整合 MySQL + Redis · Kafka 整合測試 · Flyway 與測試資料管理

-   __[06 · TDD](tdd.md)__

    ---

    Red-Green-Refactor 循環 · TDD 完整實戰 · 測試覆蓋率 · 測試最佳實踐

</div>

## 重點速覽

### 測試金字塔

``` mermaid
block-beta
    columns 5
    space:2 e2e["E2E 10%<br>Selenium / Playwright"] space:2
    space int["整合測試 20%<br>@SpringBootTest / Testcontainers"]:3 space
    unit["單元測試 70%<br>JUnit 5 + Mockito（毫秒級）"]:5
```

### 測試工具對照

| 工具 | 用途 |
|------|------|
| **JUnit 5** | 測試框架，@Test / @Nested / @ParameterizedTest |
| **Mockito** | Mock / Stub / Spy / verify / ArgumentCaptor |
| **AssertJ** | 流式斷言，比 JUnit 原生更可讀 |
| **@WebMvcTest** | Controller 層切片測試，MockMvc 模擬 HTTP |
| **@DataJpaTest** | Repository 層切片測試，H2 記憶體資料庫 |
| **@SpringBootTest** | 完整應用上下文整合測試 |
| **Testcontainers** | Docker 啟動真實 MySQL / Redis / Kafka 做整合測試 |
| **JaCoCo** | 測試覆蓋率報告，核心業務 > 80% |

### TDD 循環

- 🔴 Red（寫失敗的測試）
    - ↓
- 🟢 Green（寫最少程式碼讓測試通過）
    - ↓

🔵 Refactor（在測試保護下重構）

- ↓
- 🔴 Red（繼續下一個測試）...

### 測試命名規範
```java
// methodName_StateUnderTest_ExpectedBehavior
void createOrder_WhenInsufficientStock_ShouldThrowException() { }
void getUser_WhenUserExists_ShouldReturnUserDTO() { }
void deleteOrder_WhenOrderNotFound_ShouldReturn404() { }
```

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **測試金字塔** | 單元(70%) > 整合(20%) > E2E(10%)，越下層越快 |
| **FIRST 原則** | Fast / Independent / Repeatable / Self-validating / Timely |
| **JUnit 5** | @Test / @BeforeEach / @Nested / @ParameterizedTest |
| **AssertJ** | 流式斷言，比 JUnit 原生更可讀，支援軟斷言 |
| **參數化測試** | @CsvSource / @ValueSource / @MethodSource 減少重複代碼 |
| **Mock** | 完全模擬，隔離依賴 |
| **Stub** | 設定 Mock 方法的返回值 |
| **Spy** | 包裝真實對象，只 Mock 部分方法 |
| **verify()** | 驗證方法調用次數和順序 |
| **ArgumentCaptor** | 捕獲方法調用的參數，驗證傳入值 |
| **@WebMvcTest** | 只加載 Web 層，用 MockMvc 測試 Controller |
| **@DataJpaTest** | 只加載 JPA 層，用 H2 測試 Repository |
| **@SpringBootTest** | 完整應用上下文，真實整合測試 |
| **Testcontainers** | 用 Docker 啟動真實 MySQL/Redis/Kafka，測試更可靠 |
| **TDD** | Red（失敗）→ Green（通過）→ Refactor（重構）循環 |
| **覆蓋率** | JaCoCo，核心業務 > 80%，但品質比數字更重要 |
| **命名規範** | methodName_StateUnderTest_ExpectedBehavior |
| **AAA 結構** | Arrange（準備）/ Act（執行）/ Assert（驗證）|
