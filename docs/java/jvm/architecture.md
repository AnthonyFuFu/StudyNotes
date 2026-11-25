# JVM 整體架構

!!! abstract "本章重點"

    本章用一張圖說明 JVM 的整體架構：類加載子系統把 `.class` 載入記憶體，執行引擎負責執行與垃圾回收，後續章節會逐一深入每個部分。

``` mermaid
flowchart TB
    CLS[/".class 文件"/] --> CL["類加載子系統 ClassLoader<br>載入 → 驗證 → 準備 → 解析 → 初始化"]
    CL --> RDA
    subgraph RDA ["運行時數據區（記憶體模型）"]
        direction TB
        subgraph PRIV ["線程私有"]
            direction LR
            PC["程序計數器 PC"] ~~~ VMS["虛擬機棧 Stack"] ~~~ NMS["本地方法棧"]
        end
        subgraph SHARED ["線程共享"]
            direction LR
            HEAP["堆 Heap<br>新生代 Eden / S0 / S1 ・ 老年代"] ~~~ MS["方法區 / Metaspace<br>類資訊、常量池、靜態變數、JIT 代碼"]
        end
        PRIV ~~~ SHARED
    end
    RDA --> EE
    subgraph EE ["執行引擎"]
        direction LR
        INT["直譯器"] ~~~ JIT["JIT 編譯器"] ~~~ GC["GC"]
    end
    EE <--> NML[("本地方法庫 Native Method Library")]
```
