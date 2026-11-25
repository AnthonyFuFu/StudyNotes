# 維運、安全與成本

!!! abstract "本章重點"

    雲端環境上線後，監控、祕密管理與成本控制同樣重要。本章整理 CloudWatch、CloudTrail、Secrets Manager、KMS 的用途，一份安全檢查清單、IaC 工具比較，以及常見的成本陷阱。

## 可觀測性

| 服務 | 用途 | 對應開源工具 |
|------|------|-------------|
| **CloudWatch Metrics** | CPU、記憶體、自訂指標、告警 | Prometheus + Alertmanager |
| **CloudWatch Logs** | 集中日誌、Logs Insights 查詢 | ELK |
| **X-Ray** | 分散式追蹤 | Zipkin / SkyWalking |
| **CloudTrail** | **誰在什麼時間呼叫了哪個 AWS API**（稽核） | — |
| **Managed Prometheus / Grafana** | 託管版的 Prometheus 與 Grafana | 直接沿用 [監控與可觀測性](../monitoring/index.md) 的知識 |

!!! tip "CloudTrail 一定要開"

    帳號被入侵、資源被誤刪時，CloudTrail 是唯一能追查「是誰、從哪裡、做了什麼」的紀錄。建議開啟整個組織的 Trail 並寫進獨立帳號的 S3。

## 祕密與加密

| 服務 | 用途 |
|------|------|
| **Secrets Manager** | 存資料庫密碼、API Key，支援**自動輪替**（RDS 密碼可定期自動更換） |
| **SSM Parameter Store** | 存一般設定與少量祕密，標準版免費 |
| **KMS** | 管理加密金鑰；S3、EBS、RDS 的靜態加密都由 KMS 金鑰保護 |
| **ACM** | 免費 TLS 憑證，自動續期，掛在 ALB / CloudFront 上 |

``` mermaid
flowchart LR
    APP["應用程式<br>（IAM Role）"] -- "GetSecretValue" --> SM["Secrets Manager"]
    SM -- "用 KMS 解密" --> KMS["KMS"]
    APP -- "拿到密碼後連線" --> RDS[("RDS")]
```

這取代了 holidayDessert 用 **Jasypt** 加密設定檔的做法：密碼不再存在任何設定檔裡，而是執行時向 Secrets Manager 取得，權限由 IAM 控制，存取紀錄進 CloudTrail。

## 安全檢查清單

- ✅ Root 帳號開 MFA、不建 Access Key
- ✅ 人員用 IAM Identity Center（SSO），服務用 Role，CI 用 OIDC
- ✅ S3 保持 Block Public Access，對外用 CloudFront + OAC
- ✅ 資料庫、應用程式放 Private Subnet，Security Group 互相引用
- ✅ 開啟 CloudTrail、GuardDuty（威脅偵測）、Security Hub（合規檢查）
- ✅ EBS、RDS、S3 開啟 KMS 加密
- ✅ 用 AWS WAF 擋 SQL 注入、XSS 等常見攻擊（對應 [常見攻擊防禦](../../network-security/security/attack-defense.md)）

## 基礎設施即程式碼（IaC）

| 工具 | 特色 |
|------|------|
| **Terraform** | 多雲通用、生態最大，狀態存在 S3 + DynamoDB 鎖 |
| **CloudFormation** | AWS 原生 YAML / JSON |
| **AWS CDK** | 用 TypeScript / Java 撰寫，產生 CloudFormation |

!!! info "為什麼要用 IaC"

    在主控台點出來的環境無法重現、無法審查、也不知道誰改過。IaC 讓基礎設施跟程式碼一樣走 **Pull Request → Review → 自動套用**，這也是 [Argo CD](../cicd/argocd.md) 的 GitOps 精神。

## 成本控制

| 做法 | 效果 |
|------|------|
| 設定 **AWS Budgets** 告警 | 費用超過門檻立即通知 |
| 加上資源標籤（`Project`、`Env`、`Owner`） | 在 Cost Explorer 中依專案拆分費用 |
| 穩定負載買 **Savings Plans** | 省 30% \~ 70% |
| 批次、CI Runner 用 **Spot** | 省到 90% |
| 開發環境下班自動關機 | 用 EventBridge 排程 + Lambda |
| 注意 **NAT Gateway 與跨 AZ 流量費** | 常見的隱藏成本；存取 S3 / ECR 改走 VPC Endpoint |
| 改用 Graviton（ARM）執行個體 | 同等效能約便宜 20% |

## Well-Architected 六大支柱

| 支柱 | 核心問題 |
|------|---------|
| 卓越營運 | 部署、監控、事件處理是否自動化？ |
| 安全性 | 權限是否最小化？資料是否加密？ |
| 可靠性 | 單一 AZ 故障時服務還在嗎？能自動恢復嗎？ |
| 效能效率 | 選對執行個體類型與服務了嗎？ |
| 成本最佳化 | 有沒有閒置資源？用了正確的計費方式嗎？ |
| 永續性 | 資源使用率是否夠高？ |
