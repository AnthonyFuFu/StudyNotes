# JVM 整體架構

``` mermaid
flowchart TB
    CLS[/".class 文件"/] --> CL["類加載子系統 ClassLoader<br>載入 → 驗證 → 準備 → 解析 → 初始化"]
    CL --> RDA
    subgraph RDA ["運行時數據區（記憶體模型）"]
        direction TB
        subgraph PRIV ["線程私有"]
            direction LR
            PC["程序計數器<br>PC"]
            VMS["虛擬機棧<br>Stack"]
            NMS["本地方法棧<br>Native Stack"]
        end
        subgraph SHARED ["線程共享"]
            direction LR
            subgraph HEAP ["堆 Heap"]
                direction LR
                YG["新生代<br>Eden / S0 / S1"]
                OG["老年代<br>Old Gen"]
            end
            MS["方法區 / Metaspace<br>類資訊、常量池、靜態變數、JIT 代碼"]
        end
    end
    RDA --> EE
    subgraph EE ["執行引擎"]
        direction LR
        INT["直譯器"]
        JIT["JIT 編譯器"]
        GC["GC"]
    end
    EE <--> NML[("本地方法庫<br>Native Method Library")]
```
