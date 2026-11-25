---
icon: lucide/box
---

# ASP.NET Core

微軟的跨平台 Web 框架（.NET 8 LTS）。從 Spring Boot 的角度對照學習：中介軟體管線、DI 生命週期、MVC 與 Razor Pages、EF Core 與 Cookie 驗證。

**核心技術**：.NET 8 / Kestrel / Middleware / DI / MVC / Razor Pages（.cshtml）/ EF Core / Cookie 驗證

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["ASP.NET Core"])
    c0["01 · 請求管線、DI 與設定"]
    R --> c0
    p0("・Program.cs：最小託管模型<br>・中介軟體管線<br>・依賴注入與生命週期<br>・設定系統<br>・async / await")
    c0 --- p0
    c1["02 · MVC、Razor Pages 與 Areas"]
    R --> c1
    p1("・MVC 與 Razor Pages<br>・Razor 語法速覽<br>・Areas：切分前台與後台<br>・ViewComponent：有邏輯的可重用區塊")
    c1 --- p1
    c2["03 · EF Core 與 Cookie 驗證"]
    R --> c2
    p2("・Entity Framework Core<br>・Cookie 驗證<br>・密碼雜湊：PBKDF2")
    c2 --- p2
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2 chapter
    class p0,p1,p2 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 請求管線、DI 與設定](pipeline-di.md)__

    ---

    Program.cs：最小託管模型 · 中介軟體管線 · 依賴注入與生命週期 · 設定系統 …

-   __[02 · MVC、Razor Pages 與 Areas](mvc-razor.md)__

    ---

    MVC 與 Razor Pages · Razor 語法速覽 · Areas：切分前台與後台 · ViewComponent：有邏輯的可重用區塊

-   __[03 · EF Core 與 Cookie 驗證](efcore-auth.md)__

    ---

    Entity Framework Core · Cookie 驗證 · 密碼雜湊：PBKDF2

</div>

## 與 Spring Boot 對照

| 概念 | ASP.NET Core | Spring Boot |
|------|--------------|-------------|
| 進入點 | `Program.cs`（最小託管模型） | `@SpringBootApplication` |
| 伺服器 | Kestrel | 內嵌 Tomcat / Netty |
| 請求攔截 | Middleware、Action Filter | Servlet Filter、Interceptor、AOP |
| DI 生命週期 | Singleton / **Scoped** / Transient | singleton / request / prototype |
| 模板 | **Razor（.cshtml）** | Thymeleaf |
| ORM | **EF Core**（LINQ） | JPA / Hibernate（JPQL） |
| 設定 | `appsettings.{Env}.json` | `application-{profile}.yml` |
| 非同步 | `async` / `await` + `Task` | 虛擬執行緒 / WebFlux |

## 優點與缺點

| ✅ 優點 | ❌ 缺點 |
|--------|--------|
| 效能名列前茅（TechEmpower 測試常居前段） | 生態與社群規模不如 Java |
| DI、設定、驗證、Antiforgery 都是**內建**的，安全預設值好 | `async` 會「傳染」，每一層都要改寫 |
| LINQ 有編譯期型別檢查 | 企業內部常綁定 SQL Server 與 Windows 生態 |
| Visual Studio 開發體驗極佳 | MVC、Razor Pages、Minimal API 多種寫法，風格容易不一致 |

!!! example "我的實作：chineseArtwork"

    .NET 8 的中華書畫網站：ASP.NET Core MVC（前台 + `Areas/Admin` 後台）、Razor Pages（會員 CRUD）、ViewComponent（側欄選單、麵包屑）、EF Core DB-First + SQL Server、Cookie 驗證 + PBKDF2 密碼雜湊、ImageSharp 圖片處理；並用 Python（pandas、requests、BeautifulSoup）爬取部首與字典資料。
