# 持久化機制

!!! abstract "本章重點"

    Redis 是記憶體資料庫，重啟後資料要靠持久化恢復。本章比較 RDB 快照與 AOF 日誌的原理與優缺點，並說明生產環境推薦的混合持久化設定。

## RDB（Redis Database Backup）

RDB = 快照（Snapshot）

- 在指定時間點，將記憶體中的資料以二進制格式存到 .rdb 檔案

**觸發方式**

- ① save 命令（同步，阻塞 Redis，生產禁用）
- ② bgsave 命令（非同步，fork 子程序，不阻塞）
- ③ 自動觸發（redis.conf 配置）：

``` text
save 900 1     → 900 秒內有 1 個 key 修改
save 300 10    → 300 秒內有 10 個 key 修改
```

- save 60 10000  → 60 秒內有 10000 個 key 修改

**bgsave 流程（重要！）**

- ① Redis 父程序 fork() 出子程序
- ② 子程序把記憶體快照寫入臨時 .rdb 檔案
- ③ 寫完後替換舊的 .rdb 檔案
- ④ 父程序繼續處理請求（不阻塞！）

**Copy-On-Write（寫時複製）**

- fork 後父子程序共享記憶體頁
- 父程序修改某頁時，才複製該頁給子程序
- → 大多數時候記憶體不需要複製（節省記憶體）

**優點**

- ✅ 文件小，恢復速度快
- ✅ 適合做備份（每天定時 bgsave）
- ✅ 對 Redis 效能影響小

**缺點**

- ❌ 兩次快照之間的數據可能丟失（最多丟幾分鐘）
- ❌ fork 時若記憶體很大，fork 本身會短暫阻塞

## AOF（Append Only File）

AOF = 追加日誌

- 每次寫操作都追加到 .aof 文件（類似 MySQL Binlog）

**AOF 同步策略（appendfsync）**

- always：   每次寫操作都 fsync（最安全，最慢）
- everysec： 每秒 fsync 一次（推薦，最多丟 1 秒資料）✅
- no：       由 OS 決定何時 fsync（最快，不可控）

**AOF 重寫（rewrite）**

- 問題：AOF 文件會越來越大（含大量過期命令）
    - SET k 1 → SET k 2 → SET k 3 → 只有最後一條有意義

- 解決：AOF 重寫
- ① bgrewriteaof 命令（或自動觸發）
- ② fork 子程序，掃描當前記憶體，生成最小化的 AOF
- ③ 重寫期間的新命令寫入「AOF 重寫緩衝區」
- ④ 子程序完成後，緩衝區追加到新 AOF
- ⑤ 替換舊 AOF 文件

**自動觸發配置**

- auto-aof-rewrite-percentage 100  → AOF 比上次增長 100%
- auto-aof-rewrite-min-size 64mb   → AOF 最小 64MB 才觸發

**優點**

- ✅ 數據更完整（最多丟 1 秒）
- ✅ 文本格式，可讀性強

**缺點**

- ❌ 文件比 RDB 大
- ❌ 恢復速度比 RDB 慢

## 混合持久化（推薦）

Redis 4.0 引入，結合 RDB 和 AOF 的優點。開啟方式：`aof-use-rdb-preamble yes`。

**AOF 重寫後的檔案格式**

``` mermaid
block-beta
    columns 5
    rdb["RDB 格式快照<br>重寫時的記憶體"]:2 aof["AOF 格式的增量命令<br>重寫完成後的新命令"]:3
```

**恢復時**：① 先快速載入 RDB 部分 → ② 再重放少量 AOF 增量部分，兼顧速度和完整性。

!!! tip "生產建議"

    - ✅ 開啟 AOF（`appendonly yes`）
    - ✅ 開啟混合模式（`aof-use-rdb-preamble yes`）
    - ✅ AOF 同步策略用 `everysec`
    - ✅ 定期手動 `bgsave` 做備份
