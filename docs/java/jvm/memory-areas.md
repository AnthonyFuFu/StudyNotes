# 記憶體模型（Runtime Data Areas）

## 程序計數器（Program Counter Register）

- ✅ 線程私有（每個線程一個）
- ✅ 唯一不會發生 OOM 的區域
- ✅ 大小固定，極小

**作用**：記錄當前線程正在執行的字節碼指令地址。

**為什麼需要？**

``` mermaid
sequenceDiagram
    participant CPU
    participant A as 線程 A
    participant B as 線程 B
    CPU->>A: 執行到第 15 行（PC = 15）
    Note over CPU: 時間片耗盡，切換
    CPU->>B: 執行到第 8 行（PC = 8）
    Note over CPU: 切換回線程 A
    CPU->>A: 從 PC = 15 繼續執行 ✅
```

如果沒有 PC，切換回來後就不知道要從哪裡繼續。執行 Native 方法時：PC = undefined（未定義）。

## 虛擬機棧（VM Stack）

- ✅ 線程私有（每個線程一個棧）
- ✅ 生命週期與線程相同
- ❗ 可能拋出 `StackOverflowError` / OOM

**結構**：每個方法調用對應一個「棧幀（Stack Frame）」。

``` mermaid
block-beta
    columns 1
    block:top
        columns 1
        f3["棧幀 3：method_c() ← 棧頂（當前執行）"]
        detail["局部變數表 ｜ 運算元棧 ｜ 動態連結 ｜ 方法返回地址"]
    end
    f2["棧幀 2：method_b()"]
    f1["棧幀 1：method_a() ← 棧底"]
```

### 棧幀內部詳解：

```java
public int calculate(int a, int b) {
    int sum = a + b;
    return sum * 2;
}
```

**棧幀結構**

| 區域 | 內容 |
|------|------|
| **局部變數表**<br>Local Variable Table | 索引 0：`this`（非靜態方法）<br>索引 1：`a = 10`<br>索引 2：`b = 20`<br>索引 3：`sum = 0`（初始）→ `30`（賦值後） |
| **運算元棧**<br>Operand Stack | 執行 `a + b` 時，a 和 b 先入棧，加法後出棧<br>結果 30 入棧，賦值給 sum 後出棧 |
| **動態連結**<br>Dynamic Linking | 指向運行時常量池中該方法的引用 |
| **方法返回地址**<br>Return Address | 記錄調用者的 PC 值，方法結束後回到哪裡 |

### StackOverflowError vs OOM：

```java
// StackOverflowError：棧深度超過限制
public void infinite() {
    infinite(); // 遞迴沒有出口 → StackOverflowError
}

// OOM：建立太多線程
for (int i = 0; i < 100000; i++) {
    new Thread(() -> {
        while(true) {}
    }).start(); // OOM: unable to create new native thread
}

// 調整棧大小
// -Xss512k  每個線程棧大小為 512KB（預設 512k~1M）
```

## 堆（Heap）⭐ 最重要

- ✅ 線程共享（所有線程都用同一個堆）
- ✅ JVM 中最大的記憶體區域
- ✅ GC 主要工作區域
- ❗ 可能拋出 `OOM: Java heap space`

**堆的結構（分代設計）**

``` mermaid
block-beta
    columns 3
    block:young:2
        columns 4
        yt["新生代 Young Gen（佔堆 1/3）"]:4
        eden["Eden 8/10"]:2 s0["S0 1/10"] s1["S1 1/10"]
    end
    block:old:1
        columns 1
        ot["老年代 Old Gen（佔堆 2/3）"]
        oc["長期存活的對象<br>大對象（直接進入）"]
    end
```

- Eden : S0 : S1 = 8 : 1 : 1
- 新生代 : 老年代 = 1 : 2

| JVM 參數 | 說明 |
|---------|------|
| `-Xms` | 堆初始大小 |
| `-Xmx` | 堆最大大小 |
| `-Xmn` | 新生代大小 |
| `-XX:SurvivorRatio=8` | Eden : S0 : S1 = 8 : 1 : 1 |

### 對象在堆中的生命週期：

```
新對象建立
    ↓
進入 Eden 區
    ↓
Eden 區滿 → 觸發 Minor GC
    ↓
存活對象（標記年齡 = 1）→ 移到 S0 區
死亡對象 → 回收
    ↓
再次 Minor GC
    ↓
S0 存活 → 移到 S1（年齡 +1）
Eden 存活 → 移到 S1（年齡 = 1）
    ↓
每次 Minor GC，S0 和 S1 互換角色（其中一個永遠為空）
    ↓
年齡 >= 15（預設）→ 晉升到老年代
    ↓
老年代滿 → 觸發 Full GC（Major GC）
```

```java
public void demo() {
    // 1. 短命對象（在 Minor GC 就被回收）
    for (int i = 0; i < 10000; i++) {
        String temp = new String("臨時字串"); // 每次循環後就沒有引用了
    }

    // 2. 長命對象（最終晉升到老年代）
    List<byte[]> cache = new ArrayList<>();
    for (int i = 0; i < 20; i++) {
        cache.add(new byte[1024 * 1024]); // 1MB，每次 Minor GC 都存活
    }

    // 3. 大對象（直接進老年代，不過 Eden）
    byte[] bigObj = new byte[1024 * 1024 * 10]; // 10MB 大對象
    // -XX:PretenureSizeThreshold=5M → 超過 5MB 直接進老年代
}
```

## 方法區 / Metaspace

- **Java 7 及之前**：方法區（PermGen 永久代）
- **Java 8 及之後**：Metaspace（元空間），使用本地記憶體，不在堆中

**儲存內容**

- ✅ 類的元資訊（欄位、方法、存取修飾符等）
- ✅ 運行時常量池（Runtime Constant Pool）
- ✅ 靜態變數（Static Variables）
- ✅ JIT 編譯後的程式碼快取

**為什麼從 PermGen 改為 Metaspace？**

| | PermGen | Metaspace |
|---|---|---|
| 記憶體位置 | 堆內 | 本地記憶體 |
| 大小 | ❌ 固定（`-XX:MaxPermSize`），容易 OOM | ✅ 動態調整，預設沒有上限 |
| GC 效率 | ❌ 低 | ✅ 較好 |
| 可預測性 | ❌ 框架動態生成大量類時難以預測 | ✅ 可用 `-XX:MaxMetaspaceSize` 設定上限 |

| JVM 參數 | 說明 |
|---------|------|
| `-XX:MetaspaceSize=256m` | 初始大小 |
| `-XX:MaxMetaspaceSize=512m` | 最大大小 |

### 字串常量池：

```java
// 字串常量池（String Pool）在 Java 8+ 移到了堆中！
String s1 = "Hello";             // 在字串常量池
String s2 = "Hello";             // 從常量池取同一個
String s3 = new String("Hello"); // 在堆中新建對象

System.out.println(s1 == s2); // true（同一個常量池引用）
System.out.println(s1 == s3); // false（s3 是堆中新對象）

// intern() - 手動放入常量池
String s4 = s3.intern();
System.out.println(s1 == s4); // true

// 整數常量池（-128 ~ 127）
Integer i1 = 127;
Integer i2 = 127;
System.out.println(i1 == i2); // true（常量池範圍內）

Integer i3 = 128;
Integer i4 = 128;
System.out.println(i3 == i4); // false（超出常量池範圍，新建對象）
```
