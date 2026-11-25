---
icon: lucide/network
---

# 系統設計

分散式系統的基礎理論、高可用與高效能設計，以及面試時如何有條理地回答系統設計題。

**核心技術**：CAP / BASE / 分散式事務 / 限流熔斷 / 分庫分表 / DDD / 六角架構

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["系統設計"])
    c0["01 · 基礎理論"]
    R --> c0
    p0("・CAP 理論<br>・ACID vs BASE")
    c0 --- p0
    c1["02 · 分散式系統核心"]
    R --> c1
    p1("・一致性模型<br>・分散式事務<br>・分散式鎖")
    c1 --- p1
    c2["03 · 高可用設計"]
    R --> c2
    p2("・限流<br>・熔斷<br>・降級（Fallback）策略")
    c2 --- p2
    c3["04 · 高效能設計"]
    R --> c3
    p3("・分庫分表<br>・緩存設計")
    c3 --- p3
    c4["05 · 架構設計"]
    R --> c4
    p4("・負載均衡<br>・微服務設計原則<br>・消息隊列使用場景")
    c4 --- p4
    c5["06 · 分層架構與 DDD"]
    R --> c5
    p5("・三層式架構<br>・六角架構<br>・DDD 核心概念<br>・怎麼選")
    c5 --- p5
    c6["07 · 系統設計面試答題框架"]
    R --> c6
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5,c6 chapter
    class p0,p1,p2,p3,p4,p5 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 基礎理論](theory.md)__

    ---

    分散式系統的所有設計取捨都源自 CAP 定理：網路分區不可避免時，只能在一致性與可用性之間選擇。

-   __[02 · 分散式系統核心](distributed.md)__

    ---

    資料分散在多個節點後，就無法再用單一資料庫交易保證一致性。

-   __[03 · 高可用設計](high-availability.md)__

    ---

    高可用的目標是「部分故障時整體仍能服務」。

-   __[04 · 高效能設計](high-performance.md)__

    ---

    當單一資料庫與單層快取撐不住流量時，就需要分庫分表與更完整的快取設計。

-   __[05 · 架構設計](architecture.md)__

    ---

    系統規模變大之後，流量分配、服務拆分與非同步溝通成為架構的核心問題。

-   __[06 · 分層架構與 DDD](ddd-architecture.md)__

    ---

    程式碼要如何分層，決定了系統能不能長期維護。

-   __[07 · 系統設計面試答題框架](interview-framework.md)__

    ---

    系統設計面試沒有標準答案，但有標準的思考順序。

</div>

## 重點速覽

### 核心理論
| 理論 | 說明 |
|------|------|
| **CAP 定理** | Consistency / Availability / Partition Tolerance，三者最多同時滿足兩個 |
| **BASE 理論** | Basically Available / Soft State / Eventually Consistent，最終一致性 |
| **PACELC 模型** | CAP 的延伸，考慮正常情況下延遲與一致性的取捨 |

### 高可用架構設計
用戶請求 → DNS 解析 → CDN 加速

- → Load Balancer（Nginx / HAProxy）
- → API Gateway（限流 / 認證 / 路由）
- → 微服務集群（Spring Cloud）
- → 快取層（Redis Cluster）
- → 資料庫（MySQL 主從 / 分庫分表）
- → 消息佇列（Kafka / RabbitMQ）

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
