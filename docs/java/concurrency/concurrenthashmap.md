# ConcurrentHashMap 底層原理

## JDK 7 vs JDK 8

**JDK 7（Segment 分段鎖）**

- 16 個 Segment，每個 Segment 是一個小 HashMap
- 鎖粒度 = Segment（同一 Segment 的操作互斥）
- 最多 16 個線程並行

**JDK 8（CAS + Synchronized，更細粒度）**

- 結構：Node 陣列 + 鏈表 / 紅黑樹
- 鎖粒度 = 單個桶（Node 陣列的一格）
- 最多 N 個線程並行（N = 陣列長度）

**JDK 8 put 流程**

- ① 計算 key 的 hash 值
- ② 定位到陣列中的桶（index = hash & (n-1)）
- ③ 桶為空？
    - → CAS 插入新 Node（不加鎖，速度快）
- ④ 桶不為空，且 hash \=\= MOVED（-1）？
    - → 協助其他線程完成擴容
- ⑤ 桶不為空，且正常 Node？
    - → synchronized 鎖定這個桶的頭節點
    - → 插入鏈表 or 紅黑樹

**關鍵設計**

- 只鎖定單個桶的頭節點（鎖粒度極細）
- 不同桶的操作完全並行（高吞吐量）
- CAS 操作用於空桶插入（無鎖）

```java
// size() 的實現（不是簡單計數，而是 LongAdder）
// ConcurrentHashMap 使用分段計數（CounterCell 陣列）
// 避免高並發下 size 計數的競爭

// 常用方法
ConcurrentHashMap<String, Integer> map = new ConcurrentHashMap<>();

// putIfAbsent（原子操作）
map.putIfAbsent("key", 0);

// computeIfAbsent（初始化複雜對象）
map.computeIfAbsent("key", k -> new ArrayList<>()).add("value");

// compute（原子更新）
map.compute("count", (k, v) -> v == null ? 1 : v + 1);

// merge（合併）
map.merge("count", 1, Integer::sum);

// ⚠️ 注意：複合操作不是原子的！
// ❌ 非原子（check-then-act）
if (!map.containsKey("key")) {
    map.put("key", value);
}
// ✅ 使用 putIfAbsent 或 computeIfAbsent
map.putIfAbsent("key", value);
```
