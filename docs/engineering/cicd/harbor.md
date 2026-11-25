# Harbor 私有映像倉庫

Harbor 是 CNCF 畢業專案的**企業級容器映像倉庫**。Docker Hub 適合公開映像；公司內部的映像需要放在自己能控管的地方，並且要能掃描漏洞、控管權限、同步到多個機房。

## 為什麼需要私有倉庫

| 需求 | Docker Hub / 純 Registry | Harbor |
|------|-------------------------|--------|
| 內網部署、資料不出公司 | ❌ / ✅ | ✅ |
| 專案隔離 + RBAC 權限 | ❌ | ✅ |
| 漏洞掃描、阻擋有高風險漏洞的映像 | 部分付費 | ✅ 內建 Trivy |
| 映像簽章驗證 | ❌ | ✅ Cosign / Notation |
| 多機房 / 多雲同步 | ❌ | ✅ 複製規則 |
| 自動清理舊映像 | ❌ | ✅ 保留政策 |
| 代理快取外部映像（避免 Docker Hub 限流） | ❌ | ✅ Proxy Cache 專案 |
| 稽核紀錄 | ❌ | ✅ |

## 架構

``` mermaid
flowchart TB
    U(["docker / helm / kubelet"]) --> PX["Nginx Proxy"]
    PX --> CORE["Core<br>API、權限、Webhook"]
    PX --> REG["Registry<br>儲存映像層"]
    CORE --> JS["Job Service<br>複製、清理、掃描排程"]
    CORE --> TV["Trivy<br>漏洞掃描"]
    CORE --> DB[("PostgreSQL")]
    CORE --> RD[("Redis")]
    REG --> ST[("儲存後端<br>檔案系統 / S3")]
```

| 元件 | 職責 |
|------|------|
| **Core** | 驗證、專案與權限、API、觸發 Webhook |
| **Registry** | 實際存放映像（基於 CNCF Distribution） |
| **Job Service** | 非同步工作：複製、垃圾回收、保留政策、掃描 |
| **Trivy** | 掃描映像中 OS 套件與語言相依套件的 CVE |
| **PostgreSQL / Redis** | 中繼資料與快取 |
| 儲存後端 | 本機磁碟、NFS，或 **S3** 等物件儲存 |

## 核心功能

### 專案與權限

- 映像以**專案**分組：`harbor.company.com/<project>/<repository>:<tag>`
- 角色：專案管理員、維護者、開發者（可推送）、訪客（只能拉取）
- 整合 **LDAP / AD 或 OIDC**，用公司帳號登入
- **Robot Account**：給 CI / K8s 用的機器帳號，權限只限定某個專案的 push / pull，可設定到期日

### 漏洞掃描與部署阻擋

``` mermaid
flowchart LR
    P["CI 推送映像"] --> S["推送時自動掃描<br>Trivy"] --> C{"有 Critical / High<br>漏洞？"}
    C -->|"有"| B["阻擋拉取<br>（Prevent vulnerable images）"]
    C -->|"沒有"| OK["允許部署"]
```

專案設定可以開啟「**推送時自動掃描**」與「**阻擋嚴重度高於某等級的映像被拉取**」，讓有漏洞的映像根本部署不上 K8s。

### 其他

| 功能 | 說明 |
|------|------|
| **Tag 不可變** | 例如 `v*` 的 tag 一旦推送就不能被覆蓋，確保 `v1.2.0` 永遠是同一個映像 |
| **保留政策** | 每個 repository 只保留最近 N 個 tag，搭配**垃圾回收**真正釋放空間 |
| **複製** | 推送到總部 Harbor 後，自動同步到其他機房或雲端倉庫（ECR 等） |
| **Proxy Cache** | 代理 Docker Hub、GHCR，第一次拉取後快取，內網機器不必直連外網 |
| **OCI Artifact** | 除了映像，也能存 **Helm Chart**、簽章、SBOM |
| **Webhook** | 推送、掃描完成時通知 Jenkins、Slack，或觸發下一步部署 |

## 與 CI / K8s 整合

=== "CI 推送"

    ``` bash
    # 用 Robot Account 登入（帳密存在 CI 的 Secret）
    echo "$HARBOR_ROBOT_TOKEN" | docker login harbor.company.com -u 'robot$order-ci' --password-stdin

    # tag 用 Git commit SHA，可追溯到原始碼
    docker build -t harbor.company.com/order/order-service:${GIT_SHA} .
    docker push harbor.company.com/order/order-service:${GIT_SHA}

    # Helm Chart 也推到 Harbor（OCI）
    helm push order-service-1.4.0.tgz oci://harbor.company.com/charts
    ```

=== "K8s 拉取"

    ``` bash
    kubectl create secret docker-registry harbor-pull \
      --docker-server=harbor.company.com \
      --docker-username='robot$order-pull' \
      --docker-password="$TOKEN" -n order
    ```

    ``` yaml
    spec:
      imagePullSecrets:
        - name: harbor-pull
      containers:
        - name: order-service
          image: harbor.company.com/order/order-service:3f2a9c1
    ```

!!! warning "常見問題"

    - **自簽憑證**：Docker / containerd 會拒絕連線，要把公司 CA 加到每個節點的信任清單（`/etc/containerd/certs.d/`）
    - **刪除 tag 後空間沒有變小**：只是刪除參照，要執行**垃圾回收**才會真正清掉映像層
    - **不要用 `latest`**：同一個 tag 會指向不同映像，K8s 也可能不重新拉取；用 commit SHA 或語意化版本

## Harbor 與其他倉庫

| | Harbor | AWS ECR | GHCR | Docker Hub |
|---|--------|---------|------|-----------|
| 部署 | 自建（內網 / 任何雲） | AWS 託管 | GitHub 託管 | SaaS |
| 漏洞掃描 | Trivy 內建 | Inspector | Dependabot（相依套件） | 付費方案 |
| 權限 | 專案 RBAC + Robot Account | IAM | GitHub 權限 | 組織 / 團隊 |
| 適合 | 企業內網、混合雲、多機房 | 全在 AWS 上 | 開源、個人專案 | 公開映像 |
| 我的使用 | 公司 | — | holidayDessert | — |
