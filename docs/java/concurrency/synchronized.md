# synchronized 底層原理

!!! abstract "本章重點"

    synchronized 是 Java 最基本的同步機制。本章說明它背後的 Monitor 物件鎖運作方式，以及 JDK 6 之後由偏向鎖、輕量級鎖到重量級鎖的鎖升級機制。

## Monitor 物件鎖

每個 Java 物件都有一個 Monitor（監視器鎖），由 C++ 的 `ObjectMonitor` 實作。

| ObjectMonitor 欄位 | 意義 |
|-------------------|------|
| `_owner` | 當前持有鎖的線程 |
| `_count` | 重入次數 |
| `_EntryList` | 等待鎖的線程佇列（BLOCKED） |
| `_WaitSet` | 呼叫 `wait()` 的線程集合 |

**synchronized 運作流程**

``` mermaid
flowchart TB
    IN(["線程嘗試進入 synchronized<br>monitorenter"]) --> Q{"_owner 是否為 null？"}
    Q -->|"是"| OWN["_owner = 當前線程<br>_count = 1 → 進入"]
    Q -->|"否，是自己"| RE["_count++<br>重入（可重入鎖）"]
    Q -->|"否，是別人"| EL["進入 _EntryList 等待<br>BLOCKED"]
    OWN -->|"wait()"| WS["_count 歸零釋放鎖<br>進入 _WaitSet"]
    WS -->|"notify()"| EL
    EL -->|"鎖釋放後重新競爭"| Q
    OWN -->|"monitorexit<br>正常 + 異常都有"| OUT(["離開 synchronized"])
```

```java
// synchronized 四種用法
public class SynchronizedDemo {

    private static final Object LOCK = new Object();

    // 1. 同步實例方法（鎖 this）
    public synchronized void instanceMethod() {
        // 鎖 = this 物件
    }

    // 2. 同步靜態方法（鎖 Class）
    public static synchronized void staticMethod() {
        // 鎖 = SynchronizedDemo.class
    }

    // 3. 同步程式碼區塊（鎖指定物件）
    public void blockMethod() {
        synchronized (LOCK) {
            // 鎖 = LOCK 物件（粒度更細，推薦）
        }
    }

    // 4. 同步 this（等同於方法一）
    public void thisMethod() {
        synchronized (this) { }
    }
}

// ⚠️ 死鎖範例（兩個線程互等對方的鎖）
Object lockA = new Object();
Object lockB = new Object();

Thread t1 = new Thread(() -> {
    synchronized (lockA) {
        Thread.sleep(100);
        synchronized (lockB) { } // 等待 lockB
    }
});

Thread t2 = new Thread(() -> {
    synchronized (lockB) {
        Thread.sleep(100);
        synchronized (lockA) { } // 等待 lockA
    }
});
// 死鎖！t1 等 lockB，t2 等 lockA，互等永遠

// 預防死鎖：固定加鎖順序
// 都先鎖 lockA 再鎖 lockB
```

## 鎖升級機制（JDK 6+ 優化）

**背景**：重量級鎖需要作業系統介入（核心態切換），代價極高。JDK 6 引入鎖升級，根據競爭情況自動升級。

**物件頭 Mark Word（64 bit）**

| 鎖狀態 | 存儲內容 | 標誌位 |
|--------|---------|-------|
| 無鎖 | hashCode(25) ・ age(4) | `01` |
| 偏向鎖 | threadId(54) | `01` |
| 輕量級鎖 | 指向棧幀的指針(62) | `00` |
| 重量級鎖 | 指向 Monitor 的指針(62) | `10` |
| GC 標記 | | `11` |

**升級流程**

``` mermaid
stateDiagram-v2
    NoLock: 無鎖
    Biased: 偏向鎖
    Light: 輕量級鎖
    Heavy: 重量級鎖
    NoLock --> Biased: 第一個線程進入
    Biased --> Light: 其他線程嘗試競爭
    Light --> Heavy: 自旋超過次數
```

| 階段 | 機制 | 適合場景 |
|------|------|---------|
| **偏向鎖**（Biased Lock） | 在 Mark Word 記錄線程 ID，同一個線程再次進入直接進，不需要 CAS | 只有一個線程 |
| **輕量級鎖**（Lightweight Lock） | 在棧幀建立 Lock Record，CAS 將 Mark Word 改為指向它（自旋） | 競爭少，線程交替執行 |
| **重量級鎖**（Heavyweight Lock） | 進入核心態，真正的 Monitor 鎖；未獲得鎖的線程阻塞（不消耗 CPU） | 高競爭、長臨界區 |

自旋次數預設 10 次，JDK 6 之後改為自適應。

!!! warning

    鎖只能升級，不能降級（偏向鎖可以撤銷）。
