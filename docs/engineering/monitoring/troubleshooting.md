# 線上問題排查 SOP

!!! abstract "本章重點"

    告警響了之後，排查要有固定的順序，而不是到處亂看。本章整理一套由外而內的排查流程，以及 CPU 飆高、記憶體不足、回應變慢、連線耗盡等常見情境的定位方法與 Linux / JVM / 資料庫指令。

## 排查原則

``` mermaid
flowchart LR
    A["① 止血<br>回滾、擴容、降級"] --> B["② 確認範圍<br>哪些服務、多少使用者"] --> C["③ 看指標<br>Grafana / 告警"] --> D["④ 定位<br>日誌、鏈路、指令"] --> E["⑤ 根因與預防<br>事後檢討"]
```

!!! tip "先止血，再查原因"

    正式環境出問題時，**恢復服務優先於找到原因**。最近剛部署就先回滾（[Argo CD](../cicd/argocd.md) 回滾或 `kubectl rollout undo`），流量暴增就先擴容或限流；但在重啟之前，先把執行緒傾印與堆傾印**保存下來**，否則證據就消失了。

## 由外而內定位

| 層級 | 先看什麼 | 工具 |
|------|---------|------|
| 入口 | 錯誤率、延遲是否全面上升 | Nginx / ALB 存取日誌、[Grafana](grafana.md) |
| 鏈路 | 時間花在哪一個服務、哪一段 | [Zipkin / SkyWalking](tracing.md) |
| 應用 | 錯誤日誌、例外堆疊 | [Kibana](elk.md)，依 `traceId` 搜尋 |
| JVM | GC、執行緒、記憶體 | `jstat`、`jstack`、`jmap`、Arthas |
| 系統 | CPU、記憶體、磁碟、網路 | `top`、`free`、`df`、`ss` |
| 依賴 | 資料庫、Redis、MQ 是否變慢 | 慢查詢日誌、`SHOW PROCESSLIST`、`redis-cli --latency` |

## 常見情境

=== "CPU 飆高"

    ``` bash
    top -c                               # 找出 CPU 最高的 Java 程序 PID
    top -Hp <PID>                        # 找出該程序中 CPU 最高的執行緒 TID
    printf '%x\n' <TID>                  # 轉成 16 進位，例如 1a2b
    jstack <PID> | grep -A 20 'nid=0x1a2b'   # 在執行緒傾印中找到這條執行緒在做什麼
    ```

    | 常見原因 | 特徵 |
    |---------|------|
    | 無窮迴圈、正規表示式回溯 | 某條業務執行緒持續 RUNNABLE |
    | **頻繁 Full GC** | GC 執行緒佔滿 CPU，`jstat -gcutil` 的 FGC 一直增加 |
    | 大量序列化 / 加解密 | 堆疊停在 Jackson、加密函式 |

=== "記憶體不足 / OOM"

    ``` bash
    jstat -gcutil <PID> 1000             # 每秒觀察一次，老年代（O）回收後仍居高不下 → 洩漏
    jmap -histo:live <PID> | head -20    # 哪種物件數量最多
    jmap -dump:live,format=b,file=heap.hprof <PID>   # 產生堆傾印，用 Eclipse MAT 分析
    ```

    啟動參數一定要加上 `-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/dumps`，OOM 時自動留下證據。

    | 常見原因 | 例子 |
    |---------|------|
    | 集合只加不刪 | 靜態 `Map` 當快取卻沒有上限 |
    | ThreadLocal 未清除 | 執行緒池中的 ThreadLocal（見 [ThreadLocal](../../java/concurrency/threadlocal.md)） |
    | 一次載入大量資料 | 匯出報表一次查出百萬筆、上傳檔案整個讀進記憶體 |

    容器中還要注意：Pod 被 **OOMKilled** 不一定是 Java heap 滿了，也可能是 Metaspace、執行緒堆疊、Direct Memory 加起來超過容器限制。

=== "回應變慢"

    ``` bash
    jstack <PID> > dump1.txt; sleep 5; jstack <PID> > dump2.txt
    # 比對兩次傾印：大量執行緒卡在同一個地方，就是瓶頸
    grep -A 5 'BLOCKED' dump1.txt        # 等待鎖
    grep -c 'HikariPool' dump1.txt       # 大量執行緒在等資料庫連線
    ```

    | 卡住的位置 | 代表 |
    |-----------|------|
    | `HikariPool.getConnection` | 資料庫連線池耗盡：慢查詢或連線沒釋放 |
    | `SocketInputStream.read` | 等外部 API 回應：檢查逾時設定與熔斷 |
    | `BLOCKED on <monitor>` | 鎖競爭：`synchronized` 範圍太大 |
    | 大量 `WAITING (parking)` 在執行緒池 | 執行緒池滿了 |

=== "連線與網路"

    ``` bash
    ss -s                                # 連線總覽
    ss -tan | awk '{print $1}' | sort | uniq -c    # 各狀態的連線數
    ss -tanp | grep 3306 | wc -l         # 連到 MySQL 的連線數
    curl -o /dev/null -s -w '%{time_connect} %{time_starttransfer} %{time_total}\n' https://api.example.com
    ```

    大量 `TIME_WAIT` 通常是短連線太多（見 [TCP 四次揮手](../../network-security/network/tcp.md)），應該改用連線池或 HTTP Keep-Alive；大量 `CLOSE_WAIT` 則代表**自己的程式沒有關閉連線**。

=== "資料庫"

    ``` sql
    SHOW FULL PROCESSLIST;                                   -- 正在執行的查詢，看 Time 很長的
    SELECT * FROM information_schema.innodb_trx;            -- 執行中的交易
    SELECT * FROM performance_schema.data_lock_waits;       -- 誰在等誰的鎖（MySQL 8）
    ```

    找到慢查詢後用 [EXPLAIN](../../data/mysql/explain.md) 分析；長時間未提交的交易會持有鎖、讓其他請求排隊。

## Arthas：不重啟就能看線上程式

| 指令 | 用途 |
|------|------|
| `dashboard` | 即時的執行緒、記憶體、GC 總覽 |
| `thread -n 3` | CPU 最高的 3 條執行緒與堆疊 |
| `thread -b` | 找出造成阻塞的執行緒 |
| `trace com.xxx.OrderService create` | 方法內部每一步的耗時 |
| `watch com.xxx.OrderService create '{params, returnObj}'` | 觀察參數與回傳值 |
| `jad com.xxx.OrderService` | 反編譯，確認線上跑的是不是預期的版本 |

## Kubernetes 環境

``` bash
kubectl get pods -n order -o wide                # 狀態、重啟次數、所在節點
kubectl describe pod <pod> -n order              # Events：OOMKilled、探針失敗、拉不到映像
kubectl logs <pod> -n order --previous           # 上一次（崩潰前）容器的日誌
kubectl top pod -n order                         # CPU / 記憶體用量
kubectl exec -it <pod> -n order -- jcmd 1 Thread.print   # 在容器內取得執行緒傾印
```

## 事後檢討（Postmortem）

| 項目 | 內容 |
|------|------|
| 時間軸 | 何時發生、何時發現、何時止血、何時恢復 |
| 影響範圍 | 多少使用者、多少訂單、損失多少 |
| 根本原因 | 用「五個為什麼」追到真正的原因，而不是「某人操作失誤」 |
| 改善項目 | 加監控、加告警、加測試、改架構，每一項都要有負責人與期限 |

**不究責文化**：檢討的目的是改善系統，不是找人負責；否則下一次大家會選擇隱瞞問題。
