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

```
CLH 佇列（等待佇列）：

Head（虛節點）→ Node(T1) → Node(T2) → Node(T3) → null
                 │             │             │
              RUNNING      WAITING        WAITING

獲取鎖流程：
① 嘗試 CAS 修改 state（tryAcquire）
② 成功 → 設定 exclusiveOwnerThread = 當前線程
③ 失敗 → 加入 CLH 佇列尾部（CAS 方式，線程安全）
④ 前驅節點是 Head → 再次嘗試獲取（公平鎖機制）
⑤ 還是失敗 → LockSupport.park() 阻塞自己

釋放鎖流程：
① tryRelease：state-- 直到為 0
② unparkSuccessor：喚醒 CLH 佇列中的第一個等待線程
③ 被喚醒的線程再次嘗試獲取鎖
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
