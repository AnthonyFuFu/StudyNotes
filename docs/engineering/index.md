---
icon: lucide/wrench
---

# 工程實踐

讓程式碼可靠地交付到生產環境並持續運作：自動化測試、CI/CD 流水線（含 Harbor 與 Argo CD）、AWS 雲端服務，以及監控與可觀測性。

<div class="grid cards" markdown>

-   __[測試](testing/index.md)__

    ---

    測試金字塔與各層測試工具，從 JUnit 5、Mockito 到 Spring Boot Test、Testcontainers 與 TDD 實戰。

    `6 章` · JUnit 5 / Mockito / Testcontainers / TDD

-   __[CI/CD 與 DevOps](cicd/index.md)__

    ---

    DevOps 核心概念、Docker 與 Kubernetes 深入、Jenkins / GitHub Actions 流水線、Helm 部署，再到企業常見的 **Harbor 私有映像倉庫**與 **Argo CD GitOps**，最後整理我在各專案中實際建立的流水線。

    `8 章` · Docker / Kubernetes / Jenkins / GitHub Actions / Helm / Harbor / Argo CD / Argo Rollouts / GHCR / kubeadm

-   __[AWS 雲端服務](aws/index.md)__

    ---

    公司正式環境使用的雲端平台。從區域、IAM、VPC 的基礎架構開始，到運算與容器服務、儲存與資料庫，最後是監控、安全與成本控制；並對照我在 holidayDessert 中實作的 S3 分片上傳。

    `4 章` · Region / AZ / IAM / VPC / EC2 / ALB / ECS / EKS / Lambda / S3 / RDS / ElastiCache / CloudWatch / Secrets Manager

-   __[監控與可觀測性](monitoring/index.md)__

    ---

    Metrics、Logs、Traces 三大支柱，以及 Prometheus、Grafana、ELK、鏈路追蹤如何組成完整的可觀測性平台。

    `6 章` · Prometheus / Grafana / ELK / SkyWalking / SLO

</div>

## 從程式碼到正式環境

``` mermaid
flowchart LR
    T["測試<br>JUnit / Testcontainers"] --> CI["CI<br>Jenkins / GitHub Actions"] --> H[("Harbor<br>映像倉庫")] --> A["Argo CD<br>GitOps"] --> K["AWS EKS<br>Kubernetes"]
```

``` mermaid
flowchart LR
    K["正式環境"] --> M["監控<br>Prometheus / Grafana"] --> L["日誌與追蹤<br>ELK / Zipkin"] --> F(["回饋到下一次開發"])
```
