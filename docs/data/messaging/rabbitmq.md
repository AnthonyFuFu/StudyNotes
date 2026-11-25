# RabbitMQ

!!! abstract "本章重點"

    RabbitMQ 的核心是 Exchange 路由：訊息先送到交換器，再依規則分派到佇列。本章說明四種 Exchange、可靠性機制（Publisher Confirms、手動 ack、死信佇列），並與 Kafka 做完整比較。

RabbitMQ 是實作 **AMQP** 協定的訊息中介（Message Broker）。核心設計是：**Producer 不直接把訊息送到佇列，而是送到 Exchange，由 Exchange 依規則路由**。訊息被消費並確認後就會刪除。

## 架構

``` mermaid
flowchart LR
    P["Producer"] -- "routing key" --> EX{{"Exchange"}}
    EX -- "binding" --> Q1[("Queue A")]
    EX -- "binding" --> Q2[("Queue B")]
    Q1 --> C1["Consumer"]
    Q2 --> C2["Consumer"]
```

| 概念 | 說明 |
|------|------|
| **Exchange** | 交換器，依類型與 routing key 決定訊息要去哪些佇列 |
| **Queue** | 存放訊息的佇列 |
| **Binding** | Exchange 與 Queue 的綁定規則 |
| **Routing Key** | 訊息上的標籤 |
| **Virtual Host** | 邏輯隔離，像資料庫的 schema |

## 四種 Exchange

| 類型 | 路由規則 | 用途 |
|------|---------|------|
| **Direct** | routing key **完全相等** | 點對點任務分派 |
| **Topic** | routing key **萬用字元**：`*` 一個字、`#` 零到多個字 | 事件依類別訂閱，例如 `member.*`、`order.#` |
| **Fanout** | 忽略 key，**廣播**到所有綁定的佇列 | 通知所有服務 |
| **Headers** | 依訊息 header 比對 | 少用 |

## 我的實作：會員建立事件

microservicecloud 中，Provider 建立會員後發送事件，Consumer 非同步處理：

``` java
@Configuration
public class RabbitMQConfig {
    public static final String EXCHANGE_NAME = "member.exchange";
    public static final String ROUTING_KEY = "member.created";
    public static final String QUEUE_NAME = "member.created.queue";

    @Bean TopicExchange memberExchange() { return new TopicExchange(EXCHANGE_NAME); }

    @Bean Queue memberCreatedQueue() { return QueueBuilder.durable(QUEUE_NAME).build(); }   // 持久化

    @Bean Binding binding(Queue memberCreatedQueue, TopicExchange memberExchange) {
        return BindingBuilder.bind(memberCreatedQueue).to(memberExchange).with(ROUTING_KEY);
    }
}
```

``` java
// Provider：發布事件
rabbitTemplate.convertAndSend(RabbitMQConfig.EXCHANGE_NAME, RabbitMQConfig.ROUTING_KEY, event);

// Consumer：監聽佇列
@RabbitListener(queues = "member.created.queue")
public void handleMemberCreated(MemberCreatedEvent event) {
    // 發送歡迎郵件、初始化點數…
}
```

!!! tip "為什麼用 Topic Exchange"

    之後若新增 `member.updated`、`member.deleted` 事件，需要「所有會員事件」的服務只要綁定 `member.#` 即可，不必改 Producer。

## 可靠性機制

| 機制 | 作用 |
|------|------|
| **Publisher Confirms** | Broker 收到並持久化後回傳確認，Producer 才算送出成功 |
| **持久化** | 佇列 `durable=true` + 訊息 `deliveryMode=2`，Broker 重啟不遺失 |
| **手動 ack** | 處理完才確認；失敗可 `nack` 重新入列或送到死信 |
| **Prefetch** | 限制每個 Consumer 同時未確認的訊息數，避免一個 Consumer 囤積 |
| **死信佇列（DLX）** | 被拒絕、逾期、超過重試次數的訊息轉到另一個佇列，人工或排程處理 |
| **TTL + 死信** | 實作**延遲佇列**：訊息放在沒有消費者的佇列，逾期後轉到真正的處理佇列（例如 15 分鐘未付款自動取消） |
| **Quorum Queue** | 以 Raft 在多節點間複製佇列，取代舊的鏡像佇列 |

## Kafka 與 RabbitMQ 對照

| | Kafka | RabbitMQ |
|---|-------|----------|
| 模型 | 分散式日誌，Consumer **拉取（pull）** | 訊息中介，Broker **推送（push）** |
| 消費後 | 保留，可重播 | 確認後刪除 |
| 順序 | Partition 內有序 | 單一佇列 + 單一消費者時有序 |
| 吞吐量 | 極高（百萬級 / 秒） | 高（數萬級 / 秒） |
| 延遲 | 毫秒到十毫秒級 | **微秒到毫秒級** |
| 路由 | 只有 Topic + Partition | ✅ Exchange 彈性路由 |
| 延遲 / 優先權佇列 | ❌ 需自行實作 | ✅ 支援 |
| 我的使用 | holidayDessert 搶票訂單（削峰） | microservicecloud 會員事件（解耦） |

## 優點與缺點

=== "優點"

    - **路由彈性最好**：四種 Exchange 組合出各種投遞方式
    - 延遲低、功能齊全：死信、延遲、優先權、TTL
    - 管理介面直觀（`:15672`），容易觀察佇列狀態
    - Spring AMQP 整合簡單

=== "缺點"

    - 吞吐量不如 Kafka，不適合巨量日誌與串流
    - 訊息確認後就刪除，**無法重播**
    - 佇列大量堆積時效能下降明顯
