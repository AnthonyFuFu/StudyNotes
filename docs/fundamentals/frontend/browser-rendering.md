# 瀏覽器渲染原理

## 關鍵渲染路徑（Critical Rendering Path）

```
瀏覽器收到 HTML 後的渲染流程：

① 解析 HTML → 建構 DOM Tree
   <html>
     <body>
       <div id="app">Hello</div>
     </body>
   </html>
   → DOM Tree（節點樹）

② 解析 CSS → 建構 CSSOM Tree
   div { color: red; font-size: 16px; }
   → CSSOM Tree（樣式規則樹）

③ DOM + CSSOM → 合成 Render Tree
   只包含可見節點（display:none 不在其中）
   每個節點帶有對應的樣式

④ Layout（佈局 / 重排）
   計算每個節點的幾何位置和大小
   → 輸出：每個元素的盒子模型（x, y, width, height）

⑤ Paint（繪製 / 重繪）
   按照 Render Tree 和 Layout 結果
   將像素繪製到圖層（Layer）上

⑥ Composite（合成）
   將多個圖層合成到螢幕上
   GPU 加速層（transform / opacity）→ 只需 Composite，跳過 Layout + Paint

渲染阻塞資源：
  CSS：阻塞渲染（需要等 CSSOM 建構完成）
  JS（沒有 defer/async）：阻塞 DOM 解析 + 渲染

最佳化：
  ✅ CSS 放 <head>（越早建構 CSSOM 越好）
  ✅ JS 放 <body> 底部 或使用 defer / async
  ✅ 關鍵 CSS 內嵌（Critical CSS），非關鍵 CSS 異步加載
```

## 重排（Reflow）vs 重繪（Repaint）

```
重排（Reflow）= Layout 重新計算
  觸發條件（影響幾何屬性）：
  - 添加/刪除 DOM 元素
  - 改變 width / height / margin / padding / border
  - 改變字體大小
  - 改變 display 屬性
  - 視窗 resize
  → 代價極高！會觸發整個 Layout 過程

重繪（Repaint）= Paint 重新繪製
  觸發條件（只影響外觀，不影響幾何）：
  - 改變 color / background-color / visibility
  - 改變 border-color
  → 代價較高，但比重排輕

合成（Composite）= 只在 GPU 合成層
  只觸發 Composite，完全不觸發 Layout + Paint！
  - transform（translate / scale / rotate）
  - opacity
  → 代價最低！✅ 動畫優先使用這兩個屬性

效能建議：
  ❌ 觸發重排的動畫（使用 top / left 移動元素）
  ✅ 使用 transform: translate() 移動元素（GPU 加速）

  ❌ 多次操作 DOM（每次都可能觸發重排）
  ✅ 使用 DocumentFragment 批量操作
     或 innerHTML 一次性更新

  ❌ 在迴圈中讀取 offsetWidth（強制同步佈局）
  for (let i = 0; i < elements.length; i++) {
      elements[i].style.width = container.offsetWidth + 'px'; // 讀寫交替！
  }
  ✅ 先讀後寫
  const containerWidth = container.offsetWidth; // 先讀
  for (let i = 0; i < elements.length; i++) {
      elements[i].style.width = containerWidth + 'px'; // 再批量寫
  }
```

## 事件循環（Event Loop）

JavaScript 是單線程的，Event Loop 讓它能處理非同步。

``` mermaid
flowchart TB
    CS["Call Stack（調用棧）<br>執行同步程式碼，LIFO"]
    MI["Microtask Queue（微任務佇列）<br>Promise.then / MutationObserver / queueMicrotask<br>優先於 Macrotask，全部清空"]
    MA["Macrotask Queue（宏任務佇列）<br>setTimeout / setInterval / I/O / UI rendering<br>每次只取一個執行"]
    CS -- "棧空了" --> MI
    MI -- "微任務佇列清空" --> MA
    MA -- "執行一個宏任務後" --> CS
```

**執行順序**：同步程式碼 → 清空微任務佇列 → 執行一個宏任務 → 清空微任務佇列 → 執行一個宏任務 → …

```javascript
// 事件循環面試題
console.log('1');                          // 同步

setTimeout(() => console.log('2'), 0);    // 宏任務

Promise.resolve()
  .then(() => console.log('3'))           // 微任務
  .then(() => console.log('4'));          // 微任務

console.log('5');                          // 同步

// 輸出順序：1 → 5 → 3 → 4 → 2
// 分析：
// 同步：1, 5
// 微任務：3（then）, 4（then 的 then）
// 宏任務：2（setTimeout）
```
