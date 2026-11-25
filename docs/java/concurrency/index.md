---
icon: lucide/zap
---

# Java 並發

從執行緒狀態、synchronized 與 volatile 的底層，到 AQS、線程池與 CompletableFuture 的異步編排。

**核心技術**：Thread / synchronized / AQS / 線程池 / CompletableFuture

## 學習地圖

``` mermaid
mindmap
  root((Java 並發深度))
    Thread 生命週期與狀態轉換
    synchronized 底層原理
      Monitor 物件鎖
      鎖升級：偏向 → 輕量 → 重量
    volatile 原理
      記憶體屏障
      MESI 緩存一致性協議
    AQS 底層原理
      CLH 等待佇列
      獨佔 / 共享模式
    鎖進階
      ReentrantLock
      ReadWriteLock
      StampedLock
    ThreadLocal
      底層原理
      記憶體洩漏問題
    線程池
      ThreadPoolExecutor 7 個參數
      拒絕策略
      線程池調優
    ConcurrentHashMap 底層原理
      JDK 8 CAS + Synchronized
    CompletableFuture 異步編排
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · Thread 生命週期與狀態轉換](thread-lifecycle.md)__

    ---

    六種狀態 · 中斷機制

-   __[02 · synchronized 底層原理](synchronized.md)__

    ---

    Monitor 物件鎖 · 鎖升級機制

-   __[03 · volatile 原理](volatile.md)__

    ---

    兩大保證 · 記憶體屏障

-   __[04 · AQS 底層原理](aqs.md)__

    ---

    AQS 架構

-   __[05 · 鎖進階](locks.md)__

    ---

    ReentrantLock · ReadWriteLock · StampedLock

-   __[06 · ThreadLocal](threadlocal.md)__

    ---

    底層原理 · 記憶體洩漏問題

-   __[07 · 線程池](thread-pool.md)__

    ---

    ThreadPoolExecutor 7 個參數 · 線程池監控

-   __[08 · ConcurrentHashMap 底層原理](concurrenthashmap.md)__

    ---

    JDK 7 vs JDK 8

-   __[09 · CompletableFuture 異步編排](completablefuture.md)__

    ---

    核心 API

</div>

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **Thread 狀態** | NEW / RUNNABLE / BLOCKED / WAITING / TIMED_WAITING / TERMINATED |
| **synchronized** | Monitor 物件鎖，EntryList + WaitSet，可重入 |
| **鎖升級** | 無鎖 → 偏向鎖 → 輕量級鎖（CAS）→ 重量級鎖，只升不降 |
| **volatile** | 可見性 + 有序性（不保證原子性），記憶體屏障防止重排序 |
| **AQS** | state + CLH 佇列，是 ReentrantLock / Semaphore 的骨幹 |
| **ReentrantLock** | 可中斷 / 可超時 / 公平鎖 / Condition，必須 finally unlock |
| **ReadWriteLock** | 讀讀不互斥，讀寫 / 寫寫互斥，讀多寫少場景 |
| **StampedLock** | 樂觀讀（不加鎖），效能最強，不支援重入 |
| **ThreadLocal** | 每個線程獨立副本，key 是弱引用，用完必須 remove() |
| **線程池** | 7 個參數要熟背，禁用 Executors，推薦 CallerRunsPolicy |
| **ConcurrentHashMap** | JDK 8：CAS（空桶）+ Synchronized（桶頭節點），鎖粒度極細 |
| **CompletableFuture** | 異步編排，thenApply / thenCombine / allOf，並行查詢節省時間 |
