---
icon: lucide/sparkles
---

# Java 新特性

從 Java 8 一路到 Java 21 LTS，整理每個版本真正值得在專案中使用的特性，以及它們解決了什麼問題。

**核心技術**：Virtual Threads / Record / Sealed Class / Pattern Matching

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["Java 新特性"])
    c0["01 · Java 8 核心回顧（基礎，面試常考）"]
    R --> c0
    p0("・Lambda & 函數式接口<br>・Stream API 進階<br>・Optional")
    c0 --- p0
    c1["02 · Java 9 ~ 16 重要特性"]
    R --> c1
    p1("・var 局部類型推斷<br>・Text Block（文字塊）<br>・Switch 表達式")
    c1 --- p1
    c2["03 · Java 17 LTS 重點"]
    R --> c2
    p2("・Sealed Classes（封閉類）<br>・Pattern Matching for instanceof<br>・Record Classes（記錄類）")
    c2 --- p2
    c3["04 · Java 21 LTS 重點 ⭐ 最重要"]
    R --> c3
    p3("・Virtual Threads（虛擬線程）← 革命性<br>・Pattern Matching for Switch<br>・Sequenced Collections<br>・Structured Concurrency")
    c3 --- p3
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3 chapter
    class p0,p1,p2,p3 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · Java 8 核心回顧](java8.md)__

    ---

    Java 8 引入的 Lambda、Stream 與 Optional 至今仍是日常開發的基礎。

-   __[02 · Java 9 ~ 16 重要特性](java9-16.md)__

    ---

    Java 9 到 16 之間累積了許多實用的小改進。

-   __[03 · Java 17 LTS 重點](java17.md)__

    ---

    Java 17 是繼 Java 11 之後的 LTS 版本。

-   __[04 · Java 21 LTS 重點](java21.md)__

    ---

    Java 21 LTS 最重要的特性是虛擬執行緒，讓同步寫法也能撐住大量並發。

-   __[05 · 版本對比速查表](version-comparison.md)__

    ---

    一張表整理 Java 8 到 21 各版本的重點特性與 LTS 版本，方便快速查詢與決定升級路線。

-   __[06 · 實戰整合範例](practice.md)__

    ---

    本章把 Record、Sealed Class、模式匹配與虛擬執行緒組合在同一個情境中，示範新特性在實際專案裡如何互相搭配。

</div>

## 重點速覽

### 版本特性速查

| 特性 | 版本 | 核心價值 |
|------|------|---------|
| **Lambda / Stream** | Java 8 | 函數式編程，簡化集合操作 |
| **Optional** | Java 8 | 消滅 NullPointerException |
| **var** | Java 10 | 局部類型推斷，減少重複代碼 |
| **Text Block** | Java 15 | 多行字串，SQL / JSON 更易讀 |
| **Switch 表達式** | Java 14 | 箭頭語法，消滅 break 和 fall-through |
| **Record** | Java 16 | 一行定義不可變 DTO，自動生成 getter / equals / toString |
| **Sealed Class** | Java 17 | 限制繼承，配合 Pattern Matching 實現型別安全 |
| **Pattern Matching** | Java 17/21 | 判斷與轉換合而為一，消滅強轉樣板 |
| **Virtual Threads** | Java 21 ⭐ | 百萬並發，IO 密集型應用效能革命 |
| **Structured Concurrency** | Java 21 | 子任務跟著 Scope 走，生命週期管理更安全 |

### Virtual Threads 核心原理

| 執行緒類型 | 對應關係 | 成本 |
|-----------|---------|------|
| 傳統平台執行緒 | Java Thread **1 : 1** OS Thread | 每條約 1MB 堆疊，數千條就是上限 |
| 虛擬執行緒 | Virtual Thread **M : N** Carrier Thread（＝ CPU 核心數） | 極輕量，可以建立上百萬條 |

| 時機 | 虛擬執行緒的行為 |
|------|----------------|
| 等待 I/O 時 | 自動卸載，讓出 Carrier Thread 去執行其他虛擬執行緒 |
| I/O 完成時 | 重新掛載到任一 Carrier Thread 繼續執行 |

Spring Boot 3.2 開啟：`spring.threads.virtual.enabled: true`

## 核心要點總結

| 特性 | 核心價值 | 記憶口訣 |
|------|---------|---------|
| **Record** | 消滅 POJO 樣板程式碼 | 一行定義不可變 DTO |
| **Sealed Class** | 限制繼承，型別安全 | 告訴編譯器「只有這幾種」|
| **Pattern Matching** | 消滅強轉樣板 | 判斷同時完成轉換 |
| **Text Block** | 多行字串更易讀 | 三個引號包住 |
| **Switch 表達式** | 消滅 break 和 fall-through | 箭頭 → 返回值 |
| **Virtual Threads** | IO 密集型應用效能革命 | 幾KB vs 1MB，百萬並發 |
| **Sequenced Collections** | 統一首尾操作 API | getFirst/getLast 通用 |
| **Structured Concurrency** | 並發任務生命週期管理 | 子任務跟著 scope 走 |
