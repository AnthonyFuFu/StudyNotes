# 請求管線、DI 與設定

ASP.NET Core 是微軟的跨平台 Web 框架（.NET 8 為 LTS），預設伺服器是 **Kestrel**。如果熟悉 Spring Boot，可以把它想成「微軟版的 Spring Boot」：一樣有 DI 容器、中介軟體管線、MVC、設定系統。

## Program.cs：最小託管模型

.NET 6 之後，`Startup.cs` 被合併進 `Program.cs`，分成兩段：**註冊服務**與**組裝管線**。

``` csharp
var builder = WebApplication.CreateBuilder(args);

// ① 註冊服務（相當於 Spring 的 @Bean / @Service）
builder.Services.AddControllersWithViews();
builder.Services.AddRazorPages();
builder.Services.AddDbContext<ChineseArtworkContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("ChineseArtworkConnection")));
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options => {
        options.LoginPath = "/Admin/Account/Login";
        options.ExpireTimeSpan = TimeSpan.FromDays(7);
    });
builder.Services.AddScoped<IMemberDao, MemberDao>();
builder.Services.AddScoped<IMemberService, MemberService>();

var app = builder.Build();

// ② 組裝中介軟體管線（順序很重要）
if (!app.Environment.IsDevelopment()) {
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllerRoute("areas", "{area:exists}/{controller=Dashboard}/{action=Index}/{id?}");
app.MapControllerRoute("default", "{controller=Home}/{action=Index}/{id?}");
app.MapRazorPages();
app.Run();
```

## 中介軟體管線（Middleware Pipeline）

每個中介軟體可以處理請求、呼叫下一個、再處理回應，形成一個**洋蔥模型**：

| 順序 | 中介軟體 | 作用 |
|------|---------|------|
| 1 | `UseExceptionHandler` / `UseHsts` | 捕捉後面所有中介軟體的例外 |
| 2 | `UseHttpsRedirection` | HTTP 導向 HTTPS |
| 3 | `UseStaticFiles` | 命中 `wwwroot` 的檔案就直接回應，**不再往下走** |
| 4 | `UseRouting` | 決定要交給哪個端點 |
| 5 | `UseAuthentication` → `UseAuthorization` | 先確認身分，再檢查權限 |
| 6 | `MapControllerRoute` / `MapRazorPages` | 執行 Controller 或 Razor Page |

請求由上往下經過每一層，回應再由下往上傳回去。

``` csharp
// 自訂中介軟體：記錄每個請求的耗時
app.Use(async (context, next) =>
{
    var sw = Stopwatch.StartNew();
    await next();                                   // 呼叫下一個中介軟體
    logger.LogInformation("{Path} {Ms}ms", context.Request.Path, sw.ElapsedMilliseconds);
});
```

!!! warning "順序錯了就會出問題"

    - `UseStaticFiles()` 放在 `UseAuthorization()` 前面，靜態檔案就不會被權限擋住（通常是想要的）
    - `UseAuthentication()` 一定要在 `UseAuthorization()` 前面：先知道你是誰，才能判斷你能做什麼
    - 我的專案中漏掉了 `UseAuthentication()`；Cookie 驗證仍可運作是因為 .NET 7+ 在呼叫 `AddAuthentication` 時會自動加入，但明確寫出來比較清楚

**與 Spring 的對照**

| ASP.NET Core | Spring Boot |
|--------------|-------------|
| Middleware | Servlet Filter |
| Action Filter | HandlerInterceptor / AOP |
| `[Authorize]` | `@PreAuthorize` / Security 設定 |
| Kestrel | 內嵌 Tomcat / Netty |
| `async` / `await` + `Task` | 虛擬執行緒 / WebFlux 的非阻塞 |

## 依賴注入與生命週期

ASP.NET Core **內建** DI 容器，所有東西（DbContext、Logger、設定）都透過建構子注入：

``` csharp
public class MemberService : IMemberService
{
    private readonly IMemberDao _memberDao;
    private readonly IPasswordService _passwordService;

    public MemberService(IMemberDao memberDao, IPasswordService passwordService)
    {
        _memberDao = memberDao;
        _passwordService = passwordService;
    }
}
```

| 生命週期 | 註冊方式 | 存活範圍 | 對應 Spring | 適合 |
|---------|---------|---------|------------|------|
| **Singleton** | `AddSingleton` | 整個應用程式一個 | `singleton`（預設） | 快取、設定、無狀態工具 |
| **Scoped** | `AddScoped` | **每個 HTTP 請求一個** | `request` | **DbContext**、Service、DAO |
| **Transient** | `AddTransient` | 每次注入都新建 | `prototype` | 輕量、無狀態的小物件 |

!!! danger "Captive Dependency（被俘虜的依賴）"

    **Singleton 不能注入 Scoped**。例如把 DbContext 注入 Singleton 服務，那個 DbContext 會活到程式結束、被所有請求共用，造成資料錯亂與執行緒安全問題。開發環境下 ASP.NET Core 會在啟動時直接報錯提醒你。

    這和 Spring 不同：Spring 預設全是 singleton，`EntityManager` 是透過代理拿到「目前執行緒」的實例，所以注入到 singleton 也安全。

## 設定系統

``` json
// appsettings.json
{
  "ConnectionStrings": {
    "ChineseArtworkConnection": "Server=localhost;Database=chinese_artwork;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "Logging": { "LogLevel": { "Default": "Information" } }
}
```

| 來源（後者覆蓋前者） | 用途 |
|-------------------|------|
| `appsettings.json` | 共用預設值 |
| `appsettings.{Environment}.json` | 依環境覆蓋，例如 `appsettings.Development.json` |
| 使用者祕密（User Secrets） | 開發機的密碼、金鑰，不進版控 |
| 環境變數 | 容器 / 雲端部署時覆蓋 |
| 命令列參數 | 臨時覆蓋 |

環境由 `ASPNETCORE_ENVIRONMENT` 決定，相當於 Spring 的 `spring.profiles.active`。強型別設定用 **Options 模式**：`builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"))`，再注入 `IOptions<SmtpOptions>`，對應 Spring 的 `@ConfigurationProperties`。

## async / await

ASP.NET Core 從底層就是非同步的。用 `async` 方法等待 I/O 時，執行緒會**歸還給執行緒池**，資料回來再由任一條執行緒接手：

``` csharp
public async Task<IActionResult> Index()
{
    var members = await _context.Members.AsNoTracking().ToListAsync();   // 等待時不佔執行緒
    return View(members);
}
```

!!! tip "跟 Java 的對照"

    寫法像同步程式碼、效果是非阻塞，這正是 Java 21 **虛擬執行緒**想達成的事。差別是 C# 要在每一層都寫 `async` / `await`（俗稱「async 會傳染」），Java 虛擬執行緒則不用改程式碼。
