# GC 垃圾回收

## 如何判斷對象死亡

### 方式一：引用計數法（Java 不用！）

```java
// 引用計數法的致命缺陷：循環引用！
public class Node {
    public Node next;
}

Node a = new Node(); // a 引用計數 = 1
Node b = new Node(); // b 引用計數 = 1
a.next = b;          // b 引用計數 = 2
b.next = a;          // a 引用計數 = 2
a = null;            // a 引用計數 = 1（還有 b.next 指向它）
b = null;            // b 引用計數 = 1（還有 a.next 指向它）
// 兩個對象互相引用，引用計數永遠不為 0 → 記憶體洩漏 ❌
```

### 方式二：可達性分析（Java 使用！）

**GC Roots（根節點）**

- ✅ 虛擬機棧中的引用（局部變數）
- ✅ 方法區中的靜態變數引用
- ✅ 方法區中的常量引用
- ✅ 本地方法棧中的引用
- ✅ 被 synchronized 持有的對象

``` mermaid
flowchart TB
    R1(["GC Root 1"]) --> A["對象 A"] --> B["對象 B"]
    R2(["GC Root 2"]) --> C["對象 C"] --> D["對象 D"]
    E["對象 E"] <--> F["對象 F"]
    classDef dead stroke-dasharray:5 5,opacity:0.6
    class E,F dead
```

- ✅ **A、B、C、D**：從 GC Root 可達 → 存活
- ❌ **E、F**：互相引用但沒有 GC Root 到達 → 不可達，可以回收

### 四種引用類型：

```java
// 1. 強引用（Strong Reference）- 最常見
Object obj = new Object(); // GC 永遠不回收
obj = null; // 斷開引用後才可能被回收

// 2. 軟引用（Soft Reference）- 記憶體不足時回收
SoftReference<byte[]> softRef = new SoftReference<>(new byte[1024 * 1024]);
byte[] data = softRef.get(); // 可能為 null（已被回收）
// 用途：做緩存（記憶體夠就保留，不夠就回收）

// 3. 弱引用（Weak Reference）- 下次 GC 就回收
WeakReference<Object> weakRef = new WeakReference<>(new Object());
// 只要 GC 執行，就會被回收
// 用途：WeakHashMap（防止記憶體洩漏的 Map）

// 4. 虛引用（Phantom Reference）- 形同虛設
ReferenceQueue<Object> queue = new ReferenceQueue<>();
PhantomReference<Object> phantomRef =
    new PhantomReference<>(new Object(), queue);
phantomRef.get(); // 永遠返回 null！
// 用途：對象被回收時得到通知

// 引用強弱：強 > 軟 > 弱 > 虛
```

## 四大垃圾回收算法

### 算法一：標記-清除（Mark-Sweep）

``` mermaid
block-beta
    columns 8
    a1["A ✓"] e1[" "] b1["B ✓"] e2[" "] e3[" "] c1["C ✓"] e4[" "] d1["D ✓"]
    space:8
    a2["A"] f1["空"] b2["B"] f2["空"] f3["空"] c2["C"] f4["空"] d2["D"]
    classDef free fill:transparent,stroke-dasharray:4 4
    class f1,f2,f3,f4 free
```

上排為執行前（✓ = 存活），下排為清除後。

- ❌ 記憶體碎片化（空閒空間不連續）
- ❌ 下次分配大對象時找不到連續空間

### 算法二：標記-整理（Mark-Compact）

``` mermaid
block-beta
    columns 8
    a["A"] b["B"] c["C"] d["D"] f1["空"] f2["空"] f3["空"] f4["空"]
    classDef free fill:transparent,stroke-dasharray:4 4
    class f1,f2,f3,f4 free
```

存活對象整理到左邊，右邊形成連續空閒空間。

- **優點**：✅ 沒有碎片
- **缺點**：❌ 移動對象需要更新所有引用，效能較差（STW 時間長）
- **適用**：老年代（G1 / Serial Old）

### 算法三：複製算法（Copying）

``` mermaid
flowchart LR
    subgraph BEFORE ["執行前"]
        direction TB
        F1["From 區：A ✓ ｜ 　 ｜ B ✓ ｜ 　"]
        T1["To 區：空 ｜ 空 ｜ 空 ｜ 空"]
    end
    subgraph AFTER ["執行後"]
        direction TB
        F2["From 區：清空"]
        T2["To 區：A ｜ B ｜ 空 ｜ 空"]
    end
    BEFORE -- 複製存活對象 --> AFTER
```

- **優點**：✅ 沒有碎片、速度快
- **缺點**：❌ 浪費一半記憶體
- **適用**：新生代（Eden + S0/S1 就是複製算法）

### 算法四：分代收集（Generational Collection）

```
理論依據（弱分代假說）：
✅ 大多數對象朝生夕死（新生代）
✅ 少數對象長期存活（老年代）

新生代（Young Gen）→ 複製算法
  原因：存活率低（10%~20%），複製的對象少，速度快

老年代（Old Gen）→ 標記-清除 或 標記-整理
  原因：存活率高，複製算法太浪費空間

觸發 GC 的條件：
  Minor GC：Eden 區滿時觸發（回收新生代）
  Major GC：老年代空間不足時觸發（回收老年代）
  Full GC：Minor + Major，整個堆都回收（速度最慢！盡量避免）
```

## 六大 GC 收集器

```
收集器發展歷程：
Serial → ParNew → Parallel Scavenge
                         ↓
             Serial Old / Parallel Old / CMS
                         ↓
                        G1
                         ↓
                    ZGC / Shenandoah（Java 11+）
```

### 收集器一：Serial GC（序列）

