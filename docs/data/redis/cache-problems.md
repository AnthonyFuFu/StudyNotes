# 緩存三大問題

## 緩存穿透（Cache Penetration）

```
問題：
  查詢一個「不存在的 key」（如：id = -1）
  Redis 沒有 → 打到 DB → DB 也沒有
  大量這樣的請求 → DB 被打垮！
  （可能是惡意攻擊）

解決方案：

① 緩存空值（最簡單）
  查詢結果為 null → 也存入 Redis（value = 空字串）
  設置短 TTL（如：5 分鐘）
  缺點：大量不同的 id → 佔用大量 Redis 記憶體

② 布隆過濾器（Bloom Filter）⭐ 推薦
  預先把所有有效 id 加入布隆過濾器
  請求到來先查布隆過濾器
  不在 → 直接返回（不查 DB）
  在 → 查 Redis → 查 DB

  布隆過濾器特性：
  ✅ 說「不存在」→ 100% 不存在
  ⚠️ 說「存在」→ 可能誤判（有 Hash 碰撞）
  記憶體極省（1億個元素約 125MB）
```

```java
// 方案一：緩存空值
public User getUser(Long id) {
    String key = "user:" + id;
    String cached = redisTemplate.opsForValue().get(key);

    if (cached != null) {
        if ("null".equals(cached)) {
            return null; // 緩存了空值
        }
        return JSON.parseObject(cached, User.class);
    }

    User user = userRepository.findById(id).orElse(null);
    if (user == null) {
        // 緩存空值，TTL 短一些
        redisTemplate.opsForValue().set(key, "null", Duration.ofMinutes(5));
    } else {
        redisTemplate.opsForValue().set(key, JSON.toJSONString(user),
            Duration.ofMinutes(30));
    }
    return user;
}

// 方案二：布隆過濾器（Redisson）
@Component
public class UserBloomFilter {

    @Autowired
    private RedissonClient redissonClient;

    private RBloomFilter<Long> bloomFilter;

    @PostConstruct
    public void init() {
        bloomFilter = redissonClient.getBloomFilter("bloom:user");
        // 預計 1 億個元素，誤判率 0.01%
        bloomFilter.tryInit(100_000_000L, 0.001);

        // 初始化：把所有有效 userId 加入布隆過濾器
        userRepository.findAllIds().forEach(bloomFilter::add);
    }

    public boolean mightExist(Long userId) {
        return bloomFilter.contains(userId);
    }

    // 新增用戶時同步更新
    public void addUser(Long userId) {
        bloomFilter.add(userId);
    }
}

// 使用
public User getUser(Long id) {
    if (!bloomFilter.mightExist(id)) {
        return null; // 布隆過濾器說不存在 → 直接返回
    }
    // 正常查詢流程...
}
```

## 緩存擊穿（Cache Breakdown）

```
問題：
  一個「熱點 key」突然過期
  大量請求同時打到 DB（同一時刻）
  DB 壓力驟增

解決方案：

① 互斥鎖（Mutex Lock）
  只讓一個請求重建緩存
  其他請求等待或返回舊資料

② 邏輯過期（不設 TTL，手動控制）
  緩存永不過期
  value 中加入 expire_time 欄位
  讀到過期時，非同步更新緩存（立即返回舊資料）
```

