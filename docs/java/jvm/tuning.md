# JVM 性能調優

!!! abstract "本章重點"

    JVM 調優的前提是先看懂數據。本章整理常用的 JVM 參數、如何解讀 GC Log，以及從發現 OOM 到定位原因的完整排查流程與工具。

## 常用 JVM 參數速查表

```bash
# ===== 堆記憶體設定 =====
-Xms2g                    # 堆初始大小（生產環境建議與 Xmx 相同，避免動態擴容）
-Xmx2g                    # 堆最大大小
-Xmn512m                  # 新生代大小（G1 不需要設定）
-XX:MetaspaceSize=256m    # Metaspace 初始大小
-XX:MaxMetaspaceSize=512m # Metaspace 最大大小

# ===== 棧設定 =====
-Xss512k                  # 每個線程的棧大小（預設 512k~1m）

# ===== GC 選擇 =====
-XX:+UseG1GC              # 使用 G1（Java 9+ 預設）
-XX:+UseZGC               # 使用 ZGC（超低延遲）
-XX:+UseParallelGC        # 使用 Parallel（吞吐量優先）

# ===== G1 調優 =====
-XX:MaxGCPauseMillis=200  # GC 最大停頓目標
-XX:G1HeapRegionSize=16m  # Region 大小

# ===== GC 日誌（Java 9+ 新格式）=====
-Xlog:gc*:file=/logs/gc.log:time,level,tags:filecount=10,filesize=100m

# ===== 診斷 =====
-XX:+HeapDumpOnOutOfMemoryError         # OOM 時自動 dump
-XX:HeapDumpPath=/logs/heapdump.hprof   # dump 文件路徑

# ===== JIT 編譯 =====
-XX:+TieredCompilation                  # 分層編譯（預設開啟）
-XX:CompileThreshold=10000              # 方法調用多少次後 JIT 編譯
```

## GC Log 分析

```bash
# Java 11+ GC 日誌格式（-Xlog:gc*）：

[2.457s][info][gc,start] GC(0) Pause Young (Normal) (G1 Evacuation Pause)
[2.461s][info][gc      ] GC(0) Pause Young (Normal) (G1 Evacuation Pause)
                                 200M->10M(512M) 4.123ms
                                 ↑      ↑   ↑      ↑
                              回收前  回收後  堆大小  停頓時間

# 關鍵指標解讀：
# Young GC 停頓 > 100ms  → 新生代太小，需要調大
# Full GC 頻繁           → 老年代太小 或 記憶體洩漏
# Humongous 對象多        → 大對象頻繁分配，需調整 Region 大小
```

## OOM 排查完整流程

**OOM 類型診斷**

- 1\. java.lang.OutOfMemoryError: Java heap space
    - → 堆記憶體不足

- 2\. java.lang.OutOfMemoryError: GC overhead limit exceeded
    - → GC 時間佔比超過 98%，但回收不到 2%

- 3\. java.lang.OutOfMemoryError: Metaspace
    - → 方法區不足（類太多、動態生成類）

- 4\. java.lang.OutOfMemoryError: Direct buffer memory
    - → NIO 直接記憶體不足（Netty、NIO 框架）

- 5\. java.lang.StackOverflowError
    - → 棧溢出（遞迴過深）

- 6\. java.lang.OutOfMemoryError: unable to create new native thread
    - → 線程數超過 OS 限制

```bash
# 排查工具

# 1. jps - 列出 JVM 進程
jps -l
# 輸出：12345 com.example.Application

# 2. jmap - 記憶體分析
jmap -heap 12345                                    # 查看堆使用情況
jmap -dump:format=b,file=heapdump.hprof 12345       # 生成 heap dump
jmap -histo 12345 | head -20                        # 查看對象統計 Top 20

# 3. jstack - 線程分析
jstack 12345 > thread_dump.txt
grep -A 5 "BLOCKED" thread_dump.txt                 # 查找 BLOCKED 線程（死鎖）

# 4. jstat - GC 統計（每 1000ms 打印一次，共 10 次）
jstat -gcutil 12345 1000 10
# 輸出：
# S0     S1    E      O      M     CCS   YGC   YGCT  FGC   FGCT  GCT
# 0.00  98.55  89.45  23.18  96.50  91.38  15    0.234  0    0.000  0.234
# ↑S0   ↑S1   ↑Eden  ↑Old   ↑Meta  ↑Class ↑Young次數  ↑Full次數

# 5. jinfo - 查看 JVM 參數
jinfo -flags 12345
```

```java
// 常見記憶體洩漏場景：

// ❌ 1. 靜態集合持有大量對象（永遠不清理）
public class CacheManager {
    private static Map<String, Object> cache = new HashMap<>();

    public void add(String key, Object value) {
        cache.put(key, value); // 不斷累積，永不回收
    }
}

// ✅ 修復：使用弱引用或設定最大大小
private static Map<String, Object> cache = new WeakHashMap<>();
// 或使用 Caffeine 緩存（有大小限制）

// ❌ 2. 未關閉的資源
public void badCode() throws Exception {
    InputStream is = new FileInputStream("file.txt");
    // 忘記 close()！
}

// ✅ 修復：try-with-resources
public void goodCode() throws Exception {
    try (InputStream is = new FileInputStream("file.txt")) {
        // 自動關閉
    }
}

// ❌ 3. 非靜態內部類持有外部類引用
public class Outer {
    private byte[] bigData = new byte[1024 * 1024]; // 1MB

    // 非靜態內部類，隱式持有 Outer 的引用！
    class Inner {
        void doSomething() {}
    }
}

// ✅ 修復：改為靜態內部類
static class Inner { ... }
```

### OOM 排查實戰案例：

案例：電商系統 Full GC 頻繁，每隔 30 分鐘一次

**症狀**

- Full GC 停頓 3\~5 秒
- GC 後老年代記憶體沒有明顯下降

**排查過程**

Step 1：觀察 GC 情況

- jstat -gcutil &lt;pid> 5000
- 發現：Old 區使用率緩慢上升，最終觸發 Full GC

Step 2：生成 Heap Dump

- jmap -dump:format=b,file=heap.hprof &lt;pid>

Step 3：MAT 分析

- 發現：一個 HashMap 持有大量 Session 對象（每個 1KB）
- 總計：50 萬個 Session 對象，500MB！

Step 4：定位程式碼

- 發現：Session 管理器使用靜態 HashMap 儲存 Session
- 但 Session 過期後只是標記 expired=true，沒有從 Map 中移除！

Step 5：修復

**改用 Caffeine Cache（有過期自動移除）**

- Cache&lt;String, Session> sessionCache = Caffeine.newBuilder()
    - .expireAfterAccess(30, TimeUnit.MINUTES)
    - .maximumSize(100_000)
    - .build();

Step 6：效果

- Full GC 消失，老年代穩定在 30% 以下
