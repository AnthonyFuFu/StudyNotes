# 實戰：Spring Boot 完整部署流程

## Helm Chart（K8s 應用包管理）

Helm 是 K8s 的「套件管理器」（類似 apt / npm），將複雜的 K8s YAML 模板化，方便管理多環境。

``` text title="Chart 目錄結構"
myapp/
├── Chart.yaml              ← Chart 基本資訊
├── values.yaml             ← 預設值
├── values-staging.yaml     ← Staging 覆蓋值
├── values-prod.yaml        ← 生產覆蓋值
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── hpa.yaml
    └── _helpers.tpl        ← 共用模板函數
```

```yaml
# values.yaml（預設值）
replicaCount: 2

image:
  repository:  harbor.example.com/backend/myapp
  tag:         latest
  pullPolicy:  IfNotPresent

service:
  type:       ClusterIP
  port:       80
  targetPort: 8080

ingress:
  enabled: true
  host:    api.example.com
  tls:     true

resources:
  requests:
    cpu:    250m
    memory: 512Mi
  limits:
    cpu:    1000m
    memory: 1Gi

autoscaling:
  enabled:                        true
  minReplicas:                    2
  maxReplicas:                    10
  targetCPUUtilizationPercentage: 70

config:
  springProfile: production
  logLevel:      INFO

---
# values-prod.yaml（生產覆蓋）
replicaCount: 5
resources:
  requests:
    cpu:    500m
    memory: 1Gi
  limits:
    cpu:    2000m
    memory: 2Gi
autoscaling:
  maxReplicas: 20
```

```bash
# Helm 常用指令

# 安裝（部署到 K8s）
helm install myapp ./myapp \
  -n production \
  -f values-prod.yaml \
  --set image.tag=v1.2.3

# 升級（更新）
helm upgrade myapp ./myapp \
  -n production \
  -f values-prod.yaml \
  --set image.tag=v1.2.4

# 查看已安裝的 Chart
helm list -n production

# 查看歷史版本
helm history myapp -n production

# 回滾
helm rollback myapp 2 -n production

# 模擬安裝（不實際執行，查看生成的 YAML）
helm install myapp ./myapp --dry-run --debug

# 卸載
helm uninstall myapp -n production
```

## 完整 CI/CD 流程總覽

``` mermaid
flowchart TB
    PUSH(["開發者 git push → GitHub Actions 觸發"]) --> CI1
    subgraph CI1 ["CI 階段：建置與測試"]
        direction LR
        c1["① 拉取程式碼"] --> c2["② Maven 建置"] --> c3["③ 單元測試<br>覆蓋率 > 80%"] --> c4["④ SonarQube<br>靜態分析"]
    end
    CI1 --> CI2
    subgraph CI2 ["CI 階段：掃描與發佈"]
        direction LR
        c5["⑤ OWASP<br>依賴掃描"] --> c6["⑥ 建置<br>Docker Image"] --> c7["⑦ Trivy<br>容器掃描"] --> c8["⑧ 推送到<br>Harbor"]
    end
    CI2 -- "CI 通過" --> STG
    subgraph STG ["CD - Staging"]
        direction LR
        s1["① Helm upgrade"] --> s2["② 等待 Rollout"] --> s3["③ Smoke Test"] --> s4["④ 整合測試"]
    end
    STG -- "Release Tag 或人工審核" --> PRD
    subgraph PRD ["CD - Production"]
        direction LR
        p1["① Environment<br>審核"] --> p2["② Helm<br>滾動更新"] --> p3["③ 等待<br>Rollout"] --> p4["④ 生產<br>冒煙測試"] --> p5["⑤ 通知<br>Slack"]
    end
    PRD --> MON
    subgraph MON ["監控告警"]
        direction LR
        m1["Prometheus → Grafana"] ~~~ m2["ELK 日誌分析"] ~~~ m3["PagerDuty 告警"]
    end
```

## 常用 kubectl 指令速查

```bash
# ── 查看資源 ──
kubectl get pods -n production                  # 查看 Pod
kubectl get pods -n production -o wide          # 顯示 Node 信息
kubectl get all -n production                   # 查看所有資源
kubectl describe pod myapp-xxx -n production    # 詳細信息（排查問題）

# ── 日誌 ──
kubectl logs myapp-pod-xxx -n production        # 查看日誌
kubectl logs myapp-pod-xxx -n production -f     # 追蹤日誌
kubectl logs myapp-pod-xxx -n production \
  --previous                                    # 查看上次崩潰的日誌
kubectl logs -l app=myapp -n production \
  --max-log-requests=5                          # 查看所有 Pod 日誌

# ── 進入容器 ──
kubectl exec -it myapp-pod-xxx -n production \
  -- /bin/sh                                    # 進入容器 Shell

# ── 資源管理 ──
kubectl apply -f deployment.yaml                # 應用配置
kubectl delete pod myapp-pod-xxx -n production  # 刪除 Pod（自動重建）
kubectl scale deployment myapp-deployment \
  --replicas=5 -n production                    # 手動擴縮容

# ── 臨時調試 ──
kubectl port-forward pod/myapp-pod-xxx \
  8080:8080 -n production                       # 本地端口轉發（調試用）
kubectl run debug-pod --rm -it \
  --image=busybox -- /bin/sh                    # 臨時調試 Pod

# ── 資源使用情況 ──
kubectl top nodes                               # 查看節點資源使用
kubectl top pods -n production                  # 查看 Pod 資源使用

# ── 強制重啟（滾動重啟）──
kubectl rollout restart deployment/myapp-deployment -n production
```
