# AQS 底層原理

## AQS 架構

```
AQS（AbstractQueuedSynchronizer）是 Java 並發的骨幹！

基於 AQS 實作的類：
  ReentrantLock
  ReentrantReadWriteLock
  Semaphore
  CountDownLatch
  CyclicBarrier

AQS 核心：
  state    - int 型的同步狀態（volatile）
  CLH 佇列 - 雙向鏈表，存放等待線程的 Node

獨佔模式（ReentrantLock）：
  state = 0  → 未鎖定
  state = 1  → 已鎖定
  state = N  → 重入 N 次

共享模式（Semaphore / CountDownLatch）：
  state = N  → 允許 N 個線程同時訪問
```

**CLH 佇列（等待佇列）**

``` mermaid
flowchart LR
    H["Head<br>虛節點"] --> N1["Node（T1）<br>RUNNING"] --> N2["Node（T2）<br>WAITING"] --> N3["Node（T3）<br>WAITING"] --> NULL(["null"])
```

=== "獲取鎖流程"

    ``` mermaid
    flowchart TB
        A["① CAS 修改 state<br>tryAcquire"] -->|成功| B["② exclusiveOwnerThread = 當前線程"]
        A -->|失敗| C["③ CAS 加入 CLH 佇列尾部"]
        C --> D{"④ 前驅節點是 Head？"}
        D -->|是| A2["再次嘗試獲取"]
        A2 -->|成功| B
        A2 -->|失敗| E["⑤ LockSupport.park()<br>阻塞自己"]
        D -->|否| E
    ```

=== "釋放鎖流程"

    ``` mermaid
    flowchart LR
        R1["① tryRelease<br>state-- 直到為 0"] --> R2["② unparkSuccessor<br>喚醒第一個等待線程"] --> R3["③ 被喚醒的線程<br>再次嘗試獲取鎖"]
    ```

```java
// 自定義鎖（理解 AQS 用）
public class SimpleLock extends AbstractQueuedSynchronizer {

    // 嘗試獲取鎖（獨佔模式）
    @Override
    protected boolean tryAcquire(int acquires) {
        // CAS 將 state 從 0 改為 1
        if (compareAndSetState(0, 1)) {
            setExclusiveOwnerThread(Thread.currentThread());
            return true;
        }
        return false;
    }

    // 嘗試釋放鎖
    @Override
    protected boolean tryRelease(int releases) {
        if (getState() == 0) {
            throw new IllegalMonitorStateException();
        }
        setExclusiveOwnerThread(null);
        setState(0);
        return true;
    }

    public void lock()   { acquire(1); }
    public void unlock() { release(1); }
}
```
