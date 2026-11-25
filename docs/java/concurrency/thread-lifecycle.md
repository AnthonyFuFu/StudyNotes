# Thread 生命週期與狀態轉換

!!! abstract "本章重點"

    理解執行緒的六種狀態與轉換條件，是閱讀執行緒傾印（thread dump）與排查死鎖的基礎。本章同時說明如何用中斷機制正確地停止一條執行緒。

## 六種狀態

| 狀態 | 意義 |
|------|------|
| `NEW` | 剛建立，還沒 `start()` |
| `RUNNABLE` | 運行中或等待 CPU 調度 |
| `BLOCKED` | 等待 synchronized 鎖 |
| `WAITING` | 無限期等待（`wait()` / `join()` / `park()`） |
| `TIMED_WAITING` | 有限期等待（`sleep()` / `wait(ms)` / `join(ms)`） |
| `TERMINATED` | 執行完畢 |

**狀態轉換圖**

``` mermaid
stateDiagram-v2
    [*] --> NEW
    NEW --> RUNNABLE: start()
    RUNNABLE --> BLOCKED: synchronized 鎖被占
    BLOCKED --> RUNNABLE: 搶到鎖
    RUNNABLE --> WAITING: wait() / join() / park()
    WAITING --> RUNNABLE: notify() / notifyAll() / unpark()
    RUNNABLE --> TIMED_WAITING: sleep(ms) / wait(ms)
    TIMED_WAITING --> RUNNABLE: 超時或喚醒
    RUNNABLE --> TERMINATED: run() 執行完畢
    TERMINATED --> [*]
```

```java
// 查看線程狀態
Thread t = new Thread(() -> {
    try { Thread.sleep(1000); } catch (InterruptedException e) {}
});

System.out.println(t.getState()); // NEW

t.start();
System.out.println(t.getState()); // RUNNABLE 或 TIMED_WAITING

t.join();
System.out.println(t.getState()); // TERMINATED
```

## 中斷機制（Interruption）

```java
// ❌ 不能強制停止線程（stop() 已廢棄）
// ✅ 使用中斷機制（協作式）

Thread worker = new Thread(() -> {
    while (!Thread.currentThread().isInterrupted()) {
        // 業務邏輯
        System.out.println("工作中...");
    }
    System.out.println("線程正常結束");
});

worker.start();
Thread.sleep(100);
worker.interrupt(); // 設定中斷標誌

// 處理 InterruptedException
Thread t = new Thread(() -> {
    try {
        Thread.sleep(10000); // TIMED_WAITING
    } catch (InterruptedException e) {
        // sleep 被中斷 → 清除中斷標誌並拋出異常
        // ⚠️ 這裡要決定：恢復中斷標誌 or 直接結束
        Thread.currentThread().interrupt(); // 恢復中斷標誌（推薦）
        System.out.println("被中斷，結束執行");
    }
});
```
