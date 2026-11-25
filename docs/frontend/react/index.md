---
icon: lucide/atom
---

# React

最主流的 UI 函式庫。從 Virtual DOM、Fiber、Hooks 的原理，到 React 19 + TypeScript + Ant Design 的實戰寫法。

**核心技術**：Virtual DOM / Fiber / Hooks / React 19 / TypeScript / Ant Design / Vitest

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["React"])
    c0["01 · React 核心原理"]
    R --> c0
    p0("・Virtual DOM 與 Diff 算法<br>・Fiber 架構<br>・Hooks 深度<br>・狀態管理")
    c0 --- p0
    c1["02 · 實戰：React 19 + TypeScript"]
    R --> c1
    p1("・技術選擇<br>・自訂 Hook：把「讀取資料」抽出來<br>・React 19 的新東西<br>・測試")
    c1 --- p1
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1 chapter
    class p0,p1 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · React 核心原理](principles.md)__

    ---

    本章從 Virtual DOM 與 Diff 演算法開始，說明 React 16 引入 Fiber 架構的原因，再深入 Hooks 的運作規則與常見陷阱，最後比較各種狀態管理方案。

-   __[02 · 實戰：React 19 + TypeScript](react-typescript.md)__

    ---

    本章以 fu-clan-management-system 說明 React 19 + TypeScript 的實戰寫法：技術選擇的理由、用自訂 Hook 處理讀取狀態與競態條件、React 19 的新功能，以及 Testing Library 的測試原則。

</div>

## 優點與缺點

| ✅ 優點 | ❌ 缺點 |
|--------|--------|
| 一切都是 JavaScript，JSX 表達力強 | 只是 UI 函式庫，路由、狀態都要自己選 |
| 自訂 Hook 讓邏輯重用很自然 | `useEffect` 依賴陣列、閉包陳舊值容易出錯 |
| 生態最大，可延伸到 React Native、Electron | 沒有 Compiler 時效能優化要自己判斷 |

!!! example "我的實作：fu-clan-management-system"

    傅氏宗親會管理系統：**Electron + React 19 + TypeScript + Vite + Ant Design 6**，資料存在本機 SQLite（sql.js）；宗親名冊、世系圖、活動行事曆、會費與收支，可從 Excel 匯入名冊。
