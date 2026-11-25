---
icon: lucide/cpu
---

# JVM 深度原理

理解 JVM 如何載入類別、配置記憶體、回收垃圾，以及如何用工具定位線上效能問題。

**核心技術**：記憶體模型 / GC / 類加載 / JMM / 性能調優

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["JVM 深度原理"])
    c0["01 · JVM 整體架構"]
    R --> c0
    c1["02 · 記憶體模型（Runtime Data Areas）"]
    R --> c1
    p1("・程序計數器<br>・虛擬機棧<br>・本地方法棧<br>・堆（Heap）<br>・方法區 / Metaspace")
    c1 --- p1
    c2["03 · 類加載機制"]
    R --> c2
    p2("・類加載流程（7步驟）<br>・雙親委派模型<br>・打破雙親委派")
    c2 --- p2
    c3["04 · GC 垃圾回收"]
    R --> c3
    p3("・如何判斷對象死亡<br>・四大垃圾回收算法<br>・分代收集理論<br>・六大 GC 收集器")
    c3 --- p3
    c4["05 · Java 記憶體模型（JMM）"]
    R --> c4
    p4("・happens-before 原則<br>・volatile 底層原理<br>・三大問題：原子性、可見性、有序性")
    c4 --- p4
    c5["06 · JVM 性能調優"]
    R --> c5
    p5("・常用 JVM 參數<br>・GC Log 分析<br>・OOM 排查流程")
    c5 --- p5
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5 chapter
    class p1,p2,p3,p4,p5 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · JVM 整體架構](architecture.md)__

    ---

    本章用一張圖說明 JVM 的整體架構：類加載子系統把 `.class` 載入記憶體，執行引擎負責執行與垃圾回收，後續章節會逐一深入每個部分。

-   __[02 · 記憶體模型](memory-areas.md)__

    ---

    JVM 在執行時把記憶體劃分成不同區域，各自有不同的生命週期與 OOM 風險。

-   __[03 · 類加載機制](class-loading.md)__

    ---

    類別從 `.class` 檔變成可以使用的物件，要經過載入、連接、初始化等步驟。

-   __[04 · GC 垃圾回收](gc.md)__

    ---

    GC 決定了 Java 應用的停頓時間與吞吐量。

-   __[05 · Java 記憶體模型](jmm.md)__

    ---

    多核 CPU 下，每條執行緒看到的變數值可能不同。

-   __[06 · JVM 性能調優](tuning.md)__

    ---

    JVM 調優的前提是先看懂數據。

</div>

## 重點速覽

### 記憶體模型架構
``` mermaid
block-beta
    columns 3
    t["JVM 記憶體"]:3
    pc["程序計數器<br>線程私有"] vms["虛擬機棧<br>線程私有"] nms["本地方法棧<br>線程私有"]
    yg["新生代 1/3<br>Eden : S0 : S1 = 8 : 1 : 1"]:1 og["老年代 2/3"]:2
    ms["方法區 / Metaspace<br>類資訊 / 常量池 / 靜態變數 / JIT 緩存"]:3
    classDef title fill:transparent,stroke:transparent,font-weight:bold
    class t title
```

中間一列為 **堆 Heap**（線程共享）。

### GC 收集器對比

| 收集器 | 最大停頓 | 適用場景 | JVM 參數 |
|--------|---------|---------|---------|
| Serial | 幾百ms\~幾秒 | 小型應用 | `-XX:+UseSerialGC` |
| Parallel | 幾百ms | 後台批次 | `-XX:+UseParallelGC` |
| **G1** | < 200ms | 大多數應用（預設）| `-XX:+UseG1GC` |
| **ZGC** | < 10ms | 超低延遲系統 | `-XX:+UseZGC` |

### 掌握重點
- ✅ **類加載機制**：七步驟（載入→驗證→準備→解析→初始化→使用→卸載）
- ✅ **雙親委派**：安全性保護，可打破（SPI / Tomcat / OSGi）
- ✅ **MVCC 等效**：可達性分析 + 四種引用（強 > 軟 > 弱 > 虛）
- ✅ **JMM 三大問題**：原子性 / 可見性 / 有序性
- ✅ **volatile 原理**：記憶體屏障 + MESI 緩存一致性協議
- ✅ **happens-before**：8 大規則，多線程可見性的核心保證

## 核心要點總結

| 模組 | 核心要點 |
|------|---------|
| **記憶體模型** | 堆（新生代+老年代）/ 棧（線程私有）/ 方法區（Metaspace）|
| **堆結構** | Eden:S0:S1=8:1:1，新生代:老年代=1:2 |
| **類加載** | 載入→驗證→準備→解析→初始化，雙親委派保證安全 |
| **GC 判斷** | 可達性分析（GC Roots），4 種引用強弱 |
| **GC 算法** | 複製（新生代）/ 標記整理（老年代）|
| **GC 收集器** | G1（預設）/ ZGC（超低延遲）|
| **JMM** | 主記憶體 + 工作記憶體，三大問題：原子性/可見性/有序性 |
| **volatile** | 記憶體屏障 + MESI，保證可見性和有序性，不保證原子性 |
| **happens-before** | 8 大規則，保證多線程可見性的核心 |
| **調優** | jmap/jstat/jstack 三件套，Heap Dump 分析 MAT |
