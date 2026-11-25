---
icon: lucide/layout-template
---

# 伺服器端模板

由後端產生完整 HTML 再送到瀏覽器。Java 用 Thymeleaf、.NET 用 Razor；互動部分再以 jQuery、Vue 2 漸進增強。

**核心技術**：Thymeleaf / Razor（.cshtml）/ jQuery / Vue 2（CDN）/ STOMP.js

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["伺服器端模板"])
    c0["01 · Thymeleaf"]
    R --> c0
    p0("・渲染流程<br>・常用語法<br>・片段與版型<br>・與 Spring Security 整合")
    c0 --- p0
    c1["02 · 漸進增強：在伺服器頁面上加互動"]
    R --> c1
    p1("・一個頁面裡的分工<br>・jQuery：命令式更新<br>・Vue 2 從 CDN 引入：宣告式更新<br>・從混合架構走向前後端分離")
    c1 --- p1
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1 chapter
    class p0,p1 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · Thymeleaf](thymeleaf.md)__

    ---

    渲染流程 · 常用語法 · 片段與版型 · 與 Spring Security 整合

-   __[02 · 漸進增強：在伺服器頁面上加互動](progressive-enhancement.md)__

    ---

    一個頁面裡的分工 · jQuery：命令式更新 · Vue 2 從 CDN 引入：宣告式更新 · 從混合架構走向前後端分離

</div>

## Thymeleaf 與 Razor 對照

| | Thymeleaf | Razor（`.cshtml`） |
|---|-----------|-------------------|
| 平台 | Java / Spring | .NET / ASP.NET Core |
| 語法 | HTML 屬性 `th:text`、`th:each` | `@` 嵌入 C#：`@Model.Name`、`@foreach` |
| 自然模板 | ✅ 瀏覽器可直接開啟預覽 | ❌ 需要執行才能看 |
| 編譯 | 執行期解析 | **預先編譯**成 C#，效能較好 |
| 型別檢查 | 執行期才發現錯誤 | `@model` 強型別，**編譯期**檢查 |
| 共用版型 | `th:fragment` / layout-dialect | `_Layout.cshtml` + `@RenderBody()` |
| 可重用元件 | 片段 | Partial View、**ViewComponent**、Tag Helper |

Razor 的完整介紹在後端框架的 [MVC、Razor Pages 與 Areas](../../backend/aspnet-core/mvc-razor.md)。

## 什麼時候選伺服器端模板

| ✅ 適合 | ❌ 不適合 |
|--------|----------|
| 後台管理系統、內容型網站 | 高度互動的應用（拖拉、即時協作） |
| 需要 SEO、首屏要快 | 同一套後端要同時服務 Web 與 App |
| 小團隊、希望一次部署完成 | 前後端由不同團隊各自發版 |
