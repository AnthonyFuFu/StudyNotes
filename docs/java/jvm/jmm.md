# Java 記憶體模型（JMM）

## JMM 核心概念

**問題**：多核 CPU 下，每個核心都有自己的快取（L1 / L2 Cache），多個線程讀寫同一個變數時，可能看到不一樣的值。

- **主記憶體（Main Memory）**：所有線程共享，存放所有變數
- **工作記憶體（Working Memory）**：每個線程私有的快取

``` mermaid
flowchart TB
    MM[("主記憶體（共享）<br>int x = 0　boolean flag = false")]
    A["線程 A 的工作記憶體<br>x = 0（副本）"]
    B["線程 B 的工作記憶體<br>x = 0（副本）"]
    MM <-- "read / load" --> A
    MM <-- "read / load" --> B
```

``` mermaid
sequenceDiagram
    participant A as 線程 A
    participant M as 主記憶體
    participant B as 線程 B
    A->>A: 工作記憶體改為 x = 1
    A--)M: 寫回主記憶體（不一定立即！）
    B->>B: 讀取自己工作記憶體的舊副本
    Note over B: 看到的還是 x = 0<br>→ 可見性問題
```

## 三大問題：原子性、可見性、有序性

```java
// 1. 原子性問題
int count = 0;
// count++ 不是原子操作！分解為三步：
// ① 讀取 count（load）
// ② count + 1（add）
// ③ 寫回 count（store）
// 多線程並發 count++ 會發生數據丟失！

// 2. 可見性問題
boolean flag = false;
// 線程 A：flag = true; → 寫入工作記憶體，未同步到主記憶體
// 線程 B：while(!flag) {} → 一直讀取工作記憶體的 flag = false → 死循環！

// 3. 有序性問題（指令重排序）
// 例：double-checked locking（DCL）的問題
public class Singleton {
    private static Singleton instance;

    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                    // new Singleton() 分解為三步：
                    // ① 分配記憶體空間
                    // ② 初始化對象
                    // ③ instance 指向記憶體地址
                    // 指令重排後可能是 ① → ③ → ②
                    // 另一個線程看到 instance != null，但對象還沒初始化完！
                }
            }
        }
        return instance;
    }
}
```

## volatile 底層原理

```java
// ✅ 加 volatile 解決可見性和有序性（但不保證原子性！）
public class Singleton {
    private static volatile Singleton instance; // ← volatile 關鍵字

    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton(); // ✅ volatile 禁止重排序
                }
            }
        }
        return instance;
    }
}
```

**volatile 底層原理（兩個機制）**

機制 1：記憶體屏障（Memory Barrier）

- 在 volatile 寫操作後插入 StoreStore + StoreLoad 屏障
- 在 volatile 讀操作前插入 LoadLoad + LoadStore 屏障
- → 禁止指令重排序！

機制 2：MESI 緩存一致性協議

- volatile 變數寫入時，強制刷新到主記憶體
- 其他 CPU 核心的快取行標記為無效
- → 其他線程讀取時，必須從主記憶體重新載入

**volatile 能做什麼**

- ✅ 保證可見性（修改後立即對其他線程可見）
- ✅ 保證有序性（禁止指令重排序）
- ❌ 不保證原子性！（count++ 仍然不安全）

```java
// volatile 的正確使用場景：

// ✅ 場景1：狀態標誌（單寫多讀）
public class Server {
    private volatile boolean running = true;

    public void stop() {
        running = false; // 一個線程寫
    }

    public void run() {
        while (running) { // 其他線程讀
            // 處理請求...
        }
    }
}

// ✅ 場景2：雙重檢查鎖定（DCL）
private static volatile Singleton instance;

// ❌ 不適合的場景：複合操作（需要 Atomic 類或 synchronized）
volatile int count = 0;
count++; // ❌ 不安全！需要 AtomicInteger.incrementAndGet()
```

## happens-before 原則

happens-before 是 JMM 保證可見性和有序性的核心規則！

定義：如果操作 A happens-before 操作 B，

- 則 A 的結果對 B 可見，且 A 在 B 之前執行

**Java 中的 8 條 happens-before 規則**

- 1\. 程序順序規則（Program Order Rule）
    - 同一個線程中，按代碼順序，前面的操作 HB 後面的操作

- 2\. 監視器鎖規則（Monitor Lock Rule）
    - unlock 操作 HB 後續的 lock 操作
    - synchronized 解鎖後，其他線程加鎖能看到解鎖前的修改

- 3\. volatile 規則（Volatile Variable Rule）
    - volatile 寫 HB 後續對該變數的 volatile 讀

- 4\. 線程啟動規則（Thread Start Rule）
    - Thread.start() HB 新線程的任何操作

- 5\. 線程終止規則（Thread Termination Rule）
    - 線程的任何操作 HB Thread.join() 返回

- 6\. 線程中斷規則（Thread Interruption Rule）
    - Thread.interrupt() HB 被中斷線程檢測到中斷

- 7\. 對象終結規則（Finalizer Rule）
    - 對象初始化 HB finalize() 方法

- 8\. 傳遞性規則（Transitivity）
    - A HB B，B HB C → A HB C

```java
// happens-before 實際範例
public class HappensBeforeDemo {
    private int value = 0;
    private volatile boolean ready = false;

    // 線程 A
    public void writer() {
        value = 42;      // 操作①
        ready = true;    // 操作②（volatile 寫）
    }

    // 線程 B
    public void reader() {
        if (ready) {                         // 操作③（volatile 讀）
            System.out.println(value);       // 操作④
        }
    }

    // 分析：
    // ① HB ②（程序順序規則）
    // ② HB ③（volatile 規則）
    // ③ HB ④（程序順序規則）
    // 傳遞性：① HB ④
    // ✅ 線程 B 讀到 ready=true 時，一定能看到 value=42！
}
```
