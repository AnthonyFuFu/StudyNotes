---
icon: lucide/monitor
---

# 前端與桌面

用 Web 技術打造使用者介面：從瀏覽器與 JavaScript 的底層原理，到伺服器端模板、Vue、React、Angular，再延伸到以 Electron 把同一套技術包成跨平台桌面程式。

<div class="grid cards" markdown>

-   __[前端基礎原理](fundamentals/index.md)__

    ---

    不論用哪個框架都適用的底層知識：瀏覽器怎麼把 HTML 變成畫面、JavaScript 的執行機制、TypeScript 型別系統，以及效能優化。

    `4 章` · 關鍵渲染路徑 / Event Loop / 閉包 / Promise / TypeScript 泛型 / 效能優化

-   __[伺服器端模板](templates/index.md)__

    ---

    由後端產生完整 HTML 再送到瀏覽器。Java 用 Thymeleaf、.NET 用 Razor；互動部分再以 jQuery、Vue 2 漸進增強。

    `2 章` · Thymeleaf / Razor（.cshtml）/ jQuery / Vue 2（CDN）/ STOMP.js

-   __[Vue](vue/index.md)__

    ---

    漸進式前端框架：可以從 CDN 引入一小塊，也能做完整 SPA。先理解響應式系統與 Composition API，再看 Vue 3 前後端分離的實戰。

    `2 章` · 響應式系統（Proxy）/ Composition API / Vue Router / Vuex / Axios / STOMP

-   __[React](react/index.md)__

    ---

    最主流的 UI 函式庫。從 Virtual DOM、Fiber、Hooks 的原理，到 React 19 + TypeScript + Ant Design 的實戰寫法。

    `2 章` · Virtual DOM / Fiber / Hooks / React 19 / TypeScript / Ant Design / Vitest

-   __[Angular](angular/index.md)__

    ---

    Google 維護的完整前端框架：DI、路由、表單、HTTP、測試全部內建。對後端工程師來說，它的 DI + Service 思維和 Spring 非常接近。

    `2 章` · Angular 21 / Standalone 元件 / DI / RxJS / Signals / SSR / Hydration / Angular Material / Tailwind

-   __[Electron 桌面應用](electron/index.md)__

    ---

    用網頁技術做跨平台桌面程式。重點在 Main / Renderer / Preload 三種程序的分工、IPC 與安全設定，以及本機資料儲存與三平台打包。

    `2 章` · Main / Renderer / Preload / contextBridge / IPC / sql.js / electron-builder / GitHub Actions matrix

</div>

## 四種渲染架構

``` mermaid
flowchart LR
    A["伺服器端模板<br>Thymeleaf / Razor"] --> B["漸進增強<br>+ jQuery / Vue 2"] --> C["SPA<br>Vue 3 / React"] --> D["SSR + Hydration<br>Angular SSR"]
```

| 架構 | HTML 在哪裡產生 | 首屏 / SEO | 互動性 | 我的專案 |
|------|----------------|-----------|--------|---------|
| **伺服器端模板（MPA）** | 每次請求由後端產生 | ✅ 快 / 好 | 換頁要整頁重載 | holidayDessert（Thymeleaf）、chineseArtwork（Razor） |
| **SPA（CSR）** | 瀏覽器用 JS 產生 | 慢 / 差 | ✅ 最好 | holiday_dessert_vue（Vue 3） |
| **SSR / SSG + Hydration** | 伺服器先產生，瀏覽器再接手 | ✅ 快 / 好 | ✅ 好 | chinese_artwork_angular（Angular SSR） |
| **桌面應用** | 本機 Chromium | 不需要 SEO | ✅ 好，可離線 | fu-clan-management-system（Electron + React） |
