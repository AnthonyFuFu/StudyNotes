---
icon: lucide/container
---

# CI/CD 與 DevOps

DevOps 核心概念、Docker 與 Kubernetes 深入、Jenkins / GitHub Actions 流水線，以及 Spring Boot 的完整部署流程。

**核心技術**：Docker / Kubernetes / Jenkins / GitHub Actions / Helm

## 學習地圖

``` mermaid
%%{init: {"flowchart": {"nodeSpacing": 14, "rankSpacing": 36, "wrappingWidth": 420}}}%%
flowchart LR
    R(["CI/CD 與 DevOps"])
    c0["01 · DevOps 核心概念"]
    R --> c0
    p0("・什麼是 DevOps<br>・CI/CD 流水線<br>・DevOps 工具鏈全覽")
    c0 --- p0
    c1["02 · Docker 深入"]
    R --> c1
    p1("・核心原理（Namespace / Cgroups）<br>・Dockerfile 最佳實踐<br>・Docker Compose<br>・Docker 網路與儲存")
    c1 --- p1
    c2["03 · Kubernetes 深入"]
    R --> c2
    p2("・架構原理<br>・核心資源對象<br>・服務發現與負載均衡<br>・配置與密鑰管理<br>・滾動更新與回滾")
    c2 --- p2
    c3["04 · Jenkins + GitHub Actions"]
    R --> c3
    p3("・Jenkins Pipeline<br>・GitHub Actions Workflow<br>・完整 CI/CD 流水線")
    c3 --- p3
    c4["05 · 實戰：Spring Boot 完整部署流程"]
    R --> c4
    p4("・程式碼 → Docker Image<br>・Image → Kubernetes<br>・自動化流水線")
    c4 --- p4
    classDef chapter stroke-width:2px
    classDef points fill:transparent,text-align:left
    class c0,c1,c2,c3,c4 chapter
    class p0,p1,p2,p3,p4 points
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

-   __[04 · Jenkins 與 GitHub Actions](jenkins-github-actions.md)__

    ---

    Jenkins Pipeline · GitHub Actions Workflow

-   __[05 · 實戰：完整部署流程](deployment.md)__

    ---

    Helm Chart · 完整 CI/CD 流程總覽 · 常用 kubectl 指令速查

</div>

## 重點速覽

### 完整流水線架構
```
git push → GitHub / GitLab
    ↓
CI 階段：程式碼拉取 → Maven 建置 → 單元測試（>80%覆蓋率）
    → SonarQube 靜態分析 → OWASP 漏洞掃描
    → 多階段 Docker Build → Trivy 安全掃描
    → 推送 Image 到 Harbor Registry
    ↓
CD Staging：Helm upgrade → 等待 Rollout → Smoke Test
    ↓
CD Production（人工審核 / Release Tag）：
    Helm upgrade → 滾動更新（0 停機）→ 生產冒煙測試 → Slack 通知
```

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
