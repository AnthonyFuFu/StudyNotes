---
icon: lucide/cpu
---

# JVM 深度原理

理解 JVM 如何載入類別、配置記憶體、回收垃圾，以及如何用工具定位線上效能問題。

**核心技術**：記憶體模型 / GC / 類加載 / JMM / 性能調優

## 學習地圖

``` mermaid
mindmap
  root((JVM 深度原理))
    JVM 整體架構
    記憶體模型（Runtime Data Areas）
      程序計數器
      虛擬機棧
      本地方法棧
      堆（Heap）
      方法區 / Metaspace
    類加載機制
      類加載流程（7步驟）
      雙親委派模型
      打破雙親委派
    GC 垃圾回收
      如何判斷對象死亡
      四大垃圾回收算法
      分代收集理論
      六大 GC 收集器
    Java 記憶體模型（JMM）
      happens-before 原則
      volatile 底層原理
      三大問題：原子性、可見性、有序性
    JVM 性能調優
      常用 JVM 參數
      GC Log 分析
      OOM 排查流程
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · JVM 整體架構](architecture.md)__

    ---

    JVM 整體架構

-   __[02 · 記憶體模型](memory-areas.md)__

    ---

    程序計數器 · 虛擬機棧 · 堆（Heap）⭐ 最重要 · 方法區 / Metaspace

-   __[03 · 類加載機制](class-loading.md)__

    ---

    類加載的完整流程 · 雙親委派模型

-   __[04 · GC 垃圾回收](gc.md)__

    ---

    如何判斷對象死亡 · 四大垃圾回收算法 · 六大 GC 收集器

-   __[05 · Java 記憶體模型](jmm.md)__

    ---

    JMM 核心概念 · 三大問題：原子性、可見性、有序性 · volatile 底層原理 · happens-before 原則

-   __[06 · JVM 性能調優](tuning.md)__

    ---

    常用 JVM 參數速查表 · GC Log 分析 · OOM 排查完整流程

</div>

## 重點速覽

### 記憶體模型架構
``` mermaid
flowchart TB
    subgraph JVM ["JVM 記憶體"]
        direction TB
        subgraph PRIV ["線程私有"]
            direction LR
            PC["程序計數器"]
            VMS["虛擬機棧"]
            NMS["本地方法棧"]
        end
        subgraph HEAP ["堆 Heap（線程共享）"]
            direction LR
            YG["新生代 1/3<br>Eden : S0 : S1 = 8 : 1 : 1"]
            OG["老年代 2/3"]
        end
        MS["方法區 / Metaspace<br>類資訊 / 常量池 / 靜態變數 / JIT 緩存"]
    end
```

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
