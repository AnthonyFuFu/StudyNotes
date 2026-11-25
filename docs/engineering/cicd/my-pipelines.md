# 實戰：我的 CI/CD 與 K8s 部署

!!! abstract "本章重點"

    本章整理我在各專案中實際建立的流水線：GitHub Actions 服務容器整合測試、映像推送 GHCR、Electron 三平台打包，以及用 kubeadm 自建 Kubernetes 叢集部署微服務。

前面章節介紹的是通用概念，這一章整理我在各專案中實際建立的流水線與部署方式。

## 各專案的 CI 一覽

| 專案 | 觸發 | 流程 | 產出 |
|------|------|------|------|
| **holidayDessert** | push `master` / `pre-production` / `production`、PR | 啟動 MySQL + Redis 服務容器 → 載入 SQL → 測試 → 打包 → Docker build | 映像推送到 **GHCR** |
| **stock-observation** | push、PR `master` | `./mvnw test` → `./mvnw package` | JAR |
| **holiday_dessert_vue** | push、PR | `npm ci` → `npm run build` | 靜態檔 |
| **fu-clan-management-system** | push `master`、PR、手動 | ESLint → Prettier → 型別檢查 → Vitest → 三平台 matrix 打包 | `.exe` / `.dmg` / `.AppImage`（保留 30 天） |
| **StudyNotes** | push `master` | `zensical build` | 部署到 **GitHub Pages** |

## holidayDessert：用服務容器跑整合測試

``` yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write                    # 推送映像到 GHCR 需要
    services:                            # 與 job 一起啟動的容器
      mysql:
        image: mysql:8.0
        ports: [ "3306:3306" ]
        options: >-
          --health-cmd="mysqladmin ping -h localhost"
          --health-interval=10s --health-retries=10
      redis:
        image: redis:7
        ports: [ "6379:6379" ]
        options: --health-cmd="redis-cli ping"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '17', distribution: 'temurin' }
      # 載入 SQL → mvn test（略過需要完整環境的搶票整合測試）→ 打包 → docker build & push
```

``` mermaid
flowchart LR
    A["Checkout"] --> B["MySQL + Redis<br>服務容器就緒"] --> C["載入<br>初始化 SQL"] --> D["Maven 測試"] --> E["Docker build<br>推送 GHCR"]
```

!!! tip "為什麼用 `services` 而不是 Mock"

    搶票、快取這類邏輯的正確性**取決於真實的 Redis 與 MySQL 行為**（Lua 原子性、條件式 UPDATE）。用服務容器跑測試最接近正式環境；本機則可以用 Testcontainers 達到相同效果。

!!! warning "密碼不要寫在 workflow 裡"

    CI 用的資料庫密碼、雲端金鑰要放在 **GitHub Secrets**，以 `${{ secrets.XXX }}` 引用；`docker-compose.yml` 中的範例密碼也只適合本機開發。

## 映像與部署

``` mermaid
flowchart LR
    CI["GitHub Actions"] -- "docker push" --> GHCR[("ghcr.io/…/holidaydessert")]
    GHCR -- "docker compose pull" --> SRV["伺服器<br>App + MySQL + Redis"]
```

- `docker-compose.yml` 一次啟動應用程式、MySQL 8.0、Redis 7，用自訂 bridge 網路以服務名稱互連
- MySQL 掛載 volume 保存資料，並把初始化 SQL 放進 `docker-entrypoint-initdb.d/`，第一次啟動自動建表

## microservicecloud：自建 Kubernetes 叢集

``` mermaid
flowchart TB
    subgraph CP ["master"]
        direction LR
        API["kube-apiserver"] ~~~ ETCD[("etcd")] ~~~ SCH["scheduler / controller"]
    end
    CP --> N1 & N2
    subgraph N1 ["node1"]
        K1["kubelet + containerd"]
    end
    subgraph N2 ["node2"]
        K2["kubelet + containerd"]
    end
```

| 步驟 | 內容 |
|------|------|
| ① 系統準備 | 三台 VM（各 2 vCPU / 4GB），關閉 swap、設定核心模組與網路參數 |
| ② 容器執行環境 | 安裝 **containerd**（K8s 1.24 之後已移除 dockershim） |
| ③ 建立叢集 | master `kubeadm init`，安裝 CNI 網路外掛；worker `kubeadm join` |
| ④ 建置映像 | 在 master 上 `build-images.sh` 打包各服務映像 |
| ⑤ 部署 | `deploy.sh` 依序套用 Namespace → ConfigMap / Secret → 基礎設施 → 各服務 |

**YAML 依元件拆分**：`namespace.yml`、`configmap.yml`、`secret.yml`、`mysql.yml`、`rabbitmq.yml`、`eureka.yml`、`config-server.yml`、`provider.yml`、`consumer.yml`、`gateway.yml`、`zipkin.yml`、`prometheus-*.yml`、`grafana.yml`。

!!! info "Docker Compose 與 Kubernetes 的差別"

    | | Docker Compose | Kubernetes |
    |---|----------------|-----------|
    | 範圍 | 單機 | 多節點叢集 |
    | 自癒 | `restart: always` | Pod 掛掉自動重建、節點掛掉自動遷移 |
    | 擴展 | 手動調整 | `replicas`、HPA 自動擴縮 |
    | 更新 | 停掉再啟動 | 滾動更新、回滾 |
    | 學習成本 | 低 | 高 |

## 程式碼品質

- **SonarQube**：holidayDessert 與 AnthonyFu-Learning 都有 `sonar-project.properties`，可在 CI 中加入靜態分析步驟
- **前端**：ESLint + Prettier 在 CI 中檢查，格式不符就讓流水線失敗
