# 分層架構與 DDD

!!! abstract "本章重點"

    程式碼要如何分層，決定了系統能不能長期維護。本章從最常見的三層式架構開始，說明它在業務變複雜後的問題，再介紹六角架構（Ports & Adapters）與領域驅動設計（DDD）的核心概念，以及它們和微服務拆分的關係。

## 三層式架構

``` mermaid
flowchart LR
    C["Controller<br>請求與驗證"] --> S["Service<br>業務邏輯"] --> D["Repository<br>資料存取"] --> DB[("資料庫")]
```

我的專案都是這種結構：holidayDessert 的 `controller` / `service` / `dao` / `repository`，chineseArtwork 的 `Controllers` / `Services` / `Dao`。

| ✅ 優點 | ❌ 業務變複雜後的問題 |
|--------|---------------------|
| 直覺、好上手，Spring 範本就是這樣 | **Service 越來越肥**：一個方法幾百行，所有規則都擠在這裡 |
| 職責大致分離 | Entity 只有 getter / setter（**貧血模型**），規則散落在各個 Service |
| 適合 CRUD 為主的系統 | 業務邏輯依賴 JPA、Redis、HTTP Client，測試要 Mock 一大堆東西 |

## 六角架構（Ports & Adapters）

核心想法：**業務邏輯放在中間，不依賴任何技術細節**；資料庫、MQ、外部 API 都是「插」在外面的轉接器。

``` mermaid
%%{init: {"flowchart": {"wrappingWidth": 360}}}%%
flowchart TB
    IN["驅動端轉接器<br>REST Controller ・ MQ Listener ・ 排程"] --> UC
    subgraph CORE ["應用核心（不依賴框架）"]
        UC["Use Case 應用服務"] --> DOM["Domain<br>實體、值物件、領域規則"]
        UC --> PORT["Port 介面<br>OrderRepository、PaymentGateway"]
    end
    PORT -. "由外層實作" .-> OUT["被驅動端轉接器<br>JPA 實作 ・ 金流 SDK ・ Kafka 發送"]
```

| 概念 | 說明 |
|------|------|
| **Port** | 核心定義的介面，例如 `OrderRepository`、`PaymentGateway` |
| **Adapter** | 外層的實作：`JpaOrderRepository`、`StripePaymentGateway` |
| **依賴方向** | 一律**由外往內**，核心不 import 任何 Spring、JPA 類別 |

好處：換資料庫、換金流商只要換 Adapter；業務規則可以用純 Java 單元測試，不需要啟動 Spring。這就是 SOLID 中的**依賴反轉原則**（見[六大原則](../design-pattern/principles.md)）在架構層級的應用。Clean Architecture、Onion Architecture 都是同一個思想的不同畫法。

## DDD 核心概念

### 戰略設計：怎麼切

| 概念 | 說明 | 例子 |
|------|------|------|
| **通用語言**（Ubiquitous Language） | 業務人員與工程師使用同一套詞彙，程式碼的命名也一樣 | 「訂單」「出貨」「退款」，而不是 `data1`、`process()` |
| **限界上下文**（Bounded Context） | 同一個詞在不同情境有不同意義，各自建模 | 「商品」在**目錄**是名稱與圖片，在**庫存**是數量與倉位，在**訂單**是當下的價格快照 |
| **上下文映射** | 上下文之間如何協作 | 訂單呼叫庫存、透過事件通知物流 |

!!! tip "限界上下文就是微服務的拆分依據"

    微服務最常見的錯誤是依「資料表」拆服務，結果服務之間互相呼叫得像蜘蛛網。依**限界上下文**拆分，每個服務擁有自己的模型與資料庫，彼此透過 API 或[領域事件](../../data/messaging/concepts.md)溝通。

### 戰術設計：怎麼寫

| 建構塊 | 說明 |
|--------|------|
| **Entity** | 有唯一識別、會隨時間改變的物件（訂單） |
| **Value Object** | 沒有識別、以值判斷相等、不可變（金額、地址）；Java 的 `record` 很適合 |
| **Aggregate** | 一組必須一起保持一致的物件，對外只能透過 **Aggregate Root** 操作 |
| **Domain Service** | 不屬於任何實體的業務規則（例如計算跨訂單的運費） |
| **Domain Event** | 已經發生的業務事實：`OrderPaid`、`TicketSoldOut` |
| **Repository** | 以 Aggregate 為單位存取，不是每張表一個 |

=== "貧血模型"

    ``` java
    // 規則散落在 Service：任何地方都可以 setStatus，狀態可能被改壞
    public void pay(Long orderId) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        if (!"PENDING".equals(order.getStatus())) throw new BusinessException("訂單無法付款");
        if (order.getExpireTime().isBefore(LocalDateTime.now())) throw new BusinessException("已逾期");
        order.setStatus("PAID");
        order.setPaidTime(LocalDateTime.now());
        orderRepository.save(order);
    }
    ```

=== "充血模型（DDD）"

    ``` java
    public class Order {                                   // Aggregate Root
        private OrderStatus status;
        private Money amount;                              // Value Object
        private LocalDateTime expireTime;

        public OrderPaid pay(Clock clock) {                // 規則跟著資料走
            if (status != OrderStatus.PENDING) throw new IllegalStateException("訂單無法付款");
            if (expireTime.isBefore(LocalDateTime.now(clock))) throw new IllegalStateException("已逾期");
            this.status = OrderStatus.PAID;
            return new OrderPaid(id, amount);              // 回傳領域事件
        }
    }

    // Service 變薄，只負責協調
    @Transactional
    public void pay(Long orderId) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        OrderPaid event = order.pay(clock);
        orderRepository.save(order);
        eventPublisher.publish(event);
    }
    ```

## 怎麼選

| 情境 | 建議 |
|------|------|
| CRUD 為主的後台、規則單純 | **三層式**就好，不要過度設計 |
| 業務規則多、會長期演進（訂單、金流、保險） | 核心領域用 **DDD + 六角架構** |
| 準備拆微服務 | 先用 DDD 找出**限界上下文**，再決定服務邊界 |
| 團隊不熟 DDD | 先從「把規則搬回 Entity」「用 Value Object 取代原始型別」開始，不必一次全套 |
