# 實戰：微服務專案與 K8s 部署

!!! abstract "專案：microservicecloud"

    Spring Boot 3 + Spring Cloud 的完整微服務練習：Eureka 叢集、OpenFeign、Gateway、Resilience4j、Config Server、RabbitMQ 事件驅動、Zipkin 鏈路追蹤、Prometheus + Grafana 監控；最後從 Docker Compose 一路部署到自己用 kubeadm 建的三節點 Kubernetes 叢集。

## 架構總覽

``` mermaid
flowchart TB
    U(["外部請求"]) --> GW["Gateway 9527<br>路由、統一入口"]
    GW -- "/api/consumer/**" --> CS["Consumer 9001"]
    GW -- "/api/member/**" --> PV["Provider 8001"]
    CS -- "OpenFeign + Resilience4j" --> PV
    PV --> DB[("MySQL")]
    PV -- "會員建立事件" --> MQ[("RabbitMQ")]
    MQ -- "非同步消費" --> CS
```

``` mermaid
flowchart LR
    subgraph INFRA ["基礎設施"]
        direction LR
        E1["Eureka 7001"] ~~~ E2["Eureka 7002"] ~~~ CFG["Config Server 8888"]
    end
    subgraph OBS ["可觀測性"]
        direction LR
        ZK["Zipkin 9411"] ~~~ PR["Prometheus 9090"] ~~~ GF["Grafana 3000"]
    end
```

| 服務 | 角色 |
|------|------|
| `eureka` | 註冊中心，7001 / 7002 互相註冊組成叢集 |
| `config` | 設定中心，所有服務的設定集中在 `config-repo/` |
| `gateway` | API 閘道，`lb://` 依服務名稱負載均衡 |
| `provider` | 會員服務，寫入 MySQL 並發送 RabbitMQ 事件 |
| `consumer` | 透過 OpenFeign 呼叫 provider，並監聽會員事件 |
| `api` | 共用的 DTO / Feign 介面模組 |

**學習順序**：Eureka 叢集 → OpenFeign → Gateway → Resilience4j → Config Server → Docker Compose → 鏈路追蹤與監控 → RabbitMQ → Kubernetes。

## Gateway 路由

``` properties
spring.cloud.gateway.routes[0].id=member-provider-route
spring.cloud.gateway.routes[0].uri=lb://MICROSERVICECLOUD-MEMBER
spring.cloud.gateway.routes[0].predicates[0]=Path=/api/member/**
spring.cloud.gateway.routes[0].filters[0]=StripPrefix=1
```

- `lb://服務名稱`：交給 Spring Cloud LoadBalancer 從 Eureka 找出實例並輪詢
- `StripPrefix=1`：轉發前去掉第一段路徑（`/api`）

## OpenFeign + 降級

``` java
@FeignClient(
    value = "MICROSERVICECLOUD-MEMBER",
    fallbackFactory = MemberFeignClientFallbackFactory.class   // 比 fallback 更好：拿得到例外原因
)
public interface MemberFeignClient {

    @GetMapping("/member/{id}")
    Member findById(@PathVariable("id") Long id);

    @GetMapping("/member/list")
    List<Member> findAll();
}
```

| | `fallback` | `fallbackFactory` |
|---|-----------|-------------------|
| 拿得到例外 | ❌ | ✅ 可依例外類型回不同結果、記錄日誌 |
| 建議 | 簡單示範 | ✅ 實務使用 |

Provider 停掉時，Consumer 不會一直卡在逾時，而是由 Resilience4j 熔斷後直接回傳降級資料（`服務暫時不可用（fallback）`）。

## RabbitMQ 事件驅動

``` mermaid
flowchart LR
    PV["Provider"] -- "member.created" --> EX{{"member.exchange"}} --> Q[("member.created<br>.queue")] --> CS["Consumer"]
```

新增會員後 Provider 只負責發事件，後續動作（通知、統計）由 Consumer 非同步處理，兩個服務**解耦**。詳見 [RabbitMQ](../../data/messaging/rabbitmq.md)。

## 可觀測性

- **鏈路追蹤**：Micrometer Tracing 自動在 HTTP / Feign 呼叫中傳遞 `traceId`，送到 Zipkin（開發環境取樣率 100%）
- **指標**：各服務開放 `/actuator/prometheus`，Prometheus 抓取後在 Grafana 匯入 JVM（4701）、Spring Boot（19004）儀表板

## 部署演進

``` mermaid
flowchart LR
    A["IDE 手動啟動"] --> B["Docker Compose"] --> C["Kubernetes"]
```

=== "Docker Compose"

    ``` bash
    mvn clean package -DskipTests
    docker-compose up -d --build
    ```

    - 用 `depends_on` + healthcheck 控制啟動順序（Eureka、Config、MySQL、RabbitMQ 先起來）
    - 容器之間用**服務名稱**互相連線，不需要改 hosts

=== "Kubernetes（kubeadm）"

    - VMware 上三台 CentOS Stream VM：1 master + 2 worker，容器執行環境用 **containerd**
    - `setup-k8s-master.sh` / `setup-k8s-worker.sh`：系統準備 → 安裝 K8s 套件 → `kubeadm init` / `kubeadm join`
    - `k8s/` 目錄依元件拆分 YAML：Namespace、ConfigMap、Secret、各服務 Deployment + Service、Prometheus、Grafana
    - 對外用 **NodePort** 開放 Gateway、Eureka、Zipkin、Grafana 等介面
    - Provider 設定 `replicas: 2` 與 `readinessProbe`，示範水平擴展與滾動更新

!!! warning "踩過的坑"

    - **冷開機後 Gateway 路由失效**：Gateway 比 Eureka 早就緒，拿到空的服務清單。`kubectl rollout restart deployment/gateway` 重啟即可；根本解法是加上 readinessProbe 並讓 Gateway 定期刷新服務清單。
    - **在 K8s 裡還要不要 Eureka？** K8s Service 已經提供服務發現與負載均衡，正式環境可以改用 Spring Cloud Kubernetes 或直接用 Service DNS，少維護一個元件。
