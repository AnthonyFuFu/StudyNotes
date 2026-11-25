# 微服務核心概念

## 單體 vs 微服務

=== "單體架構 Monolith"

    ``` mermaid
    flowchart TB
        subgraph MONO ["單體應用"]
            direction LR
            U["用戶模組"]
            O["訂單模組"]
            P["商品模組"]
        end
        MONO --> DB[("資料庫（共用）")]
    ```

    - ✅ 開發簡單、部署方便、本地調用快
    - ❌ 模組耦合、任一模組出問題全掛、無法獨立擴容

=== "微服務架構 Microservices"

    ``` mermaid
    flowchart TB
        C(["客戶端"]) --> GW["API Gateway"]
        GW --> U["用戶服務"] & O["訂單服務"] & P["商品服務"]
        U --> UDB[("DB：用戶")]
        O --> ODB[("DB：訂單")]
        P --> PDB[("DB：商品")]
    ```

    - ✅ 獨立部署、獨立擴容、技術棧靈活
    - ❌ 分散式複雜度、網路開銷、分散式事務

## Spring Cloud 生態全覽

```
組件                    功能                    替代方案
────────────────────────────────────────────────────────
Nacos                  服務發現 + 配置中心      Eureka + Config
OpenFeign              聲明式 HTTP 客戶端       RestTemplate
Spring Cloud Gateway   API 閘道               Zuul
Sentinel               限流 / 熔斷 / 降級      Hystrix / Resilience4j
Sleuth + Zipkin        分散式鏈路追蹤           SkyWalking
Spring Cloud Stream    消息驅動               直接用 Kafka/RabbitMQ
Seata                  分散式事務              TCC / SAGA 手動實作
```

```xml
<!-- pom.xml（Spring Cloud + Alibaba 依賴管理）-->
<properties>
    <spring-boot.version>3.2.0</spring-boot.version>
    <spring-cloud.version>2023.0.0</spring-cloud.version>
    <spring-cloud-alibaba.version>2023.0.0.0</spring-cloud-alibaba.version>
</properties>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>${spring-cloud.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>${spring-cloud-alibaba.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```
