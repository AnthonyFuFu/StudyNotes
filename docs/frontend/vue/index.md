---
icon: lucide/triangle
---

# Vue

漸進式前端框架：可以從 CDN 引入一小塊，也能做完整 SPA。先理解響應式系統與 Composition API，再看 Vue 3 前後端分離的實戰。

**核心技術**：響應式系統（Proxy）/ Composition API / Vue Router / Vuex / Axios / STOMP

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Vue"])
    c0["01 · Vue 核心原理"]
    R --> c0
    p0("・響應式系統對比<br>・Composition API")
    c0 --- p0
    c1["02 · 實戰：Vue 3 前後端分離"]
    R --> c1
    p1("・專案結構<br>・路由：巢狀版型 + 懶加載<br>・API 呼叫與跨網域<br>・即時客服：STOMP over WebSocket<br>・狀態管理：Vuex 與 Pinia")
    c1 --- p1
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1 chapter
    class p0,p1 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · Vue 核心原理](principles.md)__

    ---

    Vue 的核心是響應式系統：資料改變時畫面自動更新。

-   __[02 · 實戰：Vue 3 前後端分離](vue3-spa.md)__

    ---

    本章以 holiday_dessert_vue 說明 Vue 3 前後端分離的實作：巢狀版型與懶加載路由、跨網域與 Cookie 的處理、STOMP 即時客服、Vuex 與 Pinia 的比較，以及打包部署。

</div>

## 優點與缺點

| ✅ 優點 | ❌ 缺點 |
|--------|--------|
| 上手門檻最低，模板語法接近 HTML | SPA 首屏與 SEO 需要 Nuxt 補強 |
| 官方提供 Router、狀態管理、建置工具，選擇少 | Vue 2 → 3 有破壞性變更 |
| 漸進式：能嵌進 Thymeleaf 頁面，也能做完整 SPA | 大型專案的型別支援不如 Angular 嚴謹 |

!!! example "我的實作"

    - **holidayDessert**：在 Thymeleaf 頁面中以 CDN 引入 **Vue 2**，處理會員登入、註冊、驗證頁
    - **holiday_dessert_vue**：**Vue 3** SPA 版前台（Vue CLI + Router + Vuex + Axios + Sass），與 Spring Boot 後端分開部署
