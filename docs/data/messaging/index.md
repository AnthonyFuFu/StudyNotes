---
icon: lucide/send
---

# 訊息佇列

削峰填谷、非同步處理、服務解耦。比較 Kafka（分散式日誌）與 RabbitMQ（訊息中介）的原理與適用場景，並整理我在專案中的實作。

**核心技術**：Kafka / RabbitMQ / 投遞語意 / 冪等消費 / 死信佇列 / Spring Kafka / Spring AMQP

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["訊息佇列"])
    c0["01 · 核心概念：為什麼需要訊息佇列"]
    R --> c0
    p0("・三個典型用途<br>・代價<br>・投遞語意<br>・訊息不遺失的三個環節<br>・怎麼選")
    c0 --- p0
    c1["02 · Kafka"]
    R --> c1
    p1("・架構<br>・為什麼 Kafka 這麼快<br>・我的實作：搶票訂單非同步落地<br>・常用設定")
    c1 --- p1
    c2["03 · RabbitMQ"]
    R --> c2
    p2("・架構<br>・四種 Exchange<br>・我的實作：會員建立事件<br>・可靠性機制<br>・Kafka 與 RabbitMQ 對照")
    c2 --- p2
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2 chapter
    class p0,p1,p2 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 核心概念：為什麼需要訊息佇列](concepts.md)__

    ---

    訊息佇列解決削峰填谷、非同步處理與服務解耦三個問題，同時也帶來一致性與重複訊息的代價。

-   __[02 · Kafka](kafka.md)__

    ---

    Kafka 本質上是分散式的追加日誌，訊息消費後仍會保留、可以重播。

-   __[03 · RabbitMQ](rabbitmq.md)__

    ---

    RabbitMQ 的核心是 Exchange 路由：訊息先送到交換器，再依規則分派到佇列。

</div>

## Kafka 與 RabbitMQ 一覽

| | Kafka | RabbitMQ |
|---|-------|----------|
| 本質 | 分散式日誌，消費後保留、可重播 | 訊息中介，確認後刪除 |
| 吞吐量 | 極高 | 高 |
| 延遲 | 毫秒級 | 微秒到毫秒級 |
| 路由 | Topic + Partition | Direct / Topic / Fanout / Headers Exchange |
| 我的使用 | holidayDessert：搶票訂單削峰 | microservicecloud：會員事件解耦 |
