# DevOps 核心概念

## 什麼是 DevOps？

**傳統開發模式的問題**

``` mermaid
sequenceDiagram
    participant Dev as 開發團隊
    participant Ops as 運維團隊
    Dev->>Ops: 功能寫完了，丟給運維！
    Ops-->>Dev: 你這個跑不起來！
    Dev-->>Ops: 在我電腦上可以啊！
    Note over Dev,Ops: 互相指責，上線困難，交付慢
```

**DevOps = Development + Operations**：打破開發與運維的隔閡。

``` mermaid
flowchart LR
    Plan --> Code --> Build --> Test --> Release
    Release --> Deploy --> Operate --> Monitor --> Plan
```

**目標**

- ✅ 更快交付（Faster Delivery）
- ✅ 更高品質（Higher Quality）
- ✅ 更穩定運行（More Stability）
- ✅ 更快恢復（Faster Recovery）

## CI/CD 流水線

| 名稱 | 說明 |
|------|------|
| **CI**（Continuous Integration）<br>持續整合 | 開發者每次提交程式碼，自動觸發：建置 → 單元測試 → 程式碼分析 → 打包<br>快速發現問題，防止「整合地獄」 |
| **CD**（Continuous Delivery）<br>持續交付 | CI 通過後，自動部署到測試 / 預生產環境<br>生產環境需要人工確認 |
| **CD**（Continuous Deployment）<br>持續部署 | 全自動，直接部署到生產環境（需要高度信任的測試） |

**完整流水線**

``` mermaid
flowchart TB
    COMMIT(["程式碼提交"]) --> CI
    subgraph CI ["CI 階段"]
        direction LR
        a1["程式碼拉取"] --> a2["編譯建置"] --> a3["單元測試"] --> a4["代碼掃描"] --> a5["建置 Docker Image"]
    end
    CI -- "CI 通過" --> CD
    subgraph CD ["CD 階段"]
        direction LR
        b1["推送 Image"] --> b2["部署到測試環境"] --> b3["整合測試"] --> b4["部署到預生產"] --> b5["冒煙測試"]
    end
    CD -- "人工審核（或自動）" --> PROD["部署到生產環境"] --> MON["監控 & 告警"]
```

## DevOps 工具鏈全覽

```
階段                工具
──────────────────────────────────────────────
計劃（Plan）        Jira、Trello、GitHub Issues
程式碼（Code）      Git、GitHub、GitLab
建置（Build）       Maven、Gradle、npm
測試（Test）        JUnit、Mockito、Testcontainers
掃描（Scan）        SonarQube、Checkstyle、OWASP
容器（Container）   Docker、Podman
倉庫（Registry）    Docker Hub、Harbor、ECR
編排（Orchestrate） Kubernetes、Docker Swarm
CI/CD（Pipeline）  Jenkins、GitHub Actions、GitLab CI
配置（Config）      Helm、Kustomize、Ansible
監控（Monitor）     Prometheus、Grafana、ELK
服務網格（Mesh）    Istio、Linkerd
```
