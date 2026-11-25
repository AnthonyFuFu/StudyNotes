---
icon: lucide/palette
---

# 前端深度

瀏覽器渲染流程、JavaScript 核心機制、TypeScript 型別系統，以及 React / Vue 的原理與前端效能優化。

**核心技術**：React / Vue 原理 / 效能優化 / TypeScript

## 學習地圖

``` mermaid
mindmap
  root((前端深度))
    瀏覽器渲染原理
      關鍵渲染路徑
      重排（Reflow）vs 重繪（Repaint）
      事件循環（Event Loop）
    JavaScript 核心原理
      原型鏈 / 繼承
      閉包（Closure）
      作用域 / 變數提升
      非同步（Promise / async-await）
    TypeScript 深度
      類型系統
      泛型
      實用工具類型
    React 核心原理
      Virtual DOM / Diff 算法
      Fiber 架構
      Hooks 深度
      狀態管理
    Vue 核心原理
      響應式系統（Vue 2 vs Vue 3）
      虛擬 DOM / Diff
      Composition API
    前端效能優化
      載入效能
      渲染效能
      網路效能
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

-   __[04 · React 核心原理](react.md)__

    ---

    Virtual DOM 與 Diff 算法 · Fiber 架構 · Hooks 深度 · 狀態管理

-   __[05 · Vue 核心原理](vue.md)__

    ---

    響應式系統對比 · Composition API

-   __[06 · 前端效能優化](performance.md)__

    ---

    載入效能 · 渲染效能 · 網路效能

</div>

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **關鍵渲染路徑** | HTML→DOM / CSS→CSSOM → Render Tree → Layout → Paint → Composite |
| **重排 vs 重繪** | 重排代價最高，transform/opacity 只觸發 Composite |
| **Event Loop** | 同步 → 微任務（Promise）→ 宏任務（setTimeout）|
| **原型鏈** | 物件透過 `__proto__` 串連，ES6 Class 是語法糖 |
| **閉包** | 函式記住外部作用域，實現私有變數和函式工廠 |
| **Promise** | pending → fulfilled/rejected，鏈式 .then，all/race |
| **TypeScript 泛型** | 類型參數化，`<T>` 讓程式碼同時通用又型別安全 |
| **Utility Types** | Partial/Omit/Pick/Record 等，減少重複型別定義 |
| **Virtual DOM** | JS 物件描述 DOM，Diff 後最小化真實 DOM 操作 |
| **Fiber** | 可中斷的協調，優先級調度，解決主線程卡頓 |
| **React Hooks** | useState/useEffect/useCallback/useMemo/自定義 Hook |
| **Vue 3 Proxy** | 解決 Vue 2 無法偵測屬性新增/陣列 index 修改的問題 |
| **Composition API** | 邏輯集中，可複用，類比 React Custom Hook |
| **Code Splitting** | React.lazy + import() 按路由分割，減少首屏 bundle |
| **React.memo** | 避免子組件不必要重渲染，搭配 useCallback 使用 |
| **虛擬化列表** | react-window 只渲染可視區域，處理萬筆資料 |
| **HTTP 快取** | 靜態資源長期快取 + Hash 命名，HTML 用 no-cache |
