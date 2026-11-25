# 實戰：SSR、Hydration 與 UI

!!! abstract "本章重點"

    內容型網站需要 SEO 與快速首屏，Angular 可以讓每條路由各自選擇預渲染、伺服器渲染或客戶端渲染。本章說明 SSR、Hydration 與 Event Replay 的原理、SSR 的注意事項，以及 Angular Material + Tailwind 的分工。

!!! abstract "專案：chinese_artwork_angular"

    中華書畫網站的 Angular 前端，Angular 21 + **SSR（Express）** + Angular Material + Tailwind CSS + Vitest，與 ASP.NET Core 版的 chineseArtwork 是同一個主題的兩種實作。

## 為什麼要 SSR

純 SPA 的首屏是一個空的 `<div id="app">`，要等 JS 下載、執行完才有內容。對**內容型網站**（藝術家介紹、作品、字典）來說，這會影響 SEO 與首屏速度。

**純 SPA（CSR）**

``` mermaid
flowchart LR
    a1["空白 HTML"] --> a2["下載 JS"] --> a3["執行 JS"] --> a4["呼叫 API"] --> a5(["看到內容"])
```

**SSR + Hydration**

``` mermaid
flowchart LR
    b1(["完整 HTML<br>立刻看到內容"]) --> b2["下載 JS"] --> b3["Hydration<br>變成可互動"]
```

## 三種渲染模式並用

Angular 可以**每條路由各自選擇**渲染方式：

``` typescript
export const serverRoutes: ServerRoute[] = [
  { path: '',                                     renderMode: RenderMode.Prerender },
  { path: ROUTE_URL.ARTIST,                       renderMode: RenderMode.Prerender },
  { path: `${ROUTE_URL.ARTIST}/${ROUTE_URL.DETAILS}`, renderMode: RenderMode.Prerender },
  { path: ROUTE_URL.ARTWORK,                      renderMode: RenderMode.Server },     // 每次請求即時渲染
  { path: `${ROUTE_URL.ARTWORK}/${ROUTE_URL.GALLERY}`, renderMode: RenderMode.Server },
  { path: ROUTE_URL.DICTIONARY,                   renderMode: RenderMode.Prerender },
  { path: '**',                                   renderMode: RenderMode.Prerender }
];
```

| 模式 | 何時產生 HTML | 適合 | 我的使用 |
|------|-------------|------|---------|
| **Prerender（SSG）** | **建置時**產生靜態 HTML | 不常變動的內容 | 首頁、藝術家、字典 |
| **Server（SSR）** | **每次請求**時在伺服器渲染 | 經常變動、依查詢條件不同的內容 | 作品列表、作品集 |
| **Client（CSR）** | 瀏覽器端 | 需要登入、高度互動的頁面 | — |

## Hydration 與 Event Replay

``` typescript
export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideClientHydration(withEventReplay()),   // 重用伺服器渲染的 DOM，並重播使用者的早期操作
    provideHttpClient(withFetch())               // SSR 時用 fetch，伺服器端與瀏覽器端行為一致
  ]
};
```

- **Hydration**：瀏覽器端**重用**伺服器送來的 DOM，只綁上事件與狀態，不重新建立畫面，避免閃爍
- **Event Replay**：JS 還沒載完時使用者就點了按鈕，這些事件會被記錄下來，Hydration 完成後重播，不會遺失
- **HTTP 傳輸快取**：伺服器渲染時呼叫過的 API，結果會嵌在 HTML 中，瀏覽器端 Hydration 時直接使用，**不會重複請求**

!!! warning "SSR 要注意的事"

    - 伺服器端沒有 `window`、`document`、`localStorage`，要用 `isPlatformBrowser()` 或 `afterNextRender()` 包起來
    - 輪播這類操作 DOM 的第三方套件（`ngx-owl-carousel-o`）要確認支援 SSR
    - 伺服器端渲染的結果與瀏覽器端第一次渲染不一致時，Hydration 會報錯

## 伺服器：Express

`server.ts` 用 Express 啟動 Node.js 伺服器：靜態檔案直接回傳，其他路由交給 Angular 引擎渲染。部署時執行 `node dist/chinese_artwork/server/server.mjs`，前面通常再放 Nginx。

## UI：Angular Material + Tailwind

| | Angular Material | Tailwind CSS |
|---|------------------|--------------|
| 類型 | 元件庫（按鈕、對話框、表格、分頁） | 工具類別 CSS（`flex`、`p-4`、`text-lg`） |
| 優點 | 無障礙、鍵盤操作、動畫都處理好 | 版面調整快，不用想 class 名稱 |
| 搭配方式 | 互動元件用 Material | 版面、間距、響應式用 Tailwind |

## 測試：Vitest

Angular 21 的新專案預設改用 **Vitest**（取代 Karma + Jasmine），測試執行速度大幅提升，寫法與 React、Vue 專案一致。

## 優點與缺點

=== "優點"

    - **一致性高**：官方決定了專案結構、路由、表單、HTTP、測試的寫法，多人協作時程式風格統一
    - **TypeScript + DI**：大型專案重構安全，對後端工程師友善
    - **SSR / SSG 內建**：每條路由可以選擇渲染方式
    - 有固定的發版週期與長期支援（LTS）

=== "缺點"

    - **學習曲線最陡**：DI、RxJS、Signals、變更偵測都要懂
    - 對小專案來說樣板程式碼多
    - 主版本升級頻繁（每半年一版），需要跟著 `ng update`
