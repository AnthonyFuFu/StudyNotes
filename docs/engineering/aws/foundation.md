# 基礎架構：區域、IAM 與 VPC

!!! abstract "本章重點"

    所有 AWS 架構都建立在 Region / AZ、IAM 權限與 VPC 網路之上。本章說明責任共擔模型、IAM 的最小權限與「不要把 Access Key 寫進程式」，以及三層式 VPC 與 Security Group 的設計。

## 全球基礎設施

``` mermaid
flowchart TB
    R["Region 區域<br>例：ap-northeast-1 東京"] --> AZ1["AZ-a<br>獨立機房群"] & AZ2["AZ-c"] & AZ3["AZ-d"]
    EDGE["Edge Location<br>CloudFront / Route 53"] -.->|"就近服務使用者"| R
```

| 概念 | 說明 | 設計原則 |
|------|------|---------|
| **Region** | 一個地理區域，彼此完全獨立 | 依使用者位置、法規（資料落地）、服務是否提供、價格選擇 |
| **Availability Zone（AZ）** | 區域內的獨立機房群，電力、網路分開，彼此低延遲互連 | 正式環境**至少跨 2 個 AZ**，單一 AZ 故障不影響服務 |
| **Edge Location** | 全球數百個節點 | CloudFront CDN、Route 53 DNS 就近回應 |

!!! info "責任共擔模型（Shared Responsibility）"

    - **AWS 負責**：雲端「本身」的安全（機房、硬體、虛擬化層、託管服務的底層）
    - **你負責**：雲端「裡面」的安全（IAM 權限、網路設定、作業系統修補、資料加密、應用程式漏洞）

    越託管的服務（S3、Lambda、RDS），你要負責的範圍越小。

## IAM：誰可以對什麼做什麼

| 元件 | 用途 | 實務建議 |
|------|------|---------|
| **Root 帳號** | 建立帳號時的最高權限 | 只用來設定帳單與緊急情況，**開啟 MFA 後鎖起來** |
| **User** | 代表一個人 | 改用 IAM Identity Center（SSO）集中管理 |
| **Group** | 一群 User 共用權限 | 依職能分組：Developer、Ops、ReadOnly |
| **Role** | **給服務或臨時身分用**，沒有長期密碼 | EC2、ECS Task、Lambda、EKS Pod 一律用 Role |
| **Policy** | JSON 權限文件 | 遵守**最小權限原則** |

``` json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"],
    "Resource": "arn:aws:s3:::holiday-dessert-upload/*"
  }]
}
```

!!! danger "不要把 Access Key 寫進程式碼"

    最常見的資安事故就是把 `AWS_ACCESS_KEY_ID` / `SECRET` 推上 GitHub，幾分鐘內就會被掃到拿去挖礦。

    | 執行環境 | 正確做法 |
    |---------|---------|
    | EC2 | Instance Profile（Role） |
    | ECS / Fargate | Task Role |
    | EKS | IRSA 或 EKS Pod Identity |
    | GitHub Actions / Jenkins | **OIDC** 換取臨時憑證，不存長期金鑰 |
    | 本機開發 | `aws sso login` 取得短期憑證 |

    AWS SDK 的**預設憑證鏈**會依序找環境變數、設定檔、Role，程式碼裡完全不需要寫金鑰。

## VPC：自己的私有網路

``` mermaid
block-beta
    columns 3
    block:net:3
        columns 3
        space igw["Internet Gateway"] space
    end
    block:pub:3
        columns 3
        pt["Public Subnet（每個 AZ 一個）"]:3
        alb["ALB 負載平衡器"] nat["NAT Gateway"] ssm["SSM / Bastion"]
    end
    block:app:3
        columns 3
        at["Private Subnet：應用層"]:3
        ec2["EC2"] ecs["ECS / Fargate"] eks["EKS 節點"]
    end
    block:data:3
        columns 3
        dt["Private Subnet：資料層"]:3
        rds[("RDS / Aurora")] cache[("ElastiCache")] os[("OpenSearch")]
    end
    classDef title fill:transparent,stroke:transparent,font-weight:bold
    class pt,at,dt title
    style net fill:transparent,stroke:transparent
    style pub fill:transparent
    style app fill:transparent
    style data fill:transparent
```

外部流量只會經過 Internet Gateway 進到 Public Subnet 的 ALB；應用層與資料層都在 Private Subnet，對外連線經由 NAT Gateway。

| 元件 | 作用 |
|------|------|
| **Subnet** | VPC 內的網段，綁定單一 AZ。Public 有路由到 Internet Gateway，Private 沒有 |
| **Route Table** | 決定封包往哪裡送 |
| **Internet Gateway** | 讓 Public Subnet 能雙向連網 |
| **NAT Gateway** | 讓 Private Subnet **能出去、不能被連進來**（下載套件、呼叫外部 API） |
| **VPC Endpoint** | 不經過網際網路直接存取 S3、ECR 等 AWS 服務，省 NAT 流量費也更安全 |

### Security Group 與 NACL

| | Security Group | Network ACL |
|---|----------------|-------------|
| 作用層級 | ENI（執行個體） | Subnet |
| 狀態 | **有狀態**：允許進來的連線，回應自動放行 | **無狀態**：進出都要各自設規則 |
| 規則 | 只有 Allow | Allow 與 Deny，依編號順序比對 |
| 常見用法 | **主要的防線**，可以引用其他 SG | 封鎖特定 IP 段的額外防線 |

!!! tip "用 Security Group 互相引用取代 IP"

    資料庫的 SG 入站規則設定「來源 = 應用層的 SG」，而不是寫死 IP。應用程式擴縮容、IP 改變都不用改規則。

**三層式架構的原則**：只有負載平衡器在 Public Subnet；應用程式與資料庫都在 Private Subnet；維運登入改用 **SSM Session Manager**，不開 22 port。
