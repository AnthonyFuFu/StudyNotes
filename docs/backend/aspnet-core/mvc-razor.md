# MVC、Razor Pages 與 Areas

你記得的 `.cshtml` 就是 **Razor 視圖**：ASP.NET Core 的伺服器端模板語法，用 `@` 在 HTML 中嵌入 C#。同一套 Razor 語法可以用在兩種開發模式：**MVC** 與 **Razor Pages**，chineseArtwork 兩種都用了。

## MVC 與 Razor Pages

=== "MVC（Controller + View）"

    ``` csharp
    // Controllers/HomeController.cs
    public class HomeController : Controller
    {
        public async Task<IActionResult> Index()
        {
            var banners = await _bannerService.GetActiveAsync();
            return View(banners);                 // 對應 Views/Home/Index.cshtml
        }
    }
    ```

    ``` text
    Controllers/HomeController.cs     ← 一個 Controller 管多個頁面（Action）
    Views/Home/Index.cshtml
    Views/Home/About.cshtml
    Views/Shared/_Layout.cshtml       ← 共用版型
    ```

=== "Razor Pages（頁面 + PageModel）"

    ``` csharp
    // Pages/Member/Edit.cshtml.cs
    public class EditModel : PageModel
    {
        [BindProperty] public Member Member { get; set; } = default!;

        public async Task<IActionResult> OnGetAsync(int id)     // GET /Member/Edit?id=1
        {
            Member = await _context.Members.FindAsync(id);
            return Member == null ? NotFound() : Page();
        }

        public async Task<IActionResult> OnPostAsync()          // POST 表單送出
        {
            if (!ModelState.IsValid) return Page();
            _context.Attach(Member).State = EntityState.Modified;
            await _context.SaveChangesAsync();
            return RedirectToPage("./Index");
        }
    }
    ```

    ``` text
    Pages/Member/Index.cshtml   + Index.cshtml.cs    ← 一個頁面一組檔案
    Pages/Member/Create.cshtml  + Create.cshtml.cs
    Pages/Member/Edit.cshtml    + Edit.cshtml.cs
    ```

| | MVC | Razor Pages |
|---|-----|-------------|
| 組織方式 | 依**角色**分：Controller、View、Model 分開放 | 依**頁面**分：每頁的畫面與邏輯放一起 |
| 路由 | 慣例路由 `{controller}/{action}/{id?}` | 依檔案路徑，`Pages/Member/Edit` → `/Member/Edit` |
| 適合 | 複雜流程、同一組邏輯服務多個頁面、也要提供 API | 表單為主的 CRUD 頁面 |
| 我的使用 | 前台、後台（Areas/Admin） | `Pages/Member` 會員 CRUD（Scaffold 產生） |

## Razor 語法速覽

``` html
@model IEnumerable<Artwork>
@{
    ViewData["Title"] = "作品列表";
}

<h1>@ViewData["Title"]</h1>

@if (!Model.Any())
{
    <p>目前沒有作品</p>
}
else
{
    <ul>
    @foreach (var art in Model)
    {
        <li>
            <a asp-action="Details" asp-route-id="@art.Id">@art.Title</a>   <!-- Tag Helper 產生網址 -->
            <span>@art.CreateTime.ToString("yyyy-MM-dd")</span>
        </li>
    }
    </ul>
}
```

| 語法 | 作用 |
|------|------|
| `@變數`、`@(運算式)` | 輸出值，**預設自動 HTML 編碼**（防 XSS） |
| `@{ ... }` | C# 程式碼區塊 |
| `@if` / `@foreach` | 流程控制 |
| `@model T` | 宣告強型別 Model，有 IntelliSense |
| `asp-action`、`asp-for`、`asp-route-*` | **Tag Helper**：產生網址、表單欄位、驗證訊息 |
| `@Html.Raw(...)` | 不編碼直接輸出（小心 XSS） |

**共用版型**：`_ViewStart.cshtml` 指定預設 Layout；`_Layout.cshtml` 用 `@RenderBody()` 放頁面內容、`@RenderSection("Scripts", required: false)` 讓頁面插入自己的 script；`_ViewImports.cshtml` 集中 `@using` 與 Tag Helper 註冊。

## Areas：切分前台與後台

``` text
Areas/
└── Admin/
    ├── Controllers/   AccountController、DashboardController、MemberController …
    ├── Views/         各 Controller 的畫面 + 後台專用 _Layout
    ├── ViewModels/    LoginViewModel
    └── Components/    SideMenuViewComponent、BreadcrumbViewComponent
```

``` csharp
[Area("Admin")]
[Authorize]                        // 整個後台都要登入
public class DashboardController : Controller { ... }
```

路由 `{area:exists}/{controller=Dashboard}/{action=Index}/{id?}` 讓 `/Admin` 直接進入後台儀表板。Area 就像是 App 內的子應用，有自己的 Controller、View 與版型。

## ViewComponent：有邏輯的可重用區塊

Partial View 只能顯示傳進來的資料；**ViewComponent 可以自己查資料**，適合側欄選單、麵包屑、購物車小計。

``` csharp
public class SideMenuViewComponent : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync()
    {
        var menus = await _menuService.GetMenusForUserAsync(UserClaimsPrincipal);
        return View(menus);        // Views/Shared/Components/SideMenu/Default.cshtml
    }
}
```

``` html
<!-- 在後台 _Layout.cshtml 中使用 -->
<vc:side-menu></vc:side-menu>
```

| | Partial View | ViewComponent | Tag Helper |
|---|-------------|---------------|-----------|
| 自己取資料 | ❌ | ✅ | ❌ |
| 可注入服務 | ❌ | ✅ | ✅ |
| 用途 | 重複的 HTML 片段 | 有邏輯的區塊（選單、通知） | 擴充 HTML 標籤屬性 |
| 對應 Thymeleaf | `th:fragment` | 片段 + `@ModelAttribute` | 自訂 Dialect |

## 優點與缺點

=== "優點"

    - **強型別**：`@model` + Tag Helper，畫面欄位改名時編譯期就會報錯
    - **Razor Pages 快速**：Scaffold 一鍵產生 CRUD 頁面
    - **Areas、ViewComponent** 讓大型後台結構清楚
    - **Visual Studio 整合度極高**：IntelliSense、除錯、Hot Reload

=== "缺點"

    - 伺服器端渲染，**互動性強的畫面**仍需要 JavaScript 或前端框架
    - MVC 與 Razor Pages 兩種模式混用時，新人容易搞不清楚頁面在哪裡
    - 綁定 .NET 生態，模板無法給非 .NET 後端重用
