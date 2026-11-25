# 線程池

## ThreadPoolExecutor 7 個參數

```java
ThreadPoolExecutor executor = new ThreadPoolExecutor(
    5,                                    // ① corePoolSize：核心線程數（長期保留）
    20,                                   // ② maximumPoolSize：最大線程數
    60L,                                  // ③ keepAliveTime：非核心線程空閒存活時間
    TimeUnit.SECONDS,                     // ④ unit：時間單位
    new LinkedBlockingQueue<>(200),       // ⑤ workQueue：等待佇列
    new ThreadFactoryBuilder()            // ⑥ threadFactory：線程工廠（命名！）
        .setNameFormat("order-pool-%d")
        .build(),
    new ThreadPoolExecutor.CallerRunsPolicy() // ⑦ handler：拒絕策略
);
```

```
線程池工作流程：

提交任務
  │
  ├→ 核心線程數 < corePoolSize？
  │   是 → 創建新核心線程執行
  │
  ├→ 佇列未滿？
  │   是 → 加入等待佇列
  │
  ├→ 線程數 < maximumPoolSize？
  │   是 → 創建非核心線程執行
  │
  └→ 執行拒絕策略！

四種拒絕策略：

AbortPolicy（預設）：
  拋出 RejectedExecutionException
  ❌ 不推薦（會讓調用方崩潰）

CallerRunsPolicy（推薦）：
  由提交任務的線程自己執行
  ✅ 起到降速效果，不丟任務

DiscardPolicy：
  靜默丟棄任務
  ❌ 任務丟失，難以排查

DiscardOldestPolicy：
  丟棄佇列中最老的任務
  ❌ 可能丟失重要任務
```

```java
// ❌ 不要用 Executors 工廠方法！
Executors.newFixedThreadPool(10);
// 使用 LinkedBlockingQueue（無界佇列！）
// 任務堆積 → OOM！

Executors.newCachedThreadPool();
// 最大線程數 Integer.MAX_VALUE
// 任務多時創建大量線程 → OOM！

// ✅ 自定義線程池參數

// 計算建議值：
// CPU 密集型（加密/計算）：corePoolSize = CPU 核心數 + 1
// IO 密集型（資料庫/網路）：corePoolSize = CPU 核心數 × 2

int cpuCores = Runtime.getRuntime().availableProcessors();

// 統一管理線程池（放在配置類）
@Configuration
public class ThreadPoolConfig {

    @Bean("orderTaskExecutor")
    public ThreadPoolExecutor orderTaskExecutor() {
        return new ThreadPoolExecutor(
            10, 50, 60L, TimeUnit.SECONDS,
            new LinkedBlockingQueue<>(500),
            new ThreadFactoryBuilder()
                .setNameFormat("order-task-%d")
                .setDaemon(false)
                .build(),
            (r, executor) -> {
                // 自定義拒絕策略：記錄日誌 + 告警
                log.error("線程池已滿！佇列大小：{}，活躍線程：{}",
                    executor.getQueue().size(),
                    executor.getActiveCount());
                // 降級處理：同步執行
                r.run();
            }
        );
    }

    // Spring 異步任務線程池（@Async 使用）
    @Bean
    public Executor asyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);
        executor.setMaxPoolSize(50);
        executor.setQueueCapacity(200);
        executor.setThreadNamePrefix("async-task-");
        executor.setRejectedExecutionHandler(
            new ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
```

## 線程池監控

```java
// 監控線程池狀態（定期打印）
@Scheduled(fixedRate = 30000)
public void monitorThreadPool() {
    log.info("線程池狀態 - 核心：{}, 活躍：{}, 最大：{}, " +
             "完成：{}, 佇列：{}, 任務總數：{}",
        executor.getCorePoolSize(),
        executor.getActiveCount(),
        executor.getMaximumPoolSize(),
        executor.getCompletedTaskCount(),
        executor.getQueue().size(),
        executor.getTaskCount()
    );
}
```
