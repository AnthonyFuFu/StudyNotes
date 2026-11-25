---
icon: lucide/cloud-cog
---

# AWS 雲端服務

公司正式環境使用的雲端平台。從區域、IAM、VPC 的基礎架構開始，到運算與容器服務、儲存與資料庫，最後是監控、安全與成本控制；並對照我在 holidayDessert 中實作的 S3 分片上傳。

**核心技術**：Region / AZ / IAM / VPC / EC2 / ALB / ECS / EKS / Lambda / S3 / RDS / ElastiCache / CloudWatch / Secrets Manager

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["AWS 雲端服務"])
    c0["01 · 基礎架構：區域、IAM 與 VPC"]
    R --> c0
    p0("・全球基礎設施<br>・IAM：誰可以對什麼做什麼<br>・VPC：自己的私有網路")
    c0 --- p0
    c1["02 · 運算與部署：EC2、ECS、EKS、Lambda"]
    R --> c1
    p1("・運算服務怎麼選<br>・EC2<br>・容器：ECR、ECS、EKS<br>・Lambda：無伺服器<br>・部署策略")
    c1 --- p1
    c2["03 · 儲存與資料庫：S3、RDS、ElastiCache"]
    R --> c2
    p2("・S3：物件儲存<br>・我的實作：Multipart Upload 邊讀邊傳<br>・RDS / Aurora：託管關聯式資料庫<br>・ElastiCache：託管 Redis<br>・其他常見服務")
    c2 --- p2
    c3["04 · 維運、安全與成本"]
    R --> c3
    p3("・可觀測性<br>・祕密與加密<br>・安全檢查清單<br>・基礎設施即程式碼<br>・成本控制")
    c3 --- p3
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3 chapter
    class p0,p1,p2,p3 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · 基礎架構：區域、IAM 與 VPC](foundation.md)__

    ---

    全球基礎設施 · IAM：誰可以對什麼做什麼 · VPC：自己的私有網路

-   __[02 · 運算與部署：EC2、ECS、EKS、Lambda](compute.md)__

    ---

    運算服務怎麼選 · EC2 · 容器：ECR、ECS、EKS · Lambda：無伺服器 …

-   __[03 · 儲存與資料庫：S3、RDS、ElastiCache](storage-database.md)__

    ---

    S3：物件儲存 · 我的實作：Multipart Upload 邊讀邊傳 · RDS / Aurora：託管關聯式資料庫 · ElastiCache：託管 Redis …

-   __[04 · 維運、安全與成本](operations-security.md)__

    ---

    可觀測性 · 祕密與加密 · 安全檢查清單 · 基礎設施即程式碼 …

</div>

## 服務地圖

| 類別 | 服務 | 對應的開源 / 自建方案 |
|------|------|---------------------|
| 身分與權限 | IAM、IAM Identity Center | LDAP、Keycloak |
| 網路 | VPC、ALB / NLB、Route 53、CloudFront | Nginx、自建 DNS、CDN |
| 運算 | EC2、Lambda | 實體機、VM |
| 容器 | **ECR**、ECS、**EKS** | **Harbor**、自建 Kubernetes |
| 儲存 | **S3**、EBS、EFS | MinIO、NFS |
| 資料庫 | RDS / Aurora、ElastiCache、DynamoDB | MySQL、Redis 自建 |
| 訊息 | SQS / SNS、MSK | RabbitMQ、Kafka |
| 監控 | CloudWatch、X-Ray、CloudTrail | Prometheus、Zipkin |
| 祕密 | Secrets Manager、KMS | Vault、Jasypt |

!!! example "我的實作：holidayDessert 的 S3"

    AWS SDK v2 `S3Client`：大於 20MB 的檔案以 **Multipart Upload 邊讀邊傳**，失敗時 Abort 清除殘留分片；下載用 **Pre-signed URL**，Bucket 保持私有。詳見[儲存與資料庫](storage-database.md)。

!!! tip "與 CI/CD 的關係"

    映像存在 ECR 或 [Harbor](../cicd/harbor.md)、部署到 EKS、由 [Argo CD](../cicd/argocd.md) 以 GitOps 方式同步，這是目前最常見的 AWS 容器化部署組合。
