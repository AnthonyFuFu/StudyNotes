# DevOps 核心概念

## 什麼是 DevOps？

```
傳統開發模式的問題：

開發團隊：「功能寫完了，丟給運維！」
運維團隊：「你這個跑不起來！」
開發團隊：「在我電腦上可以啊！」
↓
互相指責，上線困難，交付慢

DevOps = Development + Operations
打破開發與運維的隔閡

核心理念：
┌─────────────────────────────────────────────┐
│                  DevOps 無限循環               │
│                                             │
│  Plan → Code → Build → Test → Release      │
│    ↑                                   ↓   │
│  Monitor ← Operate ← Deploy ← Deploy ←    │
└─────────────────────────────────────────────┘

目標：
✅ 更快交付（Faster Delivery）
✅ 更高品質（Higher Quality）
✅ 更穩定運行（More Stability）
✅ 更快恢復（Faster Recovery）
```

## CI/CD 流水線

```
CI（Continuous Integration）持續整合：
  開發者每次提交程式碼，自動觸發：
  建置 → 單元測試 → 程式碼分析 → 打包
  → 快速發現問題，防止「整合地獄」

CD（Continuous Delivery）持續交付：
  CI 通過後，自動部署到測試/預生產環境
  生產環境需要人工確認

CD（Continuous Deployment）持續部署：
  全自動，直接部署到生產環境（需要高度信任的測試）

完整流水線：

程式碼提交
    ↓
┌───────────────────────────────────────────────────────────────┐
│                        CI 階段                                 │
│  程式碼拉取 → 編譯建置 → 單元測試 → 代碼掃描 → 建置 Docker Image  │
└───────────────────────────┬───────────────────────────────────┘
                            ↓ CI 通過
┌───────────────────────────────────────────────────────────────┐
│                        CD 階段                                 │
│  推送 Image → 部署到測試環境 → 整合測試 → 部署到預生產 → 冒煙測試  │
└───────────────────────────┬───────────────────────────────────┘
                            ↓ 人工審核（或自動）
                    部署到生產環境
                            ↓
                    監控 & 告警
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
