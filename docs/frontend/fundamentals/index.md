---
icon: lucide/file-code
---

# 前端基礎原理

不論用哪個框架都適用的底層知識：瀏覽器怎麼把 HTML 變成畫面、JavaScript 的執行機制、TypeScript 型別系統，以及效能優化。

**核心技術**：關鍵渲染路徑 / Event Loop / 閉包 / Promise / TypeScript 泛型 / 效能優化

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["前端基礎原理"])
    c0["01 · 瀏覽器渲染原理"]
    R --> c0
    p0("・關鍵渲染路徑<br>・重排（Reflow）vs 重繪<br>・事件循環")
    c0 --- p0
    c1["02 · JavaScript 核心原理"]
    R --> c1
    p1("・原型鏈<br>・閉包<br>・非同步：Promise / async-await")
    c1 --- p1
    c2["03 · TypeScript 深度"]
    R --> c2
    p2("・類型系統<br>・泛型<br>・實用工具類型")
    c2 --- p2
    c3["04 · 前端效能優化"]
    R --> c3
    p3("・載入效能<br>・渲染效能<br>・網路效能")
    c3 --- p3
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3 chapter
    class p0,p1,p2,p3 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 瀏覽器渲染原理](browser-rendering.md)__

    ---

    關鍵渲染路徑 · 重排（Reflow）vs 重繪 · 事件循環

-   __[02 · JavaScript 核心原理](javascript.md)__

    ---

    原型鏈 · 閉包 · 非同步：Promise / async-await

-   __[03 · TypeScript 深度](typescript.md)__

    ---

    類型系統 · 泛型 · 實用工具類型

-   __[04 · 前端效能優化](performance.md)__

    ---

    載入效能 · 渲染效能 · 網路效能

</div>

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **關鍵渲染路徑** | HTML→DOM / CSS→CSSOM → Render Tree → Layout → Paint → Composite |
| **重排 vs 重繪** | 重排代價最高，`transform` / `opacity` 只觸發 Composite |
| **Event Loop** | 同步 → 微任務（Promise）→ 宏任務（setTimeout） |
| **原型鏈** | 物件透過 `__proto__` 串連，ES6 Class 是語法糖 |
| **閉包** | 函式記住外部作用域，實現私有變數和函式工廠 |
| **Promise** | pending → fulfilled / rejected，鏈式 `.then`、`all` / `race` |
| **TypeScript 泛型** | 型別參數化，`<T>` 讓程式碼同時通用又型別安全 |
| **Utility Types** | `Partial` / `Omit` / `Pick` / `Record`，減少重複型別定義 |
| **Code Splitting** | 依路由動態 `import()`，減少首屏 bundle |
| **HTTP 快取** | 靜態資源長期快取 + Hash 命名，HTML 用 `no-cache` |
