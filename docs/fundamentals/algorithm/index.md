---
icon: lucide/binary
---

# 演算法與資料結構

複雜度分析與常見資料結構，搭配高頻題型的解題模板，最後整理成一份解題思路速查表。

**核心技術**：雙指針 / 滑動視窗 / 鏈表 / 樹 / DP / 排序

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["演算法與資料結構"])
    c0["01 · 複雜度分析"]
    R --> c0
    p0("・時間複雜度<br>・空間複雜度")
    c0 --- p0
    c1["02 · 陣列 / 字串"]
    R --> c1
    p1("・雙指針<br>・滑動視窗")
    c1 --- p1
    c2["03 · 鏈表"]
    R --> c2
    p2("・反轉鏈表<br>・環檢測<br>・合併鏈表")
    c2 --- p2
    c3["04 · 二元樹"]
    R --> c3
    p3("・DFS（前中後序）<br>・BFS（層序遍歷）<br>・常見題型")
    c3 --- p3
    c4["05 · 動態規劃"]
    R --> c4
    p4("・背包問題<br>・最長子序列")
    c4 --- p4
    c5["06 · 排序演算法"]
    R --> c5
    p5("・快速排序<br>・合併排序")
    c5 --- p5
    c6["07 · HashMap 應用題"]
    R --> c6
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5,c6 chapter
    class p0,p1,p2,p3,p4,p5 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 複雜度分析](complexity.md)__

    ---

    複雜度分析

-   __[02 · 陣列 / 字串](array-string.md)__

    ---

    雙指針 · 滑動視窗

-   __[03 · 鏈表](linked-list.md)__

    ---

    反轉鏈表 · 環檢測 · 合併鏈表

-   __[04 · 二元樹](binary-tree.md)__

    ---

    DFS · BFS

-   __[05 · 動態規劃](dynamic-programming.md)__

    ---

    基礎 DP · 背包問題 · 最長子序列

-   __[06 · 排序演算法](sorting.md)__

    ---

    快速排序 · 合併排序 · 排序演算法對比

-   __[07 · HashMap 應用題](hashmap.md)__

    ---

    HashMap 應用題

-   __[08 · 解題思路速查](cheatsheet.md)__

    ---

    演算法解題思路速查

</div>

## 核心要點總結

| 類型 | 演算法 | 時間複雜度 | 關鍵思路 |
|------|--------|-----------|---------|
| **雙指針** | 兩數之和 / 三數之和 / 反轉字串 | O(n) | 左右指針逼近，排序後使用 |
| **滑動視窗** | 最長無重複子字串 / 最小子陣列 | O(n) | 右擴左縮，維護視窗狀態 |
| **鏈表** | 反轉 / 環檢測 / 找中點 | O(n) | 虛擬頭節點 / 快慢指針 |
| **樹 DFS** | 最大深度 / 路徑和 / LCA | O(n) | 遞迴，想清楚返回值的意義 |
| **樹 BFS** | 層序遍歷 / 右視圖 | O(n) | Queue，每層用 levelSize 控制 |
| **DP 基礎** | 爬樓梯 / 打家劫舍 | O(n) | 定義狀態，找轉移方程 |
| **背包 DP** | 0/1 背包 / 分割等和子集 | O(n×W) | 二維 → 一維，從大到小遍歷 |
| **序列 DP** | LIS / LCS / 編輯距離 | O(n²) | 以 i 結尾 / 前 i 個字符的最優值 |
| **快速排序** | 分治 + 分割 | O(n log n) 平均 | 隨機基準，Partition 原地交換 |
| **合併排序** | 分治 + 合併 | O(n log n) 穩定 | 拆分到單元素，再合併 |
| **HashMap** | 兩數之和 / 子陣列和 / LRU | O(n) | 以空間換時間，記錄出現過的值 |
| **前綴和** | 子陣列和為 K | O(n) | prefixSum[i] - prefixSum[j] = 區間和 |