- **特點**：單線程，GC 時 STW（Stop The World）
- **Young Gen**：複製算法
- **Old Gen**：標記-整理

``` mermaid
gantt
    title GC 期間的線程活動
    dateFormat x
    axisFormat %L
    section 業務線程
    執行      : 0, 40
    等待      : crit, 40, 55
    執行      : 55, 100
    section GC 線程
    GC（STW） : active, 40, 55
```

- **適用**：小型應用（Client 模式），記憶體小於 100MB
- **JVM 參數**：`-XX:+UseSerialGC`

### 收集器二：ParNew GC（並行）

```
特點：Serial 的多線程版，GC 時仍 STW，但多個 GC 線程同時工作
Young Gen：複製算法
Old Gen：配合 CMS 使用

JVM 參數：-XX:+UseParNewGC
```

### 收集器三：Parallel Scavenge GC（吞吐量優先）

```
目標：最大化吞吐量（Throughput = 運行用戶代碼時間 / 總時間）
適用：後台計算型應用（批次處理、科學計算）

JVM 參數：
-XX:+UseParallelGC
-XX:MaxGCPauseMillis=200    最大停頓時間目標
-XX:GCTimeRatio=99          吞吐量目標（99% 時間用在業務）
-XX:+UseAdaptiveSizePolicy  自動調整各區大小
```

### 收集器四：CMS GC（低延遲，已廢棄）

- **目標**：最短 GC 停頓時間（低延遲）
- **Old Gen**：標記-清除算法

**CMS 執行過程（4 個階段）**

| 階段 | 是否 STW | 說明 |
|------|---------|------|
| **1. 初始標記**（Initial Mark） | ⚠️ STW，但很短 | 只標記 GC Roots 直接關聯的對象 |
| **2. 並發標記**（Concurrent Mark） | ✅ 與業務線程並發 | 遍歷整個對象圖 |
| **3. 重新標記**（Remark） | ⚠️ STW，比初始標記稍長 | 修正並發標記期間業務線程變動的標記 |
| **4. 並發清除**（Concurrent Sweep） | ✅ 與業務線程並發 | 清除垃圾對象 |

``` mermaid
gantt
    title CMS 時間軸
    dateFormat x
    axisFormat %L
    section 業務線程
    執行     : 0, 20
    停       : crit, 20, 25
    執行     : 25, 60
    停       : crit, 60, 68
    執行     : 68, 100
    section GC 線程
    初始標記 : active, 20, 25
    並發標記 : 25, 60
    重新標記 : active, 60, 68
    並發清除 : 68, 100
```

**缺點**

- ❌ 標記-清除 → 記憶體碎片化
- ❌ 並發執行佔用 CPU 資源
- ❌ 浮動垃圾

**JVM 參數**：`-XX:+UseConcMarkSweepGC`（Java 14 已移除）

### 收集器五：G1 GC（Garbage First）⭐ Java 9+ 預設

**核心思想**：不再固定劃分新生代 / 老年代區域，而是把整個堆切成多個大小相等的 Region。

``` mermaid
block-beta
    columns 8
    r1["E"] r2["E"] r3["O"] r4["E"] r5["S"] r6["O"] r7["E"] r8["H"]
    r9["O"] r10["S"] r11["E"] r12["O"] r13["E"] r14["H"] r15["O"] r16["E"]
```

E = Eden　S = Survivor　O = Old　H = Humongous（大對象）

**特點**

- ✅ Region 可以動態分配角色
- ✅ 優先回收垃圾最多的 Region（Garbage First）
- ✅ 可預測的停頓時間（`-XX:MaxGCPauseMillis=200`）
- ✅ 整合了複製 + 標記-整理，沒有碎片

**G1 執行過程**

``` mermaid
flowchart LR
    Y["① Young GC<br>Eden 滿，回收新生代<br>STW・複製算法"] --> CM["② Concurrent Marking<br>並發標記整個堆"]
    CM --> MX["③ Mixed GC<br>新生代 + 部分老年代"]
    MX -.->|"來不及回收"| FG["④ Full GC<br>單線程，非常慢，要避免"]
```

**JVM 參數**

| 參數 | 說明 |
|------|------|
| `-XX:+UseG1GC` | 開啟 G1（Java 9+ 預設） |
| `-XX:MaxGCPauseMillis=200` | 最大停頓目標（毫秒） |
| `-XX:G1HeapRegionSize=16m` | Region 大小（1MB \~ 32MB，2 的冪次） |
| `-XX:G1NewSizePercent=5` | 新生代最小佔比 |
| `-XX:G1MaxNewSizePercent=60` | 新生代最大佔比 |
| `-XX:InitiatingHeapOccupancyPercent=45` | 堆使用率超過 45% 開始並發標記 |

### 收集器六：ZGC（Java 15 正式）

- **目標**：超低延遲（停頓時間 < 10ms，甚至 < 1ms）
- **最大支援**：16TB 的堆
- **核心技術**：染色指針（Colored Pointers）+ 讀屏障（Load Barrier）

ZGC 移動對象時幾乎全程並發；業務線程訪問舊地址時，讀屏障會自動轉發到新地址。

| 收集器 | 最大停頓時間 | 適用場景 |
|--------|------------|---------|
| Serial | 幾百 ms \~ 幾秒 | 小型應用 |
| Parallel | 幾百 ms | 後台批次 |
| G1 | < 200ms | 大多數應用 |
| **ZGC** | **< 10ms** | 超低延遲系統 |

!!! tip "啟用方式"

    `-XX:+UseZGC`。Java 21 的 ZGC 進一步優化，停頓時間可達 < 1ms。
