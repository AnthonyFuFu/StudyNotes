# 鎖進階

## ReentrantLock

```java
// ReentrantLock vs synchronized 對比

// synchronized：
// ✅ 簡單易用
// ❌ 不能中斷等待
// ❌ 不能設定超時
// ❌ 只支援非公平鎖

// ReentrantLock：
// ✅ 可中斷等待
// ✅ 可設定超時
// ✅ 支援公平鎖 / 非公平鎖
// ✅ 可以綁定多個 Condition
// ❌ 需要手動 unlock()（必須在 finally！）

ReentrantLock lock = new ReentrantLock(true); // true = 公平鎖

// 標準使用方式
lock.lock();
try {
    // 臨界區
} finally {
    lock.unlock(); // ⚠️ 必須在 finally！
}

// 可中斷等待
try {
    lock.lockInterruptibly(); // 等待時可以被 interrupt() 中斷
    try {
        // 臨界區
    } finally {
        lock.unlock();
    }
} catch (InterruptedException e) {
    System.out.println("等待鎖被中斷");
}

// 超時等待
boolean acquired = lock.tryLock(3, TimeUnit.SECONDS);
if (acquired) {
    try {
        // 臨界區
    } finally {
        lock.unlock();
    }
} else {
    System.out.println("3 秒內未獲得鎖，放棄");
}

// Condition（類比 wait / notify，但更靈活）
ReentrantLock lock       = new ReentrantLock();
Condition      notEmpty  = lock.newCondition();
Condition      notFull   = lock.newCondition();

// 生產者
lock.lock();
try {
    while (queue.isFull()) {
        notFull.await(); // 等待「不滿」條件
    }
    queue.add(item);
    notEmpty.signal(); // 通知「不空」條件
} finally {
    lock.unlock();
}

// 消費者
lock.lock();
try {
    while (queue.isEmpty()) {
        notEmpty.await(); // 等待「不空」條件
    }
    item = queue.poll();
    notFull.signal(); // 通知「不滿」條件
} finally {
    lock.unlock();
}
```

## ReadWriteLock（讀寫鎖）

```java
// 場景：讀多寫少（如：緩存）
// 多個讀可以同時進行（讀讀不互斥）
// 寫的時候排他（讀寫互斥、寫寫互斥）

ReadWriteLock rwLock  = new ReentrantReadWriteLock();
Lock          readLock  = rwLock.readLock();
Lock          writeLock = rwLock.writeLock();

// 快取範例
private final Map<String, Object> cache   = new HashMap<>();
private final ReadWriteLock       rwLock2 = new ReentrantReadWriteLock();

public Object get(String key) {
    rwLock2.readLock().lock();
    try {
        return cache.get(key); // 多個線程可以同時讀
    } finally {
        rwLock2.readLock().unlock();
    }
}

public void put(String key, Object value) {
    rwLock2.writeLock().lock();
    try {
        cache.put(key, value); // 寫的時候排他
    } finally {
        rwLock2.writeLock().unlock();
    }
}

// ⚠️ 讀寫鎖的問題：寫鎖可能飢餓（一直有讀鎖，寫鎖永遠等不到）
// 解決：StampedLock（樂觀讀）
```

## StampedLock（JDK 8，效能最強）

```java
// StampedLock 特點：
// ✅ 樂觀讀（不加鎖，讀完驗證是否有寫入）
// ✅ 讀取效能比 ReadWriteLock 更高
// ❌ 不支援重入
// ❌ 不支援 Condition

StampedLock stampedLock = new StampedLock();
private double x, y;

// 樂觀讀（最快，不加鎖）
public double distanceFromOrigin() {
    long stamp = stampedLock.tryOptimisticRead(); // 獲取樂觀讀票據
    double cx = x, cy = y;                        // 讀取數據

    if (!stampedLock.validate(stamp)) {           // 驗證期間有沒有寫入
        // 有寫入 → 升級為悲觀讀鎖
        stamp = stampedLock.readLock();
        try {
            cx = x;
            cy = y;
        } finally {
            stampedLock.unlockRead(stamp);
        }
    }
    return Math.sqrt(cx * cx + cy * cy);
}

// 寫鎖
public void move(double deltaX, double deltaY) {
    long stamp = stampedLock.writeLock();
    try {
        x += deltaX;
        y += deltaY;
    } finally {
        stampedLock.unlockWrite(stamp);
    }
}
```
