---
icon: lucide/database
---

# 資料與訊息

後端系統倚賴的資料基礎設施：關聯式資料庫 MySQL、記憶體快取 Redis、全文搜尋 Elasticsearch，以及非同步溝通的訊息佇列 Kafka 與 RabbitMQ。

<div class="grid cards" markdown>

-   __[MySQL 深度優化](mysql/index.md)__

    ---

    索引原理、執行計劃、事務與鎖、主從複製到分庫分表，建立完整的 MySQL 調優思路。

    `6 章` · B+樹索引 / MVCC / 主從複製 / 分庫分表 / 雪花算法

-   __[Redis 深度](redis/index.md)__

    ---

    資料結構的底層編碼、持久化與淘汰策略，以及分散式鎖、緩存三大問題、熱 Key / 大 Key 等實戰議題。

    `9 章` · 資料結構底層 / 持久化 / 分散式鎖 / 緩存問題 / Cluster

-   __[Elasticsearch](elasticsearch/index.md)__

    ---

    從倒排索引與分詞原理出發，掌握 DSL 查詢、Spring Boot 整合與生產環境調優。

    `5 章` · 倒排索引 / DSL 查詢 / 聚合 / ELK Stack

-   __[訊息佇列](messaging/index.md)__

    ---

    削峰填谷、非同步處理、服務解耦。比較 Kafka（分散式日誌）與 RabbitMQ（訊息中介）的原理與適用場景，並整理我在專案中的實作。

    `3 章` · Kafka / RabbitMQ / 投遞語意 / 冪等消費 / 死信佇列 / Spring Kafka / Spring AMQP

</div>

!!! info "我用過的資料庫"

    | 資料庫 | 存取方式 | 專案 |
    |--------|---------|------|
    | MySQL 8 / MariaDB | Spring Data JPA、JdbcTemplate | holidayDessert、microservicecloud |
    | PostgreSQL / H2 | R2DBC（反應式） | stock-observation |
    | SQL Server | EF Core（DB-First） | chineseArtwork |
    | SQLite | sql.js（WebAssembly） | fu-clan-management-system |
    | Redis 7 | Lua Script、分散式鎖 | holidayDessert |
    | OpenSearch | High Level REST Client + Logstash 同步 | holidayDessert |
