# 熱 Key / 大 Key 處理

## 熱 Key（Hot Key）

```
問題：
  某個 key 被大量請求訪問（如：秒殺商品詳情）
  → 該 key 所在的 Redis 節點 CPU 飆高
  → 單點成為瓶頸

發現方法：
  ① redis-cli --hotkeys（Redis 4.0+）
  ② monitor 命令（生產慎用，會影響效能）
  ③ Proxy 層統計（如：Twemproxy）
  ④ 客戶端埋點（記錄 key 訪問頻率）

解決方案：

① 本地緩存（最有效）
  熱 Key 直接緩存在應用本地（Caffeine）
  不需要訪問 Redis！
  缺點：各實例數據可能不一致（短暫）

② Key 分片（打散熱點）
  將一個熱 Key 複製成 N 份：
  hot:product:100:0 ~ hot:product:100:9
  讀取時隨機選一份：
  int shard = ThreadLocalRandom.current().nextInt(10);
  String key = "hot:product:100:" + shard;

  寫入時更新所有分片（或異步更新）

③ Redis Cluster 讀寫分離
  對熱 Key 進行讀擴展（讀從節點）
```

## 大 Key（Big Key）

```
什麼是大 Key？
  String 類型 > 10KB
  List / Hash / Set / ZSet 元素數量 > 10000 個

問題：
  ① 佔用大量記憶體
  ② 查詢耗時（網路傳輸慢）
  ③ 刪除大 Key 會阻塞 Redis（DEL 是同步的！）
  ④ 主從同步時，大 Key 的 RDB 傳輸耗時

發現方法：
  redis-cli --bigkeys                    # 掃描大 key
  redis-cli -c DEBUG OBJECT key          # 查看 key 大小
  MEMORY USAGE keyname                   # 精確記憶體佔用

解決方案：

① 拆分大 Key
  Hash 有 10 萬個 field → 拆成 100 個 Hash，每個 1000 個 field
  big:hash:key → hash:key:0 ~ hash:key:99
  分片規則：field 的 hash % 100

② 壓縮 Value
  使用 Snappy / LZ4 壓縮存儲
  適合：value 是重複性高的 JSON

③ 刪除大 Key 用 UNLINK（非同步刪除）
  DEL key    → 同步刪除（會阻塞！）
  UNLINK key → 非同步刪除（先斷開引用，再後台清理） ✅

  或分批刪除（List / Hash / ZSet）：
  HSCAN → 每次刪除 100 個 field → 重複直到清空
```

```java
// 安全刪除大 Key（分批）
public void deleteLargeHash(String key) {
    ScanOptions options = ScanOptions.scanOptions().count(100).build();
    Cursor<Map.Entry<Object, Object>> cursor =
        redisTemplate.opsForHash().scan(key, options);

    while (cursor.hasNext()) {
        List<Object> fields = new ArrayList<>();
        for (int i = 0; i < 100 && cursor.hasNext(); i++) {
            fields.add(cursor.next().getKey());
        }
        redisTemplate.opsForHash().delete(key, fields.toArray());
    }
    redisTemplate.delete(key); // 最後刪除 key 本身
}

// UNLINK（非同步刪除）
redisTemplate.unlink("large:key");  // Spring Data Redis 支援
```
