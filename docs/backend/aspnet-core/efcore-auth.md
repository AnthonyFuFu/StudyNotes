# EF Core 與 Cookie 驗證

!!! abstract "本章重點"

    EF Core 是 .NET 的 ORM，地位相當於 JPA。本章比較 DB First 與 Code First、LINQ 查詢與變更追蹤，再說明 Cookie 驗證的流程、與 JWT 的取捨，以及 PBKDF2 密碼雜湊。

## Entity Framework Core

EF Core 是 .NET 官方的 ORM，地位相當於 Java 的 JPA / Hibernate。查詢用 **LINQ** 撰寫，由 EF Core 翻譯成 SQL。

### DB First 與 Code First

=== "DB First（我的做法）"

    先在 SQL Server 建好資料表，再用工具**反向產生** Entity 與 DbContext：

    ``` powershell
    Scaffold-DbContext "Name=ConnectionStrings:ChineseArtwork" `
        Microsoft.EntityFrameworkCore.SqlServer -OutputDir Models -Force
    ```

    - ✅ 資料庫已存在、由 DBA 管理時最適合
    - ✅ 搭配 ER 圖設計，資料表結構一目了然
    - ❌ 資料表變更後要重新 Scaffold，自己改過的 Entity 會被覆蓋（用 `partial class` 擴充可避免）

    !!! tip "連線字串不要寫死"

        用 `Name=ConnectionStrings:xxx` 讓產生的 DbContext 從 `appsettings.json` 讀取，避免把連線資訊寫進程式碼。

=== "Code First"

    先寫 C# 類別，再由 **Migration** 產生資料表：

    ``` powershell
    Add-Migration AddArtworkTable
    Update-Database
    ```

    - ✅ 資料表結構跟著程式碼一起版控，多環境部署一致
    - ❌ 需要熟悉 Migration，複雜的資料庫物件（預存程序、觸發器）不好管理

### DbContext 與查詢

``` csharp
public partial class ChineseArtworkContext : DbContext
{
    public virtual DbSet<Artwork> Artworks { get; set; }
    public virtual DbSet<Artist> Artists { get; set; }
    public virtual DbSet<Dictionary> Dictionaries { get; set; }
    // …其餘由 Scaffold 產生
}
```

``` csharp
var artworks = await _context.Artworks
    .AsNoTracking()                              // 唯讀查詢：不追蹤變更，速度快、省記憶體
    .Include(a => a.Artist)                      // 一起載入關聯，避免 N+1
    .Where(a => a.DynastyId == dynastyId)
    .OrderByDescending(a => a.CreateTime)
    .Skip((page - 1) * size).Take(size)          // 分頁 → OFFSET / FETCH
    .ToListAsync();
```

| 概念 | EF Core | JPA / Hibernate |
|------|---------|-----------------|
| 工作單元 | `DbContext`（Scoped，每請求一個） | `EntityManager` / 持久化上下文 |
| 查詢語言 | LINQ（編譯期型別檢查） | JPQL / Criteria API |
| 變更追蹤 | `ChangeTracker`，`SaveChanges()` 時產生 SQL | 髒檢查，flush 時產生 SQL |
| 唯讀查詢 | `AsNoTracking()` | `@Transactional(readOnly = true)` / 查詢提示 |
| 預先載入 | `Include` / `ThenInclude` | `JOIN FETCH` / `@EntityGraph` |
| 交易 | `SaveChanges()` 自帶交易；`BeginTransaction()` 手動 | `@Transactional` |

!!! warning "IQueryable 與 IEnumerable"

    `Where`、`OrderBy` 接在 `IQueryable` 上時會被翻譯成 SQL 在**資料庫**執行；一旦先呼叫了 `ToList()` 或轉成 `IEnumerable`，後面的條件就變成在**記憶體**裡過濾，會先把整張表撈回來。

### 分層：Service / DAO

chineseArtwork 把資料存取與業務邏輯分開，各自定義介面，再在 `Program.cs` 以 `AddScoped` 註冊：

``` text
Dao/Interfaces/IMemberDao.cs              Services/Interfaces/IMemberService.cs
Dao/Implementations/MemberDao.cs          Services/Implementations/MemberService.cs
```

這和 Spring 的 `@Repository` / `@Service` 分層概念相同，好處是 Controller 不直接碰 DbContext，業務邏輯可以用 Mock 測試。

## Cookie 驗證

``` mermaid
sequenceDiagram
    participant B as 瀏覽器
    participant S as ASP.NET Core
    B->>S: POST /Admin/Account/Login（帳號、密碼）
    Note over S: 驗證密碼（PBKDF2）<br>建立 ClaimsPrincipal
    S->>B: Set-Cookie: .AspNetCore.Cookies=加密票證<br>（HttpOnly）
    B->>S: GET /Admin/Dashboard（自動帶 Cookie）
    Note over S: Cookie 中介軟體解密 → 還原使用者身分<br>[Authorize] 檢查通過
    S->>B: 200 後台頁面
