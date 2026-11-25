---
icon: lucide/network
---

# 系統設計

分散式系統的基礎理論、高可用與高效能設計，以及面試時如何有條理地回答系統設計題。

**核心技術**：CAP / BASE / 分散式事務 / 限流熔斷 / 分庫分表

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 基礎理論](theory.md)__

    ---

    CAP 理論 · ACID vs BASE

-   __[02 · 分散式系統核心](distributed.md)__

    ---

    一致性模型 · 分散式事務 · 分散式鎖

-   __[03 · 高可用設計](high-availability.md)__

    ---

    限流 · 熔斷 · 降級（Fallback）策略

-   __[04 · 高效能設計](high-performance.md)__

    ---

    分庫分表 · 緩存設計

-   __[05 · 架構設計](architecture.md)__

    ---

    負載均衡 · 微服務設計原則 · 消息隊列使用場景

-   __[06 · 系統設計面試答題框架](interview-framework.md)__

    ---

    系統設計面試答題框架

</div>

??? abstract "原始學習路線圖"

    ```
    系統設計
    ├── 1️⃣ 基礎理論（CAP / BASE / ACID）
    ├── 2️⃣ 分散式系統核心
    │   ├── 一致性模型
    │   ├── 分散式事務
    │   └── 分散式鎖
    ├── 3️⃣ 高可用設計
    │   ├── 限流（Rate Limiting）
    │   ├── 熔斷（Circuit Breaker）
    │   └── 降級（Fallback）
    ├── 4️⃣ 高效能設計
    │   ├── 分庫分表
    │   ├── 讀寫分離
    │   └── 緩存設計
    └── 5️⃣ 架構設計
        ├── 負載均衡
        ├── 微服務設計原則
        └── 消息隊列使用場景
    ```

## 重點速覽

### 核心理論
| 理論 | 說明 |
|------|------|
| **CAP 定理** | Consistency / Availability / Partition Tolerance，三者最多同時滿足兩個 |
| **BASE 理論** | Basically Available / Soft State / Eventually Consistent，最終一致性 |
| **PACELC 模型** | CAP 的延伸，考慮正常情況下延遲與一致性的取捨 |

### 高可用架構設計
```
用戶請求 → DNS 解析 → CDN 加速
    → Load Balancer（Nginx / HAProxy）
    → API Gateway（限流 / 認證 / 路由）
    → 微服務集群（Spring Cloud）
    → 快取層（Redis Cluster）
    → 資料庫（MySQL 主從 / 分庫分表）
    → 消息佇列（Kafka / RabbitMQ）
```

### 掌握重點
- ✅ **分散式事務**：2PC / TCC / SAGA / 本地消息表
- ✅ **限流策略**：令牌桶、漏桶、滑動視窗（Sentinel 實作）
- ✅ **熔斷降級**：Resilience4j / Sentinel 原理與實作
- ✅ **分庫分表**：垂直切分 / 水平切分 / ShardingSphere
- ✅ **一致性 Hash**：解決分散式節點增減的資料分布問題
- ✅ **消息佇列**：Kafka 高吞吐量原理（Partition / Consumer Group / 冪等性）

## 核心要點總結

| 主題 | 核心知識點 |
|------|-----------|
| **CAP/BASE** | 分散式不可能三角，BASE 是妥協方案 |
| **分散式事務** | 2PC（強一致）/ TCC / SAGA / 本地消息表（最終一致）|
| **分散式鎖** | Redis + Lua 保證原子性，Redisson Watch Dog 自動續期 |
| **限流** | 令牌桶（允許突發）/ 漏桶（穩定輸出）/ 滑動窗口 |
| **熔斷** | Closed → Open → Half-Open 狀態機 |
| **緩存** | 穿透（布隆過濾器）/ 雪崩（隨機 TTL）/ 擊穿（互斥鎖）|
| **分庫分表** | 垂直切分（按業務）/ 水平切分（按數據量）|
