# Kafka

Kafka 本質上是一個**分散式、只能追加寫入的日誌（Commit Log）**。訊息被消費後**不會刪除**，而是依保留時間（預設 7 天）清理，所以可以重播。

## 架構

``` mermaid
flowchart LR
    P["Producer"] --> T
    subgraph T ["Topic：ticket-order"]
        direction TB
        P0["Partition 0"] ~~~ P1["Partition 1"] ~~~ P2["Partition 2"]
    end
    T --> G
    subgraph G ["Consumer Group：ticket-order-group"]
        direction TB
        C1["Consumer 1<br>← P0"] ~~~ C2["Consumer 2<br>← P1"] ~~~ C3["Consumer 3<br>← P2"]
    end
```

| 概念 | 說明 |
|------|------|
| **Broker** | 一台 Kafka 伺服器，多台組成叢集 |
| **Topic** | 訊息的分類 |
| **Partition** | Topic 切成多個分區，**並行的單位**；同一個 Partition 內保證順序 |
| **Offset** | 訊息在 Partition 中的位置，Consumer 自己記錄讀到哪裡 |
| **Consumer Group** | 同一組內，**一個 Partition 只會給一個 Consumer**；不同組各自完整消費 |
| **Replica** | Partition 的副本，Leader 負責讀寫，Follower 同步 |

!!! info "順序與並行的取捨"

    Kafka 只保證**同一個 Partition 內**有序。同一個訂單的事件要有序，就用訂單 ID 當 **key**，相同 key 會被分到同一個 Partition。Consumer 數量超過 Partition 數時，多出來的 Consumer 會閒置。

## 為什麼 Kafka 這麼快

| 技術 | 效果 |
|------|------|
| **順序寫入磁碟** | 只追加不修改，磁碟順序寫入速度接近記憶體 |
| **Page Cache** | 讀寫都經過作業系統快取，剛寫入的資料通常直接從記憶體讀 |
| **零拷貝（sendfile）** | 資料從 Page Cache 直接送到網卡，不經過應用程式記憶體 |
| **批次 + 壓縮** | Producer 累積一批再送（`linger.ms`、`batch.size`），並壓縮 |
| **Partition 並行** | 多個 Partition 分散在多台 Broker，水平擴展 |

## 我的實作：搶票訂單非同步落地

``` java
// Producer：搶票成功後送出訂單訊息
ticketOrderKafkaTemplate.send(TicketProducerConfig.TICKET_ORDER_TOPIC, message);
```

``` java
// Consumer：寫入資料庫
@KafkaListener(
    topics  = TicketProducerConfig.TICKET_ORDER_TOPIC,
    groupId = TicketConsumerConfig.TICKET_ORDER_GROUP,
    containerFactory = "ticketOrderKafkaListenerFactory"
)
@Transactional
public void consumeOrder(TicketOrderMessageDto message) {
    // Step 1：扣減 DB 庫存（條件式 UPDATE，影響 0 筆代表庫存不足）
    int affected = ticketTypeRepository.decrementRemaining(message.getTypeId(), message.getQuantity());
    if (affected == 0) {
        // 記錄補償日誌，交由後續對帳處理
    }
    // Step 2：建立訂單（狀態：待付款）
}
```

``` java
// 反序列化失敗時不要讓 Consumer 卡死：包一層 ErrorHandlingDeserializer
new ErrorHandlingDeserializer<>(new JsonDeserializer<>(TicketOrderMessageDto.class));
```

!!! warning "毒藥訊息（Poison Pill）"

    一筆格式錯誤的訊息如果每次反序列化都失敗，Consumer 會**一直重試同一筆**，後面的訊息全部卡住。`ErrorHandlingDeserializer` 會把錯誤交給錯誤處理器，再搭配 **Dead Letter Topic** 把壞訊息移走。

**序列化**：專案中保留了 Confluent **Avro** + Schema Registry 的設定。Avro 以二進位格式傳輸、由 Schema Registry 管理版本，欄位增減時能檢查前後相容性；JSON 則較直觀、好除錯。

**降級**：沒有啟用 `kafka` profile 時，訂單改由 `@Async` 執行緒池寫入，開發與測試環境不需要架 Kafka。

## 常用設定

| 設定 | 建議 | 說明 |
|------|------|------|
| `acks` | `all` | 所有同步副本都寫入才算成功 |
| `enable.idempotence` | `true` | Producer 冪等，重試不會產生重複訊息 |
| `enable.auto.commit` | `false` | 處理完才手動提交 offset |
| `max.poll.records` | 依處理速度 | 一次拉太多、處理太久會被踢出群組（觸發 Rebalance） |

## 優點與缺點

=== "優點"

    - **吞吐量極高**：每秒數十萬到百萬筆
    - **可重播**：訊息保留一段時間，新的消費者可以從頭讀
    - **水平擴展**：加 Partition、加 Broker
    - 生態完整：Kafka Connect、Kafka Streams、Schema Registry

=== "缺點"

    - **架設與維運複雜**：叢集、副本、Partition 規劃（新版 KRaft 已不需要 ZooKeeper）
    - 路由能力弱：沒有 RabbitMQ 那種彈性的 Exchange 路由
    - 沒有原生的延遲佇列、優先權佇列
    - 單筆訊息延遲比 RabbitMQ 高（為了批次與吞吐）