```

``` csharp
[HttpPost]
[ValidateAntiForgeryToken]                                       // 防 CSRF
public async Task<IActionResult> Login(LoginViewModel model)
{
    var artist = await _artistService.FindByAccountAsync(model.Account);
    if (artist == null || !_passwordService.VerifyPassword(artist.ArtPassword, model.Password))
    {
        ModelState.AddModelError("", "帳號或密碼錯誤");
        return View(model);
    }

    var claims = new List<Claim>
    {
        new Claim(ClaimTypes.Name, artist.ArtName),
        new Claim(ClaimTypes.NameIdentifier, artist.ArtId.ToString()),
        new Claim(ClaimTypes.Email, artist.ArtEmail),
        new Claim("AccountType", "Artist"),                      // 自訂 Claim
    };
    foreach (var authority in authorities)                       // 依權限表加入角色
        claims.Add(new Claim(ClaimTypes.Role, authority.Func.FuncName));

    var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
    await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
                                  new ClaimsPrincipal(identity));
    return RedirectToAction("Index", "Dashboard");
}
```

後台 Controller 加上 `[Authorize]`，沒有登入就會被導向 `LoginPath`；角色 Claim 則可以搭配 `[Authorize(Roles = "...")]` 做功能權限。

| | Cookie 驗證（chineseArtwork） | JWT（holidayDessert） |
|---|------------------------------|----------------------|
| 狀態 | 票證加密存在 Cookie，伺服器不存 Session | 無狀態，Token 自帶資訊 |
| 傳遞 | 瀏覽器自動帶上 | 前端放在 `Authorization: Bearer` |
| 撤銷 | 改 Security Stamp 或縮短效期 | 需要黑名單或短效 Token + Refresh Token |
| CSRF | ⚠️ 需要防護（ASP.NET Core 表單內建 Antiforgery Token） | Bearer Header 天然免疫 |
| 適合 | 伺服器端渲染的網站、後台 | SPA、行動 App、微服務 |

## 密碼雜湊：PBKDF2

``` csharp
public string HashPassword(string password)
{
    byte[] salt = RandomNumberGenerator.GetBytes(128 / 8);        // 每個使用者不同的隨機鹽
    string hashed = Convert.ToBase64String(KeyDerivation.Pbkdf2(
        password: password,
        salt: salt,
        prf: KeyDerivationPrf.HMACSHA256,
        iterationCount: 10000,                                    // 故意算很慢，拖慢暴力破解
        numBytesRequested: 256 / 8));
    return $"{Convert.ToBase64String(salt)}:{hashed}";            // 鹽和雜湊一起存
}
```

!!! tip "迭代次數要跟著硬體調高"

    OWASP 目前建議 PBKDF2-HMAC-SHA256 至少 **600,000** 次迭代；10,000 次是早期常見值。也可以直接使用 ASP.NET Core Identity 內建的 `PasswordHasher<T>`，它會在格式中記錄版本，日後升級演算法時能平滑轉換。Java 這邊對應的是 Spring Security 的 `BCryptPasswordEncoder` / `Pbkdf2PasswordEncoder`。

## 優點與缺點

=== "優點"

    - **LINQ** 查詢有編譯期型別檢查，重構欄位名稱很安全
    - **Scaffold** 讓 DB First 專案幾分鐘就有完整的 Entity
    - Cookie 驗證、Antiforgery、資料保護（Data Protection）都是**內建**的，安全預設值好
    - `async` / `await` 從資料庫到 Controller 一路非阻塞

=== "缺點"

    - LINQ 翻譯不出來的寫法會在執行期才報錯，複雜查詢仍要看產生的 SQL
    - DB First 重新 Scaffold 時容易覆蓋自訂內容
    - 生態以 SQL Server 最完整，其他資料庫的 Provider 成熟度不一
