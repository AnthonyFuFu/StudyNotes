# synchronized 底層原理

## Monitor 物件鎖

```
每個 Java 物件都有一個 Monitor（監視器鎖）
Monitor 由 C++ 的 ObjectMonitor 實作

ObjectMonitor 結構：
┌─────────────────────────────────────────┐
│             ObjectMonitor               │
│                                         │
│  _owner      → 當前持有鎖的線程          │
│  _count      → 重入次數（ReentrantLock） │
│  _EntryList  → 等待鎖的線程佇列（BLOCKED）│
│  _WaitSet    → 呼叫 wait() 的線程集合    │
└─────────────────────────────────────────┘

synchronized 運作流程：

線程 A 嘗試進入 synchronized：
  ① 查看 _owner 是否為 null
  ② 為 null → 設定 _owner = 線程 A，_count = 1 → 進入
  ③ 不為 null 且是自己 → _count++ → 重入（可重入鎖）
  ④ 不為 null 且是別人 → 進入 _EntryList 等待

線程 A 呼叫 wait()：
  ① _count-- 直到為 0 → 釋放鎖（_owner = null）
  ② 線程 A 進入 _WaitSet

呼叫 notify()：
  ① 從 _WaitSet 取出一個線程 → 移到 _EntryList
  ② 等待重新競爭鎖

位元組碼層面：
  monitorenter → 進入 synchronized
  monitorexit  → 離開 synchronized（正常 + 異常都有）
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

```
背景：重量級鎖需要作業系統介入（核心態切換），代價極高
JDK 6 引入鎖升級，根據競爭情況自動升級

物件頭（Object Header）Mark Word（64bit）：

鎖狀態      │ 存儲內容
────────────┼─────────────────────────────────
無鎖        │ hashCode(25) │ age(4) │ 01
偏向鎖      │ threadId(54) │ 01
輕量級鎖    │ 指向棧幀的指針(62) │ 00
重量級鎖    │ 指向 Monitor 的指針(62) │ 10
GC 標記     │ 11

升級流程：

無鎖
  │ 第一個線程進入 synchronized
  ↓
偏向鎖（Biased Lock）
  記錄線程 ID 在 Mark Word
  之後同一個線程進入 → 直接進，不需要 CAS！
  適合：只有一個線程的場景
  │ 其他線程嘗試競爭
  ↓
輕量級鎖（Lightweight Lock）
  CAS 方式嘗試獲取鎖（自旋）
  在線程的棧幀建立 Lock Record，CAS 將 Mark Word 改為指向 Lock Record
  適合：競爭少，線程交替執行（不同時）
  │ 自旋超過次數（預設 10 次，JDK 6 後自適應）
  ↓
重量級鎖（Heavyweight Lock）
  進入核心態，真正的 Monitor 鎖
  未獲得鎖的線程阻塞（不消耗 CPU）
  適合：高競爭、長臨界區

⚠️ 鎖只能升級，不能降級（偏向鎖可以撤銷）
```