```java
// 方案一：互斥鎖
public Product getProduct(Long id) {
    String key     = "product:" + id;
    String lockKey = "lock:rebuild:" + id;

    // 1. 先查緩存
    String cached = redisTemplate.opsForValue().get(key);
    if (cached != null) {
        return JSON.parseObject(cached, Product.class);
    }

    // 2. 緩存未命中，嘗試獲取鎖
    String requestId = UUID.randomUUID().toString();
    boolean locked = Boolean.TRUE.equals(
        redisTemplate.opsForValue()
            .setIfAbsent(lockKey, requestId, Duration.ofSeconds(3))
    );

    try {
        if (locked) {
            // 3. 獲得鎖 → 重建緩存
            // 再查一次（雙重檢查，防止其他線程已經重建）
            cached = redisTemplate.opsForValue().get(key);
            if (cached != null) {
                return JSON.parseObject(cached, Product.class);
            }

            Product product = productRepository.findById(id).orElseThrow();
            redisTemplate.opsForValue().set(key, JSON.toJSONString(product),
                Duration.ofMinutes(30));
            return product;
        } else {
            // 4. 未獲得鎖 → 短暫等待後重試
            Thread.sleep(50);
            return getProduct(id); // 遞迴重試
        }
    } finally {
        // 5. 釋放鎖（Lua 原子操作）
        if (locked) {
            unlock(lockKey, requestId);
        }
    }
}

// 方案二：邏輯過期（熱點數據，永不過期）
@Data
public class CacheWrapper<T> {
    private T      data;
    private LocalDateTime expireTime; // 邏輯過期時間（存在 value 裡）
}

public Product getProductWithLogicalExpire(Long id) {
    String key    = "product:" + id;
    String cached = redisTemplate.opsForValue().get(key);

    CacheWrapper<Product> wrapper =
        JSON.parseObject(cached, new TypeReference<CacheWrapper<Product>>() {});

    // 未過期 → 直接返回
    if (LocalDateTime.now().isBefore(wrapper.getExpireTime())) {
        return wrapper.getData();
    }

    // 已過期 → 非同步重建，先返回舊資料
    String lockKey = "lock:rebuild:" + id;
    boolean locked = Boolean.TRUE.equals(
        redisTemplate.opsForValue()
            .setIfAbsent(lockKey, "1", Duration.ofSeconds(3))
    );

    if (locked) {
        // 非同步重建緩存（不阻塞當前請求）
        CompletableFuture.runAsync(() -> {
            try {
                Product product = productRepository.findById(id).orElseThrow();
                CacheWrapper<Product> newWrapper = new CacheWrapper<>();
                newWrapper.setData(product);
                newWrapper.setExpireTime(LocalDateTime.now().plusMinutes(30));
                redisTemplate.opsForValue()
                    .set(key, JSON.toJSONString(newWrapper));
            } finally {
                redisTemplate.delete(lockKey);
            }
        }, executor);
    }

    return wrapper.getData(); // 立即返回舊資料，不讓用戶等待
}
```

## 緩存雪崩（Cache Avalanche）

```
問題：
  大量 key 在同一時間過期（如：夜間批次初始化緩存，TTL 全設 30 分鐘）
  → 30 分鐘後全部過期 → 大量請求同時打到 DB → 雪崩！

另一種場景：
  Redis 服務直接宕機 → 所有請求打到 DB

解決方案：

① TTL 隨機化（防止同時過期）
  TTL = 基礎時間 + random(0, 600) 秒
  讓過期時間分散，避免同時失效

② 永不過期 + 非同步更新（邏輯過期）
  見上方「緩存擊穿方案二」

③ Redis 高可用（防止宕機）
  Redis Sentinel（哨兵模式，自動主從切換）
  Redis Cluster（集群模式，分片 + 高可用）

④ 多級緩存（降低 Redis 壓力）
  本地緩存（Caffeine）→ Redis → DB
  即使 Redis 宕機，本地緩存仍可服務

⑤ 熔斷降級（服務保護）
  檢測到 DB 壓力過大 → 熔斷 → 返回預設值
  Sentinel / Resilience4j 實作
```

```java
// ① TTL 隨機化
private static final Random RANDOM = new Random();

public void cacheProduct(Long id, Product product) {
    int baseTtl    = 30 * 60;              // 30 分鐘（秒）
    int jitter     = RANDOM.nextInt(600);  // 隨機 0~10 分鐘
    int actualTtl  = baseTtl + jitter;

    redisTemplate.opsForValue().set(
        "product:" + id,
        JSON.toJSONString(product),
        Duration.ofSeconds(actualTtl)
    );
}

// ④ 多級緩存（Caffeine + Redis）
@Service
public class ProductCacheService {

    private final Cache<Long, Product> localCache = Caffeine.newBuilder()
        .maximumSize(1000)
        .expireAfterWrite(5, TimeUnit.MINUTES) // 本地緩存 5 分鐘
        .build();

    @Autowired
    private StringRedisTemplate redisTemplate;

    public Product getProduct(Long id) {
        // L1：本地緩存（毫秒級，零網路開銷）
        Product product = localCache.getIfPresent(id);
        if (product != null) return product;

        // L2：Redis 緩存
        String cached = redisTemplate.opsForValue().get("product:" + id);
        if (cached != null) {
            product = JSON.parseObject(cached, Product.class);
            localCache.put(id, product); // 回填本地緩存
            return product;
        }

        // L3：資料庫
        product = productRepository.findById(id).orElseThrow();
        redisTemplate.opsForValue().set("product:" + id,
            JSON.toJSONString(product), Duration.ofMinutes(30));
        localCache.put(id, product);
        return product;
    }
}
```
