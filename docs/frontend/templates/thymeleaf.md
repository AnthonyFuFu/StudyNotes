# Thymeleaf

Thymeleaf 是 Spring Boot 最常搭配的伺服器端模板引擎。最大特色是**自然模板（Natural Template）**：模板本身就是合法的 HTML，用瀏覽器直接打開也能看到版面，屬性 `th:*` 只在伺服器渲染時生效。

## 渲染流程

``` mermaid
sequenceDiagram
    participant B as 瀏覽器
    participant C as Controller
    participant T as Thymeleaf
    B->>C: GET /admin/product
    C->>C: 查詢資料，放入 Model
    C->>T: return "admin/product/list"
    T->>T: 解析 templates/admin/product/list.html<br>代入 Model 資料
    T->>B: 完整的 HTML
```

``` java
@Controller
@RequestMapping("/admin/product")
public class ProductManagement {

    @GetMapping
    public String list(Model model, @RequestParam(defaultValue = "1") int page) {
        model.addAttribute("products", productService.findPage(page));
        return "admin/product/list";      // → templates/admin/product/list.html
    }
}
```

## 常用語法

``` html
<table>
  <tr th:each="p, stat : ${products}" th:classappend="${stat.odd} ? 'odd'">
    <td th:text="${stat.count}">1</td>
    <td th:text="${p.name}">商品名稱</td>                       <!-- 預設 HTML 編碼，防 XSS -->
    <td th:text="${#numbers.formatDecimal(p.price, 0, 'COMMA', 0, 'POINT')}">100</td>
    <td>
      <span th:if="${p.stock == 0}" class="badge">售完</span>
      <a th:href="@{/admin/product/edit(id=${p.id})}">編輯</a>    <!-- 自動加上 Context Path -->
    </td>
  </tr>
</table>
```

| 語法 | 用途 | 對應 Razor |
|------|------|-----------|
| `${...}` | 變數運算式（Model 中的資料） | `@Model.xxx` |
| `*{...}` | 選取運算式，搭配 `th:object` 簡化表單 | `asp-for` |
| `@{...}` | 連結運算式，自動加上 Context Path | `asp-action` / `Url.Action` |
| `#{...}` | 國際化訊息 | `IStringLocalizer` |
| `~{...}` | 片段運算式 | `<partial>` / ViewComponent |
| `th:text` / `th:utext` | 編碼輸出 / 不編碼輸出 | `@x` / `@Html.Raw(x)` |
| `th:if` / `th:unless` / `th:switch` | 條件 | `@if` |
| `th:each` | 迴圈（`stat` 提供 index、count、odd 等） | `@foreach` |

## 片段與版型

holidayDessert 把共用的 CSS / JS 載入、頁首頁尾抽成片段，各頁面再插入：

``` html
<!-- templates/front/load/js.html -->
<th:block th:fragment="js">
  <script th:src="@{/front/js/jquery.min.js}"></script>
  <script src="https://cdn.jsdelivr.net/npm/@stomp/stompjs@7.0.0/bundles/stomp.umd.min.js"></script>
</th:block>

<!-- templates/front/index.html -->
<head th:insert="~{front/load/js :: js}"></head>
```

| 指令 | 行為 |
|------|------|
| `th:insert` | 把片段**放進**目前標籤內 |
| `th:replace` | 用片段**取代**目前標籤 |
| `th:fragment` | 定義片段，可以帶參數：`th:fragment="header(title)"` |

!!! tip "版型繼承"

    要做到 Razor `_Layout.cshtml` 那樣的「母版 + 內容」，可以加入 **thymeleaf-layout-dialect**，用 `layout:decorate` 與 `layout:fragment`。

## 與 Spring Security 整合

``` html
<div sec:authorize="hasRole('ADMIN')">
  <a th:href="@{/admin/employee}">員工管理</a>        <!-- 只有管理員看得到 -->
</div>
<span sec:authentication="name">使用者</span>

<form th:action="@{/admin/login}" method="post">      <!-- 自動加入 CSRF Token 隱藏欄位 -->
  ...
</form>
```

## 優點與缺點

=== "優點"

    - **SEO 友善、首屏快**：瀏覽器拿到的就是完整 HTML
    - **自然模板**：設計師可以直接用瀏覽器預覽靜態稿
    - **與 Spring 深度整合**：表單綁定、驗證錯誤、Security、國際化
    - **部署簡單**：前後端同一個 JAR，不需要另外架前端伺服器

=== "缺點"

    - 每次互動都要整頁重新載入，**互動性差**，要搭配 jQuery 或 Vue 補強
    - 渲染效能不如編譯式模板（Razor 會預先編譯成 C#）
    - 前後端耦合，前端工程師要懂後端專案結構
