# volatile 原理

## 兩大保證

```
volatile 保證：
  ① 可見性：一個線程修改，其他線程立即可見
  ② 有序性：禁止指令重排序（保證 happens-before）

volatile 不保證：
  ❌ 原子性（i++ 非原子操作）
```

```java
// ❌ 沒有 volatile，可能出現可見性問題
private boolean running = true;

Thread worker = new Thread(() -> {
    while (running) { // 線程可能讀取到緩存中的舊值，永遠不停！
    }
});

worker.start();
Thread.sleep(100);
running = false; // 主線程修改，worker 線程可能看不到！

// ✅ 加上 volatile
private volatile boolean running = true;
// 每次讀都從主記憶體讀，每次寫都立即刷新到主記憶體
```

## 記憶體屏障（Memory Barrier）

```
JMM（Java Memory Model）定義四種屏障：

LoadLoad   屏障：前面的 Load 先於後面的 Load
StoreStore 屏障：前面的 Store 先於後面的 Store
LoadStore  屏障：前面的 Load 先於後面的 Store
StoreLoad  屏障：前面的 Store 先於後面的 Load（最強）

volatile 寫的屏障：
  ... 普通操作
  [StoreStore 屏障]
  volatile 寫
  [StoreLoad 屏障]
  ... 後續操作

volatile 讀的屏障：
  ... 前面操作
  volatile 讀
  [LoadLoad 屏障]
  [LoadStore 屏障]
  ... 後續操作

效果：
  volatile 寫之前的所有操作 → 都在 volatile 寫之前完成
  volatile 讀之後的所有操作 → 都在 volatile 讀之後完成
  → 保證有序性！
```

```java
// 雙重檢查鎖定（DCL）為什麼需要 volatile？
public class Singleton {
    // ⚠️ 必須加 volatile！
    private static volatile Singleton instance;

    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                    // new 操作分三步：
                    // ① 分配記憶體
                    // ② 初始化物件
                    // ③ 將引用指向記憶體地址
                    // 沒有 volatile → JIT 可能重排為 ①③②
                    // 另一個線程看到 instance != null 但物件未初始化完成！
                }
            }
        }
        return instance;
    }
}
// volatile 的 StoreStore 屏障 → 防止 ②③ 重排序
```
