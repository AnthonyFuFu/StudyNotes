---
icon: lucide/container
---

# CI/CD 與 DevOps

DevOps 核心概念、Docker 與 Kubernetes 深入、Jenkins / GitHub Actions 流水線、Helm 部署，再到企業常見的 **Harbor 私有映像倉庫**與 **Argo CD GitOps**，最後整理我在各專案中實際建立的流水線。

**核心技術**：Docker / Kubernetes / Jenkins / GitHub Actions / Helm / Harbor / Argo CD / Argo Rollouts / GHCR / kubeadm

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["CI/CD 與 DevOps"])
    c0["01 · DevOps 核心概念"]
    R --> c0
    p0("・什麼是 DevOps？<br>・CI/CD 流水線<br>・DevOps 工具鏈全覽")
    c0 --- p0
    c1["02 · Docker 深入"]
    R --> c1
    p1("・Docker 核心原理<br>・Dockerfile 最佳實踐<br>・Docker Compose<br>・Docker 網路")
    c1 --- p1
    c2["03 · Kubernetes 深入"]
    R --> c2
    p2("・K8s 整體架構<br>・核心資源對象<br>・滾動更新與回滾<br>・StatefulSet")
    c2 --- p2
    c3["04 · Jenkins + GitHub Actions"]
    R --> c3
    p3("・Jenkins Pipeline<br>・GitHub Actions Workflow")
    c3 --- p3
    c4["05 · 實戰：Spring Boot 完整部署流程"]
    R --> c4
    p4("・Helm Chart<br>・完整 CI/CD 流程總覽<br>・常用 kubectl 指令速查")
    c4 --- p4
    c5["06 · Harbor 私有映像倉庫"]
    R --> c5
    p5("・為什麼需要私有倉庫<br>・架構<br>・核心功能<br>・與 CI / K8s 整合<br>・Harbor 與其他倉庫")
    c5 --- p5
    c6["07 · Argo CD 與 GitOps"]
    R --> c6
    p6("・GitOps 是什麼<br>・Argo CD 架構<br>・Application<br>・完整流水線：Git → Harbor → Argo CD<br>・回滾與漂移")
    c6 --- p6
    c7["08 · 實戰：我的 CI/CD 與 K8s 部署"]
    R --> c7
    p7("・各專案的 CI 一覽<br>・holidayDessert：用服務容器跑整合測試<br>・映像與部署<br>・microservicecloud：自建 Kubernetes 叢集<br>・程式碼品質")
    c7 --- p7
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4,c5,c6,c7 chapter
    class p0,p1,p2,p3,p4,p5,p6,p7 points
```

## 章節導覽

<div class="grid cards" markdown>

-   __[01 · DevOps 核心概念](devops-concepts.md)__

    ---

    什麼是 DevOps？ · CI/CD 流水線 · DevOps 工具鏈全覽

-   __[02 · Docker 深入](docker.md)__

    ---

    Docker 核心原理 · Dockerfile 最佳實踐 · Docker Compose · Docker 網路

-   __[03 · Kubernetes 深入](kubernetes.md)__

    ---

    K8s 整體架構 · 核心資源對象 · 滾動更新與回滾 · StatefulSet

-   __[04 · Jenkins + GitHub Actions](jenkins-github-actions.md)__

    ---

    Jenkins Pipeline · GitHub Actions Workflow

-   __[05 · 實戰：Spring Boot 完整部署流程](deployment.md)__

    ---

    Helm Chart · 完整 CI/CD 流程總覽 · 常用 kubectl 指令速查

-   __[06 · Harbor 私有映像倉庫](harbor.md)__

    ---

    為什麼需要私有倉庫 · 架構 · 核心功能 · 與 CI / K8s 整合 …

-   __[07 · Argo CD 與 GitOps](argocd.md)__

    ---

    GitOps 是什麼 · Argo CD 架構 · Application · 完整流水線：Git → Harbor → Argo CD …

-   __[08 · 實戰：我的 CI/CD 與 K8s 部署](my-pipelines.md)__

    ---

    各專案的 CI 一覽 · holidayDessert：用服務容器跑整合測試 · 映像與部署 · microservicecloud：自建 Kubernetes 叢集 …

</div>

## 重點速覽

### 完整流水線架構
git push → GitHub / GitLab

- ↓

CI 階段：程式碼拉取 → Maven 建置 → 單元測試（>80%覆蓋率）

- → SonarQube 靜態分析 → OWASP 漏洞掃描
- → 多階段 Docker Build → Trivy 安全掃描
- → 推送 Image 到 Harbor Registry
- ↓

CD Staging：Helm upgrade → 等待 Rollout → Smoke Test

- ↓

**CD Production（人工審核 / Release Tag）**

- Helm upgrade → 滾動更新（0 停機）→ 生產冒煙測試 → Slack 通知

### Kubernetes 核心資源

| 資源 | 用途 |
|------|------|
| **Pod** | 最小部署單元，三種探針（liveness/readiness/startup）|
| **Deployment** | 管理無狀態應用，滾動更新 / 回滾 |
| **StatefulSet** | 管理有狀態應用（MySQL / Kafka），穩定網路標識 |
| **Service** | ClusterIP（內部）/ NodePort（測試）/ LoadBalancer（生產）|
| **Ingress** | HTTP 路由層，TLS 終止，統一入口 |
| **HPA** | 基於 CPU / 記憶體 / 自定義指標自動擴縮容 |
| **ConfigMap / Secret** | 配置與程式碼分離，生產用 Vault 管理 Secret |

### Docker 多階段建置
```dockerfile
# 建置階段（含 JDK + Maven）
FROM maven:3.9.5-eclipse-temurin-17-alpine AS builder
COPY pom.xml .
RUN mvn dependency:go-offline -B   # 利用 Docker 層緩存
COPY src ./src
RUN mvn clean package -DskipTests

# 運行階段（只含 JRE，Image 最小化）
FROM eclipse-temurin:17-jre-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /build/target/app-*.jar app.jar
USER appuser
EXPOSE 8080
```

## 核心要點總結

| 主題 | 核心要點 |
|------|---------|
| **Docker 原理** | Namespace（隔離）+ Cgroups（限制）+ UnionFS（分層）|
| **Dockerfile** | 多階段建置、利用緩存層、非 root 用戶、最小化 Image |
| **K8s 架構** | Control Plane（API Server/etcd/調度器）+ Worker Node |
| **Pod** | 最小部署單元，三種探針（liveness/readiness/startup）|
| **Deployment** | 無狀態應用，滾動更新 maxSurge/maxUnavailable |
| **Service** | ClusterIP（內部）/ NodePort（測試）/ LoadBalancer（生產）|
| **Ingress** | HTTP 路由層，統一入口，TLS 終止 |
| **HPA** | 基於 CPU/記憶體自動擴縮容，防止頻繁抖動 |
| **ConfigMap/Secret** | 配置與代碼分離，Secret 生產用 Vault |
| **Jenkins** | Jenkinsfile Pipeline，多 Stage 並行，自動回滾 |
| **GitHub Actions** | YAML Workflow，Job 依賴，Environment 保護 |
| **Helm** | K8s 套件管理，模板化，多環境管理 |
