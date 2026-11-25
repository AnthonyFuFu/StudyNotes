---
icon: lucide/container
---

# CI/CD 與 DevOps

DevOps 核心概念、Docker 與 Kubernetes 深入、Jenkins / GitHub Actions 流水線，以及 Spring Boot 的完整部署流程。

**核心技術**：Docker / Kubernetes / Jenkins / GitHub Actions / Helm

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

??? abstract "原始學習路線圖"

    ```
    CI/CD 與 DevOps
    ├── 1️⃣ DevOps 核心概念
    │   ├── 什麼是 DevOps
    │   ├── CI/CD 流水線
    │   └── DevOps 工具鏈全覽
    ├── 2️⃣ Docker 深入
    │   ├── 核心原理（Namespace / Cgroups）
    │   ├── Dockerfile 最佳實踐
    │   ├── Docker Compose
    │   └── Docker 網路與儲存
    ├── 3️⃣ Kubernetes 深入
    │   ├── 架構原理
    │   ├── 核心資源對象
    │   ├── 服務發現與負載均衡
    │   ├── 配置與密鑰管理
    │   └── 滾動更新與回滾
    ├── 4️⃣ Jenkins + GitHub Actions
    │   ├── Jenkins Pipeline
    │   ├── GitHub Actions Workflow
    │   └── 完整 CI/CD 流水線
    └── 5️⃣ 實戰：Spring Boot 完整部署流程
        ├── 程式碼 → Docker Image
        ├── Image → Kubernetes
        └── 自動化流水線
    ```

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
