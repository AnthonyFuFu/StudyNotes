---
icon: lucide/hexagon
---

# Angular

Google 維護的完整前端框架：DI、路由、表單、HTTP、測試全部內建。對後端工程師來說，它的 DI + Service 思維和 Spring 非常接近。

**核心技術**：Angular 21 / Standalone 元件 / DI / RxJS / Signals / SSR / Hydration / Angular Material / Tailwind

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Angular"])
    c0["01 · 核心概念：元件、DI、RxJS 與 Signals"]
    R --> c0
    p0("・和 Vue / React 的定位差異<br>・Standalone 元件<br>・依賴注入<br>・RxJS：處理非同步串流<br>・Signals：更簡單的響應式狀態")
    c0 --- p0
    c1["02 · 實戰：SSR、Hydration 與 UI"]
    R --> c1
    p1("・為什麼要 SSR<br>・三種渲染模式並用<br>・Hydration 與 Event Replay<br>・伺服器：Express<br>・UI：Angular Material + Tailwind")
    c1 --- p1
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1 chapter
    class p0,p1 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 核心概念：元件、DI、RxJS 與 Signals](core.md)__

    ---

    和 Vue / React 的定位差異 · Standalone 元件 · 依賴注入 · RxJS：處理非同步串流 …

-   __[02 · 實戰：SSR、Hydration 與 UI](ssr-ui.md)__

    ---

    為什麼要 SSR · 三種渲染模式並用 · Hydration 與 Event Replay · 伺服器：Express …

</div>

## 三大框架比較

| | Angular | Vue | React |
|---|---------|-----|-------|
| 類型 | 完整框架 | 漸進式框架 | UI 函式庫 |
| 語言 | TypeScript（強制） | JS / TS | JS / TS |
| 響應式 | Signals + RxJS | Proxy（`ref` / `reactive`） | `useState` + 重新渲染 |
| 模板 | HTML 模板 + 控制流 `@if` / `@for` | HTML 模板 + 指令 `v-if` / `v-for` | JSX |
| SSR | 內建 `@angular/ssr` | Nuxt | Next.js |
| 學習曲線 | 陡 | 平緩 | 中 |
| 適合 | 大型企業系統、多人協作 | 中小型、快速開發 | 各種規模 |

!!! example "我的實作：chinese_artwork_angular"

    Angular 21 的中華書畫網站：standalone 元件、懶加載路由、**SSR + 預渲染**（每條路由各自選擇渲染模式）、Hydration + Event Replay、Angular Material + Tailwind CSS、Vitest。
